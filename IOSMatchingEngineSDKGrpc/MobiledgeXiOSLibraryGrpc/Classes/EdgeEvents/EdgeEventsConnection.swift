// Copyright 2018-2020 MobiledgeX, Inc. All rights and licenses reserved.
// MobiledgeX, Inc. 156 2nd Street #408, San Francisco, CA 94105
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

//
//  EdgeEventsConnection.swift
//

import Foundation
@_implementationOnly import GRPC
@_implementationOnly import NIO
import os.log
import Promises

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.EdgeEvents {
    
    class Stream {
        var stream: BidirectionalStreamingCall<DistributedMatchEngine_ClientEdgeEvent, DistributedMatchEngine_ServerEdgeEvent>
        
        init(client: MobiledgeXiOSLibraryGrpc.GrpcClient, serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) {
            self.stream = client.apiclient.streamEdgeEvent(callOptions: nil, handler: serverEventsHandler)
            // add callback that checks if the stream closed gracefully
            /*self.stream.status.whenSuccess { status in
                os_log("edgeevents connection stopped. status is %@", log: OSLog.default, type: .debug, status.message ?? "")
                self.cleanup()
                if !status.isOk {
                    reject(status)
                }
            }*/
        }
        
        func sendMessage(clientEdgeEvent: DistributedMatchEngine_ClientEdgeEvent) -> EventLoopFuture<Void> {
            return self.stream.sendMessage(clientEdgeEvent)
        }
    }
    
    /// EdgeEventsConnection class
    /// Provides the client with useful information about their appinst state and other cloudlets that may be closer or have lower latency
    /// Provides functions to receive and send EdgeEvents
    public class EdgeEventsConnection {
                
        var matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine
        
        var client: MobiledgeXiOSLibraryGrpc.GrpcClient? = nil
        var host: String
        var port: UInt16
        var tlsEnabled = true
        
        var connectionReady = false
        var connectionClosed = false
        var initializedWithConfig = false
        
        var latencyTimer: DispatchSourceTimer? = nil
        var currLatencyInterval: Int = 0
        var locationTimer: DispatchSourceTimer? = nil
        var currLocationInterval: UInt = 0
        var lastStoredLocation: DistributedMatchEngine_Loc = DistributedMatchEngine_Loc.init()
        
        var config: EdgeEventsConfig? = nil
        var stream: Stream? = nil
        var newFindCloudletHandler: ((EdgeEventsStatus, FindCloudletEvent?) -> Void)? = nil
        var serverEventsHandler: ((DistributedMatchEngine_ServerEdgeEvent) -> Void)? = nil
        var getLastLocation: (() -> Promise<DistributedMatchEngine_Loc>)? = nil
        
        let getLocationQueue = DispatchQueue(label: "getLocationQueue") // used to sync lastLocation
                        
        /// Initializer with EdgeEventsConfig (Recommended)
        init(matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine, dmeHost: String, dmePort: UInt16, tlsEnabled: Bool, newFindCloudletHandler: @escaping ((EdgeEventsStatus, FindCloudletEvent?) -> Void), config: EdgeEventsConfig) {
            self.matchingEngine = matchingEngine
            self.config = config
            self.host = dmeHost
            self.port = dmePort
            self.tlsEnabled = tlsEnabled
            self.newFindCloudletHandler = newFindCloudletHandler
            self.initializedWithConfig = true
            self.getLastLocation = MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.getLastLocation
        }
        
        /// Initializer without EdgeEventsConfig (Not recommended. Recommended is with EdgeEventsConfig)
        init(matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine, dmeHost: String, dmePort: UInt16, tlsEnabled: Bool, serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) {
            self.matchingEngine = matchingEngine
            self.host = dmeHost
            self.port = dmePort
            self.tlsEnabled = tlsEnabled
            self.serverEventsHandler = serverEventsHandler
            self.initializedWithConfig = false
        }
        
        /// Start EdgeEventsConnection
        public func start(timeoutMs: Double = 10000) -> Promise<EdgeEventsStatus> {
            return Promise<EdgeEventsStatus>(on: matchingEngine.state.edgeEventsQueue) { fulfill, reject in
                self.validateEdgeEvents().then { validated in
                    // validate config and handlers
                    if !validated {
                        reject(EdgeEventsError.invalidEdgeEventsSetup)
                    }
                    self.client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: self.host, port: self.port, tlsEnabled: self.tlsEnabled)
                    // create bidirectional stream
                    self.stream = Stream.init(client: self.client!, serverEventsHandler: self.serverEventsHandler ?? self.handleServerEvents)
                    // initialize init edgeevent
                    var initMessage = DistributedMatchEngine_ClientEdgeEvent.init()
                    initMessage.eventType = .eventInitConnection
                    // check for valid lastFindCloudletReply
                    guard let _ = self.matchingEngine.lastFindCloudletReply else {
                        reject(EdgeEventsError.hasNotDoneFindCloudlet)
                        return
                    }
                    // check for session cookie
                    guard let sessionCookie = self.matchingEngine.state.getSessionCookie() else {
                        reject(EdgeEventsError.missingSessionCookie)
                        return
                    }
                    initMessage.sessionCookie = sessionCookie
                    // check for edgeevents cookie
                    guard let edgeEventsCookie = self.matchingEngine.state.getEdgeEventsCookie() else {
                        reject(EdgeEventsError.missingEdgeEventsCookie)
                        return
                    }
                    initMessage.edgeEventsCookie = edgeEventsCookie
            
                    do {
                        
                        // send init message
                        let res = self.stream?.sendMessage(clientEdgeEvent: initMessage)
                        try res!.wait()
                        // wait until receive init message back or timeout
                        while true {
                            if self.connectionReady {
                                break
                            }
                        }
                        // if application initialized with EdgeEventsConfig, we will handle sending client events (latency and gps)
                        if self.initializedWithConfig {
                            self.startSendClientEvents()
                        }
                        fulfill(.success)
                        return
                    } catch {
                        reject(error)
                        return
                    }
                }.catch { error in
                    reject(error)
                }.timeout(timeoutMs/1000.0)
            }
        }
        
        /// Stop EdgeEventsConnection and cleanup
        public func close() -> Promise<EdgeEventsStatus> {
            return Promise<EdgeEventsStatus>(on: matchingEngine.state.edgeEventsQueue) { fulfill, reject in
                // send terminate connection
                var terminateEdgeEvent = DistributedMatchEngine_ClientEdgeEvent.init()
                terminateEdgeEvent.eventType = .eventTerminateConnection
                let res = self.stream?.sendMessage(clientEdgeEvent: terminateEdgeEvent)
                do {
                    try res!.wait()
                } catch {
                    reject(error)
                    return
                }
                self.cleanup().then { cleanedUp in
                    if cleanedUp {
                        fulfill(.success)
                    } else {
                        fulfill(.fail(error: EdgeEventsError.unableToCleanup))
                    }
                }.catch { error in
                    fulfill(.fail(error: error))
                }
                
            }
        }
        
        /// Clean up EdgeEventsConnection class variables
        public func cleanup() -> Promise<Bool> {
            // close grpc client and clean up variables
            latencyTimer?.cancel()
            latencyTimer = nil
            currLatencyInterval = 0
            locationTimer?.cancel()
            locationTimer = nil
            currLocationInterval = 0
            lastStoredLocation = DistributedMatchEngine_Loc.init()
            connectionReady = false
            connectionClosed = true
            return MobiledgeXiOSLibraryGrpc.closeGrpcClient(client: client!)
        }
        
        /// Restart EdgeEventsConnection
        public func restart() -> Promise<EdgeEventsStatus> {
            // If autoMigrationEdgeEventsConnection is true, then automatically create new bidirectional connection
            if self.matchingEngine.autoMigrationEdgeEventsConnection {
                return close().then { status -> Promise<EdgeEventsStatus> in
                    if status == .success {
                        return self.start()
                    } else {
                        os_log("unable to close previous edgeevents connection. in order to restart edgeeventsconnection manually, call switchedToNewCloudlet", log: OSLog.default, type: .debug)
                        let promise = Promise<EdgeEventsStatus>.pending()
                        promise.fulfill(.fail(error: EdgeEventsError.failedToClose))
                        return promise
                    }
                }.then { status -> Promise<EdgeEventsStatus> in
                    if status == .success {
                        os_log("successfully restarted edgeevents connection", log: OSLog.default, type: .debug)
                    } else {
                        os_log("unable to restart edgeevents connection. in order to restart edgeeventsconnection manually, call switchedToNewCloudlet", log: OSLog.default, type: .debug)
                    }
                    let promise = Promise<EdgeEventsStatus>.pending()
                    promise.fulfill(.success)
                    return promise
                }
            // If autoMigrationEdgeEventsConnection is false, it is up to the application to restart edgeevents connection by calling switchedToNewCloudlet if and when their application has switched to the new cloudlet provided
            } else {
                os_log("autoMigrationEdgeEventsConnection is false. Call switchedToNewCloudlet to receive edgeevents from new cloudlet", log: OSLog.default, type: .debug)
                let promise = Promise<EdgeEventsStatus>.pending()
                promise.fulfill(.success)
                return promise
            }
        }
        
        /// Send a location update to DME
        /// If the new location is closer to another cloudlet, DME will send a .eventCloudletUpdate as well as a new FIndCloudletReply
        public func postLocationUpdate(loc: DistributedMatchEngine_Loc) -> Promise<EdgeEventsStatus> {
            // initialize location edgeevent
            var locationEdgeEvent = DistributedMatchEngine_ClientEdgeEvent.init()
            locationEdgeEvent.eventType = .eventLocationUpdate
            locationEdgeEvent.gpsLocation = loc
            locationEdgeEvent.deviceInfo = matchingEngine.getDeviceInfo()
            return Promise<EdgeEventsStatus>(on: self.matchingEngine.state.edgeEventsQueue) { fulfill, reject in
                if self.connectionReady && !self.connectionClosed {
                    do {
                        let res = self.stream?.sendMessage(clientEdgeEvent: locationEdgeEvent)
                        try res!.wait()
                        fulfill(.success)
                    } catch {
                        reject(error)
                    }
                } else {
                    reject(EdgeEventsError.connectionAlreadyClosed)
                }
            }
        }
        
        /// Send a latency update to DME
        /// DME will send a .eventLatencyProcessed with summarized latency stats
        /// If .eventLatencyProcessed is specified in EdgeEventsConfig, the SDK will check if the latency is greater than the latencyThresholdTriggerMs.
        /// If latency is greater than latencyThresholdTriggerMs, then the SDK will try to find a better cloudlet. If a better cloudlet is found, it is returned to the newCloudletHandler
        public func postLatencyUpdate(site: MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site, loc: DistributedMatchEngine_Loc) -> Promise<EdgeEventsStatus> {
            // initialize latency edgeevent
            var latencyEdgeEvent = DistributedMatchEngine_ClientEdgeEvent.init()
            latencyEdgeEvent.eventType = .eventLatencySamples
            latencyEdgeEvent.samples = site.getDmeSamples()
            latencyEdgeEvent.gpsLocation = loc
            latencyEdgeEvent.deviceInfo = matchingEngine.getDeviceInfo()
            
            return Promise<EdgeEventsStatus>(on: self.matchingEngine.state.edgeEventsQueue) { fulfill, reject in
                if self.connectionReady && !self.connectionClosed {
                    do {
                        let res = self.stream?.sendMessage(clientEdgeEvent: latencyEdgeEvent)
                        try res!.wait()
                        fulfill(.success)
                    } catch {
                        reject(error)
                    }
                } else {
                    reject(EdgeEventsError.connectionAlreadyClosed)
                }
            }
        }
        
        /// Run Ping latency test and then send the latency samples to DME
        /// Not recommended. Recommended is testConnectAndPostLatencyUpdate
        /// (Swift does not support Ping natively, so there are some issues with the Ping test)
        public func testPingAndPostLatencyUpdate(testPort: UInt16, loc: DistributedMatchEngine_Loc) -> Promise<EdgeEventsStatus> {
            let promise = Promise<EdgeEventsStatus>.pending()
            do {
                guard let fcReply = matchingEngine.lastFindCloudletReply else {
                    promise.reject(EdgeEventsError.hasNotDoneFindCloudlet)
                    return promise
                }
                guard let appPortsDict = try matchingEngine.getTCPAppPorts(findCloudletReply: fcReply) else {
                    promise.reject(EdgeEventsError.emptyAppPorts)
                    return promise
                }
                if appPortsDict.capacity == 0 {
                    promise.reject(EdgeEventsError.emptyAppPorts)
                    return promise
                }
                var port = testPort
                if port == 0 {
                    guard let firstElem = appPortsDict.first else {
                        promise.reject(EdgeEventsError.emptyAppPorts)
                        return promise
                    }
                    port = firstElem.key
                }
                guard let appPort = appPortsDict[port] else {
                    promise.reject(EdgeEventsError.portDoesNotExist)
                    return promise
                }
                let host = try matchingEngine.getHost(findCloudletReply: fcReply, appPort: appPort)
                let site = MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site(network: MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR, host: host, port: port, testType: MobiledgeXiOSLibraryGrpc.PerformanceMetrics.NetTest.TestType.PING, numSamples: 5)
                let netTest = MobiledgeXiOSLibraryGrpc.PerformanceMetrics.NetTest(sites: [site], qos: .background)
                
                return Promise<EdgeEventsStatus>(on: self.matchingEngine.state.edgeEventsQueue) { fulfill, reject in
                    netTest.runTest(numSamples: 5).then { sites in
                        return self.postLatencyUpdate(site: sites[0], loc: loc)
                    }
                }
            } catch {
                promise.reject(error)
                return promise
            }
        }
        
        /// Run a connect/disconnect socket latency test and send latency samples to DME
        /// Recommended test
        /// Only works for TCP port
        func testConnectAndPostLatencyUpdate(testPort: UInt16, loc: DistributedMatchEngine_Loc) -> Promise<EdgeEventsStatus> {
            let promise = Promise<EdgeEventsStatus>.pending()
            do {
                guard let fcReply = matchingEngine.lastFindCloudletReply else {
                    promise.reject(EdgeEventsError.hasNotDoneFindCloudlet)
                    return promise
                }
                guard let appPortsDict = try matchingEngine.getTCPAppPorts(findCloudletReply: fcReply) else {
                    promise.reject(EdgeEventsError.emptyAppPorts)
                    return promise
                }
                if appPortsDict.capacity == 0 {
                    promise.reject(EdgeEventsError.emptyAppPorts)
                    return promise
                }
                var port = testPort
                if port == 0 {
                    guard let firstElem = appPortsDict.first else {
                        promise.reject(EdgeEventsError.emptyAppPorts)
                        return promise
                    }
                    port = firstElem.key
                }
                guard let appPort = appPortsDict[port] else {
                    promise.reject(EdgeEventsError.portDoesNotExist)
                    return promise
                }
                let host = try matchingEngine.getHost(findCloudletReply: fcReply, appPort: appPort)
                let site = MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site(network: MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR, host: host, port: port, testType: MobiledgeXiOSLibraryGrpc.PerformanceMetrics.NetTest.TestType.CONNECT, numSamples: 5)
                let netTest = MobiledgeXiOSLibraryGrpc.PerformanceMetrics.NetTest(sites: [site], qos: .background)
                
                return Promise<EdgeEventsStatus>(on: self.matchingEngine.state.edgeEventsQueue) { fulfill, reject in
                    netTest.runTest(numSamples: 5).then { sites in
                        return self.postLatencyUpdate(site: sites[0], loc: loc)
                    }
                }
            } catch {
                promise.reject(error)
                return promise
            }
        }
        
        func handleServerEvents(event: DistributedMatchEngine_ServerEdgeEvent) {
            switch event.eventType {
            case .eventInitConnection:
                os_log("initconnection", log: OSLog.default, type: .debug)
                connectionReady = true
                connectionClosed = false
            case .eventLatencyRequest:
                os_log("latencyrequest", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEventTriggers.contains(.latencyTooHigh) {
                    getLastStoredLocation().then { loc -> Promise<EdgeEventsStatus> in
                        return self.testConnectAndPostLatencyUpdate(testPort: self.config!.latencyTestPort!, loc: loc)
                    }.then { status in
                        os_log("successfully test connect and post latency update", log: OSLog.default, type: .debug)
                    }.catch { error in
                        os_log("error testing connect and posting latency update: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        self.sendErrorToHandler(error: error)
                    }
                }
            case .eventLatencyProcessed:
                os_log("latencyprocessed", log: OSLog.default, type: .debug)
                print("latency stats are \(event.statistics)")
                if config!.newFindCloudletEventTriggers.contains(.latencyTooHigh) {
                    let stats = event.statistics
                    if stats.avg >= config!.latencyThresholdTriggerMs! {
                        sendFindCloudletToHandler(eventType: .latencyTooHigh)
                    }
                }
            case .eventCloudletState:
                os_log("cloudletstate", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEventTriggers.contains(.cloudletStateChanged) && event.cloudletState != .ready {
                    sendFindCloudletToHandler(eventType: .cloudletStateChanged)
                }
            case .eventCloudletMaintenance:
                os_log("cloudletmaintenance", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEventTriggers.contains(.cloudletMaintenanceStateChanged) && event.maintenanceState != .normalOperation {
                    sendFindCloudletToHandler(eventType: .cloudletMaintenanceStateChanged)
                }
            case .eventAppinstHealth:
                os_log("appinsthealth", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEventTriggers.contains(.appInstHealthChanged) && event.healthCheck != .ok {
                    sendFindCloudletToHandler(eventType: .appInstHealthChanged)
                }
            case .eventCloudletUpdate:
                os_log("cloudletupdate", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEventTriggers.contains(.closerCloudlet) {
                    sendFindCloudletToHandler(eventType: .closerCloudlet, newCloudlet: event.newCloudlet)
                }
            case .eventError:
                os_log("eventError", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEventTriggers.contains(.error) {
                    sendErrorToHandler(error: EdgeEventsError.eventError(msg: event.errorMsg))
                }
            case .eventUnknown:
                os_log("eventUnknown", log: OSLog.default, type: .debug)
            default:
                os_log("default case, event: %@", log: OSLog.default, type: .debug, event.eventType.rawValue)
            }
        }
        
        func sendFindCloudletToHandler(eventType: FindCloudletEventTrigger, newCloudlet: DistributedMatchEngine_FindCloudletReply? = nil) {
            if newCloudlet != nil && eventType == .closerCloudlet {
                if !self.newCloudletIsDifferent(newCloudlet: newCloudlet!, oldCloudlet: self.matchingEngine.lastFindCloudletReply!) {
                    self.newFindCloudletHandler!(.fail(error: EdgeEventsError.eventTriggeredButCurrentCloudletIsBest), nil)
                } else {
                    let findCloudletEvent = FindCloudletEvent(newCloudlet: newCloudlet!, trigger: eventType)
                    matchingEngine.lastFindCloudletReply = newCloudlet
                    matchingEngine.state.setEdgeEventsCookie(edgeEventsCookie: newCloudlet?.edgeEventsCookie)
                    restart().then { status in
                        self.newFindCloudletHandler!(.success, findCloudletEvent)
                    }
                }
            } else {
                let oldCloudlet = self.matchingEngine.lastFindCloudletReply
                getLastStoredLocation().then { loc -> Promise<DistributedMatchEngine_FindCloudletReply> in
                    let req = try self.matchingEngine.createFindCloudletRequest(gpsLocation: loc, carrierName: self.matchingEngine.lastFindCloudletRequest?.carrierName)
                    return self.matchingEngine.findCloudlet(host: self.host, port: self.port, request: req, mode: MobiledgeXiOSLibraryGrpc.MatchingEngine.FindCloudletMode.PERFORMANCE)
                }.then { reply -> Promise<EdgeEventsStatus> in
                    if !self.newCloudletIsDifferent(newCloudlet: reply, oldCloudlet: oldCloudlet!) {
                        let promise = Promise<EdgeEventsStatus>.pending()
                        promise.fulfill(.fail(error: EdgeEventsError.eventTriggeredButCurrentCloudletIsBest))
                        return promise
                    } else {
                        return self.restart()
                    }
                }.then { status in
                    if status == .success {
                        let findCloudletEvent = FindCloudletEvent(newCloudlet: self.matchingEngine.lastFindCloudletReply!, trigger: eventType)
                        self.newFindCloudletHandler!(.success, findCloudletEvent)
                    } else {
                        self.newFindCloudletHandler!(status, nil)
                    }
                }.catch { error in
                    os_log("received server event, but error doing findcloudlet: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                    self.newFindCloudletHandler!(.fail(error: error), nil)
                }
            }
        }
        
        func sendErrorToHandler(error: Error) {
            self.newFindCloudletHandler!(.fail(error: error), nil)
        }
        
        func startSendClientEvents() {
            // Set up latency update timer if latencyUpdateConfig proviced
            if let latencyConfig = config!.latencyUpdateConfig {
                switch latencyConfig.updatePattern {
                case .onStart:
                    matchingEngine.state.edgeEventsQueue.async {
                        self.getLastStoredLocation().then { loc -> Promise<EdgeEventsStatus> in
                            return self.testConnectAndPostLatencyUpdate(testPort: self.config!.latencyTestPort!, loc: loc)
                        }.then { status in
                            os_log("successfully test connect and post latency update", log: OSLog.default, type: .debug)
                        }.catch { error in
                            os_log("error testing connect and posting latency update: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        }
                    }
                case .onInterval:
                    latencyTimer = DispatchSource.makeTimerSource(queue: matchingEngine.state.edgeEventsQueue)
                    latencyTimer!.setEventHandler(handler: {
                        if self.currLatencyInterval < latencyConfig.maxNumberOfUpdates! || latencyConfig.maxNumberOfUpdates! <= 0 {
                            self.getLastStoredLocation().then { loc -> Promise<EdgeEventsStatus> in
                                return self.testConnectAndPostLatencyUpdate(testPort: self.config!.latencyTestPort!, loc: loc)
                            }.then { status in
                                os_log("successfully test connect and post latency update", log: OSLog.default, type: .debug)
                                self.currLatencyInterval += 1
                            }.catch { error in
                                os_log("error testing connect and posting latency update: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                                self.sendErrorToHandler(error: error)
                            }
                        } else {
                            self.latencyTimer!.cancel()
                        }
                    })
                    latencyTimer!.schedule(deadline: .now(), repeating: .seconds(Int(latencyConfig.updateIntervalSeconds!)), leeway: .milliseconds(100))
                    latencyTimer!.resume()
                default:
                    os_log("application will handle latency updates", log: OSLog.default, type: .debug)
                }
            }
            
            // Set up location update timer if locationUpdateConfig provided
            if let locationConfig = config!.locationUpdateConfig {
                switch locationConfig.updatePattern {
                case .onStart:
                    matchingEngine.state.edgeEventsQueue.async {
                        self.updateLastStoredLocation().then { loc -> Promise<EdgeEventsStatus> in
                            return self.postLocationUpdate(loc: loc)
                        }.then { status in
                            os_log("successfully post location update", log: OSLog.default, type: .debug)
                        }.catch { error in
                            os_log("error posting location update: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        }
                    }
                case .onInterval:
                    locationTimer = DispatchSource.makeTimerSource(queue: matchingEngine.state.edgeEventsQueue)
                    locationTimer!.setEventHandler(handler: {
                        if self.currLocationInterval < locationConfig.maxNumberOfUpdates! || locationConfig.maxNumberOfUpdates! <= 0 {
                            self.updateLastStoredLocation().then { loc -> Promise<EdgeEventsStatus> in
                                return self.postLocationUpdate(loc: loc)
                            }.then { status in
                                os_log("successfully post location update", log: OSLog.default, type: .debug)
                                self.currLocationInterval += 1
                            }.catch { error in
                                os_log("error posting location update: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                                self.sendErrorToHandler(error: error)
                            }
                        } else {
                            self.locationTimer!.cancel()
                        }
                    })
                    locationTimer!.schedule(deadline: .now(), repeating: .seconds(Int(locationConfig.updateIntervalSeconds!)), leeway: .milliseconds(100))
                    locationTimer!.resume()
                default:
                    os_log("application will handle location updates", log: OSLog.default, type: .debug)
                }
            }
        }
        
        func validateEdgeEvents() -> Promise<Bool> {
            let promise = Promise<Bool>.pending()
            if self.initializedWithConfig {
                // Check config and callbacks if using EdgeEventsConfig
                let err = self.validateEdgeEventsConfig()
                if err != nil {
                    promise.reject(err!)
                    return promise
                }
                guard let _ = self.newFindCloudletHandler else {
                    os_log("nil newFindCloudletHandler - a valid newFindCloudletHandler is required receive events", log: OSLog.default, type: .debug)
                    promise.reject(EdgeEventsError.missingNewFindCloudletHandler)
                    return promise
                }
                guard let _ = self.getLastLocation else {
                    os_log("nil getLastLocation function - a valid getLastLocation function is required to send client events", log: OSLog.default, type: .debug)
                    promise.reject(EdgeEventsError.missingGetLastLocationFunction)
                    return promise
                }
                self.updateLastStoredLocation().then { loc in
                    promise.fulfill(true)
                }.catch { error in
                    os_log("A valid return value from getLastLocation is required to send client events. Error is %@", log: OSLog.default, type: .debug, error.localizedDescription)
                    promise.reject(EdgeEventsError.unableToGetLastLocation)
                }
            } else {
                // Check that serverEventsHandler is non nil if no EdgeEventsConfig
                guard let _ = self.serverEventsHandler else {
                    os_log("nil serverEventsHandler function - a valid serverEventsHandler function is required to receive server events", log: OSLog.default, type: .debug)
                    promise.reject(EdgeEventsError.missingServerEventsHandler)
                    return promise
                }
                promise.fulfill(true)
            }
            return promise
        }
        
        func validateEdgeEventsConfig() -> Error? {
            // Check that config is non nil
            guard let _ = config else {
                os_log("nil EdgeEventsConfig - a valid EdgeEventsConfig is required to send client events", log: OSLog.default, type: .debug)
                return EdgeEventsError.missingEdgeEventsConfig
            }
            // Check that if newFindCloudletEventTriggers contains .latencyTooHigh valid latency fields are populated
            if config!.newFindCloudletEventTriggers.contains(.latencyTooHigh) {
                // Validate latencyUpdateConfig
                guard let latencyUpdateConfig = config!.latencyUpdateConfig else {
                    os_log("A latencyUpdateConfig is required if .eventLatencyProcessed is specified in newFindCloudletEvents", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingLatencyUpdateConfig
                }
                // Validate latency threshold
                guard let threshold = config!.latencyThresholdTriggerMs else {
                    os_log("nil latencyThresholdTriggerMs - a valid latencyThresholdTriggerMs is required if .eventLatencyProcessed is in newFindCloudletEvents", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingLatencyThreshold
                }
                if threshold <= 0 {
                    os_log("latencyThresholdTriggerMs is not a positive number - a valid latencyThresholdTriggerMs is required if .eventLatencyProcessed is in newFindCloudletEvents", log: OSLog.default, type: .debug)
                    return EdgeEventsError.invalidLatencyThreshold
                }
                // Validate latency test port
                if config!.latencyTestPort == nil {
                    os_log("latencyTestPort is required if .eventLatencyProcessed or .eventLatencyRequest are in newFindCloudletEvents. Using 0, which will test any port", log: OSLog.default, type: .debug)
                    config!.latencyTestPort = 0
                }
                // Validate latencyUpdateConfig .onInterval
                if latencyUpdateConfig.updatePattern == .onInterval {
                    guard let interval = latencyUpdateConfig.updateIntervalSeconds else {
                        os_log("nil updateIntervalSeconds in latencyUpdateConfig - a valid updateIntervalSeconds is required if updatePattern is .onInterval", log: OSLog.default, type: .debug)
                        return EdgeEventsError.missingUpdateInterval
                    }
                    if interval <= 0 {
                        os_log("updateIntervalSeconds is not a positive number in latencyUpdateConfig - a valid updateIntervalSeconds is required if updatePattern is .onInterval", log: OSLog.default, type: .debug)
                        return EdgeEventsError.invalidUpdateInterval
                    }
                    if latencyUpdateConfig.maxNumberOfUpdates == nil {
                        config!.latencyUpdateConfig!.maxNumberOfUpdates = 0
                    }
                    if latencyUpdateConfig.maxNumberOfUpdates! <= 0 {
                        os_log("maxNumberOfUpdates is <= 0, so latencyUpdates will occur until edgeevents is stopped", log: OSLog.default, type: .debug)
                    }
                }
            }
            
            
            // Check that if newFindCloudletEventTriggers contains .closerCloudlet valid location fields are populated
            if config!.newFindCloudletEventTriggers.contains(.closerCloudlet) {
                // Validate locationUpdateConfig
                guard let locationUpdateConfig = config!.locationUpdateConfig else {
                    os_log("A locationUpdateConfig is required if .eventCloudletUpdate is specified in newFindCloudletEvents", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingLocationUpdateConfig
                }
                // Validate locationUpdateConfig .onInterval
                if locationUpdateConfig.updatePattern == .onInterval {
                    guard let interval = locationUpdateConfig.updateIntervalSeconds else {
                        os_log("nil updateIntervalSeconds in locationUpdateConfig - a valid updateIntervalSeconds is required if updatePattern is .onInterval", log: OSLog.default, type: .debug)
                        return EdgeEventsError.missingUpdateInterval
                    }
                    if interval <= 0 {
                        os_log("updateIntervalSeconds is not a positive number in locationUpdateConfig - a valid updateIntervalSeconds is required if updatePattern is .onInterval", log: OSLog.default, type: .debug)
                        return EdgeEventsError.invalidUpdateInterval
                    }
                    if locationUpdateConfig.maxNumberOfUpdates == nil {
                        config!.locationUpdateConfig!.maxNumberOfUpdates = 0
                    }
                    if locationUpdateConfig.maxNumberOfUpdates! <= 0 {
                        os_log("maxNumberOfUpdates is <= 0, so locationUpdates will occur until edgeevents is stopped", log: OSLog.default, type: .debug)
                    }
                }
            }
            // No errors
            return nil
        }
        
        // Checks whether or not the newFindCloudletReply is the same as the current cloudlet
        func newCloudletIsDifferent(newCloudlet: DistributedMatchEngine_FindCloudletReply, oldCloudlet: DistributedMatchEngine_FindCloudletReply) -> Bool {
            return oldCloudlet.fqdn != newCloudlet.fqdn
        }
        
        // Helper function that calls the getLastLocation function and syncs lastStoredLocation
        func updateLastStoredLocation() -> Promise<DistributedMatchEngine_Loc> {
            return Promise<DistributedMatchEngine_Loc>(on: getLocationQueue) { fulfill, reject in
                let lastLoc = self.lastStoredLocation
                self.getLastLocation!().then { loc in
                    if lastLoc == loc {
                        reject(EdgeEventsError.gpsLocationDidNotChange)
                        return
                    }
                    self.lastStoredLocation = loc
                    fulfill(loc)
                }.catch { error in
                    os_log("cannot get location. using last known location", log: OSLog.default, type: .debug)
                    reject(error)
                }
            }
        }
        
        // Helper function that returns the shared lastStoredLocation
        func getLastStoredLocation() -> Promise<DistributedMatchEngine_Loc> {
            return Promise<DistributedMatchEngine_Loc>(on: getLocationQueue) { fulfill, reject in
                let lastLoc = self.lastStoredLocation
                fulfill(lastLoc)
            }
        }
    }
}
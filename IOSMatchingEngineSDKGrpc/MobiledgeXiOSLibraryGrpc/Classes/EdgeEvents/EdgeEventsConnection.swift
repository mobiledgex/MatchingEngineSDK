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
import GRPC
import os.log
import Promises

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.EdgeEvents {
    
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
        var lastLocation: DistributedMatchEngine_Loc? = nil
        
        var config: EdgeEventsConfig? = nil
        var stream: BidirectionalStreamingCall<DistributedMatchEngine_ClientEdgeEvent, DistributedMatchEngine_ServerEdgeEvent>? = nil
        var newFindCloudletHandler: ((EdgeEventsStatus, FindCloudletEvent?) -> Void)? = nil
        var serverEventsHandler: ((DistributedMatchEngine_ServerEdgeEvent) -> Void)? = nil
        var getLastLocation: (() -> DistributedMatchEngine_Loc?)? = nil
        
        // Initializer with EdgeEventsConfig (will be the suggested initializer)
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
        
        // Initializer without EdgeEventsConfig (only use for developers that need access to raw events and understand how to receive and send events)
        init(matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine, dmeHost: String, dmePort: UInt16, tlsEnabled: Bool, serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) {
            self.matchingEngine = matchingEngine
            self.host = dmeHost
            self.port = dmePort
            self.tlsEnabled = tlsEnabled
            self.serverEventsHandler = serverEventsHandler
            self.initializedWithConfig = false
        }
        
        public func start(timeoutMs: Double = 10000) -> Promise<EdgeEventsStatus> {
            // validate config and handlers
            let err = validateEdgeEvents()
            if err != nil {
                let promise = Promise<EdgeEventsStatus>.pending()
                promise.reject(err!)
                return promise
            }
            self.client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: host, port: port, tlsEnabled: tlsEnabled)
            // create bidirectional stream
            self.stream = client!.apiclient.streamEdgeEvent(callOptions: nil, handler: self.serverEventsHandler ?? handleServerEvents)
            // initialize init edgeevent
            var initMessage = DistributedMatchEngine_ClientEdgeEvent.init()
            initMessage.eventType = .eventInitConnection
            // check for valid lastFindCloudletReply
            guard let _ = matchingEngine.lastFindCloudletReply else {
                let promise = Promise<EdgeEventsStatus>.pending()
                promise.reject(EdgeEventsError.hasNotDoneFindCloudlet)
                return promise
            }
            // check for session cookie
            guard let sessionCookie = matchingEngine.state.getSessionCookie() else {
                let promise = Promise<EdgeEventsStatus>.pending()
                promise.reject(EdgeEventsError.missingSessionCookie)
                return promise
            }
            initMessage.sessionCookie = sessionCookie
            // check for edgeevents cookie
            guard let edgeEventsCookie = matchingEngine.state.getEdgeEventsCookie() else {
                let promise = Promise<EdgeEventsStatus>.pending()
                promise.reject(EdgeEventsError.missingEdgeEventsCookie)
                return promise
            }
            initMessage.edgeEventsCookie = edgeEventsCookie
            
            return Promise<EdgeEventsStatus>(on: matchingEngine.state.edgeEventsQueue) { fulfill, reject in
                do {
                    // add callback that checks that stream was successful in starting
                    self.stream!.status.whenSuccess { status in
                        os_log("edgeevents connection stopped. status is %@", log: OSLog.default, type: .debug, status.message ?? "")
                        self.cleanup()
                        if !status.isOk {
                            reject(status)
                        }
                    }
                    // send init message
                    let res = self.stream?.sendMessage(initMessage)
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
            }.timeout(timeoutMs/1000.0)
        }
        
        public func close() -> Promise<EdgeEventsStatus> {
            let promise = Promise<EdgeEventsStatus>.pending()
            // send terminate connection
            var terminateEdgeEvent = DistributedMatchEngine_ClientEdgeEvent.init()
            terminateEdgeEvent.eventType = .eventTerminateConnection
            let res = stream?.sendMessage(terminateEdgeEvent)
            do {
                try res!.wait()
            } catch {
                promise.reject(error)
                return promise
            }
            cleanup()
            promise.fulfill(.success)
            return promise
        }
        
        public func cleanup() {
            // close grpc client and clean up variables
            latencyTimer?.cancel()
            latencyTimer = nil
            locationTimer?.cancel()
            locationTimer = nil
            connectionReady = false
            connectionClosed = true
            MobiledgeXiOSLibraryGrpc.closeGrpcClient(client: client!)
        }
        
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
        
        public func postLocationUpdate(loc: DistributedMatchEngine_Loc) -> Promise<EdgeEventsStatus> {
            // initialize location edgeevent
            var locationEdgeEvent = DistributedMatchEngine_ClientEdgeEvent.init()
            locationEdgeEvent.eventType = .eventLocationUpdate
            locationEdgeEvent.gpsLocation = loc
            locationEdgeEvent.deviceInfo = matchingEngine.getDeviceInfo()
            
            return Promise<EdgeEventsStatus>(on: self.matchingEngine.state.edgeEventsQueue) { fulfill, reject in
                if self.connectionReady && !self.connectionClosed {
                    do {
                        let res = self.stream?.sendMessage(locationEdgeEvent)
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
                        let res = self.stream?.sendMessage(latencyEdgeEvent)
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
            case .eventLatencyRequest:
                os_log("latencyrequest", log: OSLog.default, type: .debug)
                var loc = getLastLocation!()
                if loc == nil {
                    os_log("cannot get location. using last known location", log: OSLog.default, type: .debug)
                    loc = lastLocation
                }
                self.testConnectAndPostLatencyUpdate(testPort: self.config!.latencyTestPort, loc: loc!).then { status in
                    os_log("successfully test connect and post latency update", log: OSLog.default, type: .debug)
                }.catch { error in
                    os_log("error testing connect and posting latency update: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                    self.sendErrorToHandler(error: error)
                }
            case .eventLatencyProcessed:
                os_log("latencyprocessed", log: OSLog.default, type: .debug)
                print("latency stats are \(event.statistics)")
                if config!.newFindCloudletEvents.contains(event.eventType) {
                    let stats = event.statistics
                    if stats.avg >= config!.latencyThresholdTriggerMs! {
                        sendFindCloudletToHandler(eventType: .latencyTooHigh)
                    }
                }
            case .eventCloudletState:
                os_log("cloudletstate", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEvents.contains(event.eventType) && event.cloudletState != .ready {
                    sendFindCloudletToHandler(eventType: .cloudletStateChanged)
                }
            case .eventCloudletMaintenance:
                os_log("cloudletmaintenance", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEvents.contains(event.eventType) && event.maintenanceState != .normalOperation {
                    sendFindCloudletToHandler(eventType: .cloudletMaintenanceStateChanged)
                }
            case .eventAppinstHealth:
                os_log("appinsthealth", log: OSLog.default, type: .debug)
                if config!.newFindCloudletEvents.contains(event.eventType) && event.healthCheck != .ok {
                    sendFindCloudletToHandler(eventType: .appInstHealthChanged)
                }
            case .eventCloudletUpdate:
                os_log("cloudletupdate", log: OSLog.default, type: .debug)
                sendFindCloudletToHandler(eventType: .closerCloudlet, newCloudlet: event.newCloudlet)
            case .eventUnknown:
                os_log("eventUnknown", log: OSLog.default, type: .debug)
            default:
                os_log("default case, event: %@", log: OSLog.default, type: .debug, event.eventType.rawValue)
            }
        }
        
        func sendFindCloudletToHandler(eventType: FindCloudletEventTrigger, newCloudlet: DistributedMatchEngine_FindCloudletReply? = nil) {
            if newCloudlet != nil && eventType == .closerCloudlet {
                let findCloudletEvent = FindCloudletEvent(newCloudlet: newCloudlet!, trigger: eventType)
                matchingEngine.lastFindCloudletReply = newCloudlet
                restart().then { status in
                    self.newFindCloudletHandler!(.success, findCloudletEvent)
                }
            } else {
                do {
                    var loc = getLastLocation!()
                    if loc == nil {
                        os_log("cannot get location. using last known location", log: OSLog.default, type: .debug)
                        loc = lastLocation
                    }
                    let req = try matchingEngine.createFindCloudletRequest(gpsLocation: loc!)
                    matchingEngine.findCloudlet(host: host, port: port, request: req, mode: MobiledgeXiOSLibraryGrpc.MatchingEngine.FindCloudletMode.PERFORMANCE).then { reply -> Promise<EdgeEventsStatus> in
                        if self.matchingEngine.lastFindCloudletReply!.fqdn == reply.fqdn {
                            let promise = Promise<EdgeEventsStatus>.pending()
                            promise.fulfill(.fail(error: EdgeEventsError.eventTriggeredButCurrentCloudletIsBest))
                            return promise
                        } else {
                            self.matchingEngine.lastFindCloudletReply = reply
                            return self.restart()
                        }
                    }.then { status in
                        if status == .success {
                            let findCloudletEvent = FindCloudletEvent(newCloudlet: self.matchingEngine.lastFindCloudletReply!, trigger: eventType)
                            self.newFindCloudletHandler!(.success, findCloudletEvent)
                        } else {
                            self.newFindCloudletHandler!(status, nil)
                        }
                    }
                } catch {
                    os_log("received server event: %@, but error doing findcloudlet: %@", log: OSLog.default, type: .debug, eventType as! CVarArg, error.localizedDescription)
                    newFindCloudletHandler!(.fail(error: error), nil)
                }
            }
        }
        
        func sendErrorToHandler(error: Error) {
            self.newFindCloudletHandler!(.fail(error: error), nil)
        }
        
        func startSendClientEvents() {
            // Set up latency update timer
            let latencyConfig = config!.latencyUpdateConfig
            switch latencyConfig.updatePattern {
            case .onStart:
                var loc = getLastLocation!()
                if loc == nil {
                    os_log("cannot get location. using last known location", log: OSLog.default, type: .debug)
                    loc = lastLocation
                }
                matchingEngine.state.edgeEventsQueue.async {
                    self.testPingAndPostLatencyUpdate(testPort: self.config!.latencyTestPort, loc: loc!).then { status in
                        os_log("successfully test connect and post latency update", log: OSLog.default, type: .debug)
                    }.catch { error in
                        os_log("error testing connect and posting latency update: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                    }
                }
            case .onInterval:
                latencyTimer = DispatchSource.makeTimerSource(queue: matchingEngine.state.edgeEventsQueue)
                latencyTimer!.setEventHandler(handler: {
                    if self.currLatencyInterval < latencyConfig.maxNumberOfUpdates! || latencyConfig.maxNumberOfUpdates! <= 0 {
                        var loc = self.getLastLocation!()
                        if loc == nil {
                            os_log("cannot get location. using last known location", log: OSLog.default, type: .debug)
                            loc = self.lastLocation
                        }
                        self.testConnectAndPostLatencyUpdate(testPort: self.config!.latencyTestPort, loc: loc!).then { status in
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
            
            // Set up location update timer
            let locationConfig = config!.locationUpdateConfig
            switch locationConfig.updatePattern {
            case .onStart:
                var loc = getLastLocation!()
                if loc == nil {
                    os_log("cannot get location. using last known location", log: OSLog.default, type: .debug)
                    loc = lastLocation
                }
                matchingEngine.state.edgeEventsQueue.async {
                    self.postLocationUpdate(loc: loc!).then { status in
                        os_log("successfully post location update", log: OSLog.default, type: .debug)
                    }.catch { error in
                        os_log("error posting location update: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                    }
                }
            case .onInterval:
                locationTimer = DispatchSource.makeTimerSource(queue: matchingEngine.state.edgeEventsQueue)
                locationTimer!.setEventHandler(handler: {
                    if self.currLocationInterval < locationConfig.maxNumberOfUpdates! || locationConfig.maxNumberOfUpdates! <= 0 {
                        var loc = self.getLastLocation!()
                        if loc == nil {
                            os_log("cannot get location. using last known location", log: OSLog.default, type: .debug)
                            loc = self.lastLocation
                        }
                        self.postLocationUpdate(loc: loc!).then { status in
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
        
        func validateEdgeEvents() -> Error? {
            if initializedWithConfig {
                // Check config and callbacks if using EdgeEventsConfig
                let err = validateEdgeEventsConfig()
                if err != nil {
                    return err
                }
                guard let _ = newFindCloudletHandler else {
                    os_log("nil newFindCloudletHandler - a valid newFindCloudletHandler is required receive events", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingNewFindCloudletHandler
                }
                guard let _ = getLastLocation else {
                    os_log("nil getLastLocation function - a valid getLastLocation function is required to send client events", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingGetLastLocationFunction
                }
                lastLocation = getLastLocation!()
                guard let _ = lastLocation else {
                    os_log("nil last location - a valid return value from getLastLocation is required to send client events", log: OSLog.default, type: .debug)
                    return EdgeEventsError.unableToGetLastLocation
                }
                return nil
            } else {
                // Check that serverEventsHandler is non nil if no EdgeEventsConfig
                guard let _ = serverEventsHandler else {
                    os_log("nil serverEventsHandler function - a valid serverEventsHandler function is required to receive server events", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingServerEventsHandler
                }
                return nil
            }
        }
        
        func validateEdgeEventsConfig() -> Error? {
            // Check that config is non nil
            guard let _ = config else {
                os_log("nil EdgeEventsConfig - a valid EdgeEventsConfig is required to send client events", log: OSLog.default, type: .debug)
                return EdgeEventsError.missingEdgeEventsConfig
            }
            // Check that if newFindCloudletEvents contains .eventLatencyProcessed that there is a valid latency threshold
            if config!.newFindCloudletEvents.contains(.eventLatencyProcessed) {
                guard let threshold = config!.latencyThresholdTriggerMs else {
                    os_log("nil latencyThresholdTriggerMs - a valid latencyThresholdTriggerMs is required if .eventLatencyProcessed is in newFindCloudletEvents", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingLatencyThreshold
                }
                if threshold <= 0 {
                    os_log("latencyThresholdTriggerMs is not a positive number - a valid latencyThresholdTriggerMs is required if .eventLatencyProcessed is in newFindCloudletEvents", log: OSLog.default, type: .debug)
                    return EdgeEventsError.invalidLatencyThreshold
                }
            }
            // Validate latencyUpdateConfig
            if config!.latencyUpdateConfig.updatePattern == .onInterval {
                guard let interval = config!.latencyUpdateConfig.updateIntervalSeconds else {
                    os_log("nil updateIntervalSeconds in latencyUpdateConfig - a valid updateIntervalSeconds is required if updatePattern is .onInterval", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingUpdateInterval
                }
                if interval <= 0 {
                    os_log("updateIntervalSeconds is not a positive number in latencyUpdateConfig - a valid updateIntervalSeconds is required if updatePattern is .onInterval", log: OSLog.default, type: .debug)
                    return EdgeEventsError.invalidUpdateInterval
                }
                if config!.latencyUpdateConfig.maxNumberOfUpdates == nil {
                    config!.latencyUpdateConfig.maxNumberOfUpdates = 0
                }
                if config!.latencyUpdateConfig.maxNumberOfUpdates! <= 0 {
                    os_log("maxNumberOfUpdates is <= 0, so latencyUpdates will occur until edgeevents is stopped", log: OSLog.default, type: .debug)
                }
            }
            // Validate locationUpdateConfig
            if config!.locationUpdateConfig.updatePattern == .onInterval {
                guard let interval = config!.locationUpdateConfig.updateIntervalSeconds else {
                    os_log("nil updateIntervalSeconds in locationUpdateConfig - a valid updateIntervalSeconds is required if updatePattern is .onInterval", log: OSLog.default, type: .debug)
                    return EdgeEventsError.missingUpdateInterval
                }
                if interval <= 0 {
                    os_log("updateIntervalSeconds is not a positive number in locationUpdateConfig - a valid updateIntervalSeconds is required if updatePattern is .onInterval", log: OSLog.default, type: .debug)
                    return EdgeEventsError.invalidUpdateInterval
                }
                if config!.locationUpdateConfig.maxNumberOfUpdates == nil {
                    config!.locationUpdateConfig.maxNumberOfUpdates = 0
                }
                if config!.locationUpdateConfig.maxNumberOfUpdates! <= 0 {
                    os_log("maxNumberOfUpdates is <= 0, so locationUpdates will occur until edgeevents is stopped", log: OSLog.default, type: .debug)
                }
            }
            // No errors
            return nil
        }
    }
}

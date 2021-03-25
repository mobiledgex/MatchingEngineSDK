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

extension MobiledgeXiOSLibraryGrpc.EdgeEvents {
    
    public class EdgeEventsConnection {
        
        var count = 0
        
        var matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine
        var client: MobiledgeXiOSLibraryGrpc.GrpcClient
        var host: String
        var port: UInt16
        var tlsEnabled = true
        
        var connectionInitialized = false
        var connectionClosed = false
        var initializedWithConfig: Bool
        
        // TODO DELETE
        var sentLocation = false
        var sentLatency = false
        
        var latencyTimer: DispatchSourceTimer? = nil
        var locationTimer: DispatchSourceTimer? = nil
        
        var config: EdgeEventsConfig? = nil
        var stream: BidirectionalStreamingCall<DistributedMatchEngine_ClientEdgeEvent, DistributedMatchEngine_ServerEdgeEvent>? = nil
        var newFindCloudletHandler: ((DistributedMatchEngine_FindCloudletReply) -> Void)? = nil
        var serverEventsHandler: ((DistributedMatchEngine_ServerEdgeEvent) -> Void)? = nil
                
        init(matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine, host: String, port: UInt16, tlsEnabled: Bool, newFindCloudletHandler: @escaping ((DistributedMatchEngine_FindCloudletReply) -> Void), config: EdgeEventsConfig) {
            self.matchingEngine = matchingEngine
            self.config = config
            self.host = host
            self.port = port
            self.tlsEnabled = tlsEnabled
            self.newFindCloudletHandler = newFindCloudletHandler
            self.initializedWithConfig = true
            self.client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: host, port: port, tlsEnabled: tlsEnabled)
        }
        
        init(matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine, host: String, port: UInt16, tlsEnabled: Bool, serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) {
            self.matchingEngine = matchingEngine
            self.host = host
            self.port = port
            self.tlsEnabled = tlsEnabled
            self.serverEventsHandler = serverEventsHandler
            self.initializedWithConfig = false
            self.client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: host, port: port, tlsEnabled: tlsEnabled)
        }
        
        func start(timeoutMs: Double = 10000) -> Promise<Bool> {
            self.stream = client.apiclient.streamEdgeEvent(callOptions: nil, handler: self.serverEventsHandler ?? handleServerEvents)
            var initMessage = DistributedMatchEngine_ClientEdgeEvent.init()
            initMessage.eventType = .eventInitConnection
            // TODO: HANDLE NIL COOKIES
            initMessage.sessionCookie = self.matchingEngine.state.getSessionCookie()!
            initMessage.edgeEventsCookie = self.matchingEngine.state.getEdgeEventsCookie()!
            
            return Promise<Bool>(on: self.matchingEngine.state.executionQueue) { fulfill, reject in
                do {
                    self.stream!.status.whenSuccess { status in
                        if status != .ok {
                            reject(status)
                        }
                        os_log("successful edgeevents status received", log: OSLog.default, type: .debug)
                    }
                    
                    let res = self.stream?.sendMessage(initMessage)
                    try res!.wait()
                    while true {
                        if self.connectionInitialized {
                            break
                        }
                    }
                    self.startSendClientEvents()
                    while !self.sentLatency || !self.sentLocation {
                        
                    }
                    fulfill(true)
                } catch {
                    reject(error)
                }
            }.timeout(timeoutMs/1000.0)
        }
        
        public func close() {
            // send terminate connection
            MobiledgeXiOSLibraryGrpc.closeGrpcClient(client: self.client)
            self.connectionClosed = true
            self.latencyTimer = nil
            self.locationTimer = nil
        }
        
        public func postLocationUpdate() {
            
        }
        
        public func postLatencyUpdate() {
            
        }
        
        public func testPingAndPostLatencyUpdate() {
            
        }
        
        public func testConnectAndPostLatencyUpdate() {
            
        }
        
        func handleServerEvents(event: DistributedMatchEngine_ServerEdgeEvent) {
            switch event.eventType {
            case .eventInitConnection:
                os_log("initconnection", log: OSLog.default, type: .debug)
                self.connectionInitialized = true
            case .eventLatencyRequest:
                os_log("latencyrequest", log: OSLog.default, type: .debug)
            case .eventLatencyProcessed:
                os_log("latencyprocessed", log: OSLog.default, type: .debug)
            case .eventCloudletState:
                os_log("cloudletstate", log: OSLog.default, type: .debug)
            case .eventCloudletMaintenance:
                os_log("cloudletmaintenance", log: OSLog.default, type: .debug)
            case .eventAppinstHealth:
                os_log("appinsthealth", log: OSLog.default, type: .debug)
            case .eventCloudletUpdate:
                os_log("cloudletupdate", log: OSLog.default, type: .debug)
            case .eventUnknown:
                os_log("unknown", log: OSLog.default, type: .debug)
            default:
                os_log("default", log: OSLog.default, type: .debug)
            }
            sendFindCloudletToHandler()
        }
        
        func sendFindCloudletToHandler() {
            //self.matchingEngine.findCloudlet(host: self.host, port: self.port, request: nil)
            var fakeReply = DistributedMatchEngine_FindCloudletReply.init()
            fakeReply.status = DistributedMatchEngine_FindCloudletReply.FindStatus.findFound
            fakeReply.edgeEventsCookie = "blahblah"
            self.newFindCloudletHandler!(fakeReply)
        }
        
        // Must be called with DispathQueue.async???
        func startSendClientEvents() {
            os_log("start send client events", log: OSLog.default, type: .debug)
            self.latencyTimer = DispatchSource.makeTimerSource(queue: self.matchingEngine.state.executionQueue)
            self.latencyTimer!.setEventHandler(handler: {
                os_log("latency timer fired", log: OSLog.default, type: .debug)
                if self.count == 2 {
                    self.sentLatency = true
                }
                self.count += 1
            })
            self.latencyTimer!.schedule(deadline: .now(), repeating: .seconds(2), leeway: .milliseconds(100))
            self.latencyTimer!.resume()
            
            
            self.locationTimer = DispatchSource.makeTimerSource(queue: self.matchingEngine.state.executionQueue)
            self.locationTimer!.setEventHandler(handler: {
                os_log("location timer fired", log: OSLog.default, type: .debug)
                self.sentLocation = true
            })
            self.locationTimer!.schedule(deadline: .now(), repeating: .seconds(3), leeway: .milliseconds(100))
            self.locationTimer!.resume()
        }
    }
}

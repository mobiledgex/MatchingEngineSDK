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

extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    public class EdgeEventsConnection {
        
        var client: GrpcClient
        var host: String
        var port: UInt16
        var tlsEnabled = true
        
        var connectionInitialized = false
        
        var config: EdgeEventsConfig
        var stream: BidirectionalStreamingCall<DistributedMatchEngine_ClientEdgeEvent, DistributedMatchEngine_ServerEdgeEvent>? = nil
                
        public init(config: EdgeEventsConfig, host: String, port: UInt16, tlsEnabled: Bool) {
            self.config = config
            self.host = host
            self.port = port
            self.tlsEnabled = tlsEnabled
            self.client = MobiledgeXiOSLibraryGrpc.MatchingEngine.getGrpcClient(host: host, port: port, tlsEnabled: tlsEnabled)
        }
        
        public func start(rcReply: DistributedMatchEngine_RegisterClientReply, fcReply: DistributedMatchEngine_FindCloudletReply) -> Promise<Bool> {
            self.stream = client.apiclient.streamEdgeEvent(callOptions: nil, handler: handleServerEvents)
            var initMessage = DistributedMatchEngine_ClientEdgeEvent.init()
            initMessage.eventType = .eventInitConnection
            initMessage.sessionCookie = rcReply.sessionCookie
            initMessage.edgeEventsCookie = fcReply.edgeEventsCookie
            
            return Promise<Bool>(on: DispatchQueue.global(qos: .default)) { fulfill, reject in
                do {
                    self.stream!.status.whenSuccess { status in
                        if status != .ok {
                            reject(status)
                        }
                        os_log("successful edgeevents status received", log: OSLog.default, type: .debug)
                    }
                    
                    let res = self.stream?.sendMessage(initMessage)
                    try res!.wait()
                    while (!self.connectionInitialized) {
                        
                    }
                    fulfill(true)
                } catch {
                    reject(error)
                }
            }
        }
        
        public func close() {
            MobiledgeXiOSLibraryGrpc.MatchingEngine.closeGrpcClient(client: self.client)
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
        }
    }
    
    public struct EdgeEventsConfig {
        
    }
    
    public struct ClientEventsConfig {
        var updatePattern: Int
        var updateInterval: Double
        var numberOfUpdates: Int
    }
    
    public func getDefaultEdgeEventsConfig() -> EdgeEventsConfig {
        return EdgeEventsConfig()
    }
    
    public func initializeEdgeEvents(config: EdgeEventsConfig? = nil) {
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            // Handle error
            return
        }
        let port = DMEConstants.dmeGrpcPort
        initializeEdgeEvents(host: host, port: port, config: config)
    }
    
    public func initializeEdgeEvents(host: String, port: UInt16, config: EdgeEventsConfig? = nil) {
        var eeConfig = config
        if config == nil {
            eeConfig = getDefaultEdgeEventsConfig()
        }
        
        self.edgeEventsConnection = EdgeEventsConnection.init(config: eeConfig!, host: host, port: port, tlsEnabled: self.tlsEnabled)
    }
}

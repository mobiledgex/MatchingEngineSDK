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
//  InitializeEdgeEvents.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    public func initializeEdgeEvents(newFindCloudletHandler: @escaping ((DistributedMatchEngine_FindCloudletReply) -> Void), config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig? = nil) {
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            // Handle error
            return
        }
        let port = DMEConstants.dmeGrpcPort
        initializeEdgeEvents(host: host, port: port, newFindCloudletHandler: newFindCloudletHandler, config: config)
    }
    
    public func initializeEdgeEvents(host: String, port: UInt16, newFindCloudletHandler: @escaping ((DistributedMatchEngine_FindCloudletReply) -> Void), config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig? = nil) {
        var eeConfig = config
        if config == nil {
            eeConfig = MobiledgeXiOSLibraryGrpc.EdgeEvents.getDefaultEdgeEventsConfig()
        }
        
        self.edgeEventsConnection = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection.init(matchingEngine: self, host: host, port: port, tlsEnabled: self.tlsEnabled, newFindCloudletHandler: newFindCloudletHandler, config: eeConfig!)
    }
    
    public func initializeEdgeEventsWithoutConfig(serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) {
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            // Handle error
            return
        }
        let port = DMEConstants.dmeGrpcPort
        initializeEdgeEventsWithoutConfig(host: host, port: port, serverEventsHandler: serverEventsHandler)
    }
    
    public func initializeEdgeEventsWithoutConfig(host: String, port: UInt16, serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) {
        self.edgeEventsConnection = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection.init(matchingEngine: self, host: host, port: port, tlsEnabled: self.tlsEnabled, serverEventsHandler: serverEventsHandler)
    }
    
    public func startEdgeEvents() -> Promise<Bool> {
        if self.edgeEventsConnection == nil {
            // log
            return Promise<Bool>.init(false)
        }
        return self.edgeEventsConnection!.start()
    }
}

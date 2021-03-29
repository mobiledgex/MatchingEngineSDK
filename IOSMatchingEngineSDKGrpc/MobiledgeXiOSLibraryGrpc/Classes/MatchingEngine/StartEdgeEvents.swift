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
//  StartEdgeEvents.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    @available(iOS 13.0, *)
    public func startEdgeEvents(newFindCloudletHandler: @escaping ((DistributedMatchEngine_FindCloudletReply) -> Void), config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig? = nil) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promise.reject(error)
            return promise
        }
        let port = DMEConstants.dmeGrpcPort
        return startEdgeEvents(host: host, port: port, newFindCloudletHandler: newFindCloudletHandler, config: config)
    }
    
    @available(iOS 13.0, *)
    public func startEdgeEvents(host: String, port: UInt16, newFindCloudletHandler: @escaping ((DistributedMatchEngine_FindCloudletReply) -> Void), config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig? = nil) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        var eeConfig = config
        if config == nil {
            eeConfig = MobiledgeXiOSLibraryGrpc.EdgeEvents.getDefaultEdgeEventsConfig()
        }
        
        self.edgeEventsConnection = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection.init(matchingEngine: self, host: host, port: port, tlsEnabled: self.tlsEnabled, newFindCloudletHandler: newFindCloudletHandler, config: eeConfig!)
        guard let _ = self.edgeEventsConnection else {
            let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
            promise.reject(MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.uninitializedEdgeEventsConnection)
            return promise
        }
        return self.edgeEventsConnection!.start()
    }
    
    @available(iOS 13.0, *)
    public func startEdgeEventsWithoutConfig(serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promise.reject(error)
            return promise
        }
        let port = DMEConstants.dmeGrpcPort
        return startEdgeEventsWithoutConfig(host: host, port: port, serverEventsHandler: serverEventsHandler)
    }
    
    @available(iOS 13.0, *)
    public func startEdgeEventsWithoutConfig(host: String, port: UInt16, serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        self.edgeEventsConnection = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection.init(matchingEngine: self, host: host, port: port, tlsEnabled: self.tlsEnabled, serverEventsHandler: serverEventsHandler)
        guard let eeConn = self.edgeEventsConnection else {
            let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
            promise.reject(MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.uninitializedEdgeEventsConnection)
            return promise
        }
        return eeConn.start()
    }
    
    public func stopEdgeEvents() -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        guard let eeConn = self.edgeEventsConnection else {
            let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
            promise.reject(MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.uninitializedEdgeEventsConnection)
            return promise
        }
        return eeConn.close()
    }
    
    @available(iOS 13.0, *)
    public func restartEdgeEvents() -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promise.reject(error)
            return promise
        }
        let port = DMEConstants.dmeGrpcPort
        return restartEdgeEvents(host: host, port: port)
    }
    
    @available(iOS 13.0, *)
    public func restartEdgeEvents(host: String, port: UInt16) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        return stopEdgeEvents().then { status -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> in
            guard let eeConn = self.edgeEventsConnection else {
                let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
                promise.reject(MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.uninitializedEdgeEventsConnection)
                return promise
            }
            return eeConn.start()
        }
    }
    
    public func getEdgeEventsConnection() -> MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection? {
        return self.edgeEventsConnection
    }
}

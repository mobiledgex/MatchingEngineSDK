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

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    public func startEdgeEvents(newFindCloudletHandler: @escaping ((MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus, DistributedMatchEngine_FindCloudletReply?) -> Void), config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
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
    
    public func startEdgeEvents(host: String, port: UInt16, newFindCloudletHandler: @escaping ((MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus, DistributedMatchEngine_FindCloudletReply?) -> Void), config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        self.edgeEventsConnection = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection.init(matchingEngine: self, host: host, port: port, tlsEnabled: self.tlsEnabled, newFindCloudletHandler: newFindCloudletHandler, config: config)
        guard let _ = self.edgeEventsConnection else {
            let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
            promise.reject(MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.uninitializedEdgeEventsConnection)
            return promise
        }
        return self.edgeEventsConnection!.start()
    }
    
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
    
    public func switchedToNewCloudlet() -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promise.reject(error)
            return promise
        }
        let port = DMEConstants.dmeGrpcPort
        return switchedToNewCloudlet(host: host, port: port)
    }
    
    public func switchedToNewCloudlet(host: String, port: UInt16) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
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
    
    public func createDefaultEdgeEventsConfig(latencyUpdateIntervalSeconds: UInt, locationUpdateIntervalSeconds: UInt, latencyThresholdTriggerMs: Double) -> MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig {
        let newFindCloudletEvents: Set = [DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventCloudletState, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventCloudletMaintenance, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventAppinstHealth, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventLatencyProcessed]
        let latencyUpdateConfig = MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig(updatePattern: .onInterval, updateIntervalSeconds: latencyUpdateIntervalSeconds, maxNumberOfUpdates: 0)
        let locationUpdateConfig = MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig(updatePattern: .onInterval, updateIntervalSeconds: locationUpdateIntervalSeconds, maxNumberOfUpdates: 0)
        
        let config = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig(newFindCloudletEvents: newFindCloudletEvents, latencyThresholdTriggerMs: latencyThresholdTriggerMs, latencyTestPort: 0, latencyUpdateConfig: latencyUpdateConfig, locationUpdateConfig: locationUpdateConfig)
        return config
    }
    
    public func createEdgeEventsConfig(newFindCloudletEvents: Set<DistributedMatchEngine_ServerEdgeEvent.ServerEventType>, latencyThresholdTriggerMs: Double?, latencyTestPort: UInt16, latencyUpdateConfig: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig, locationUpdateConfig: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig) -> MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig {
        let config = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig(newFindCloudletEvents: newFindCloudletEvents, latencyThresholdTriggerMs: latencyThresholdTriggerMs, latencyTestPort: latencyTestPort, latencyUpdateConfig: latencyUpdateConfig, locationUpdateConfig: locationUpdateConfig)
        return config
    }
    
    public func createClientEventsConfig(updatePattern: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig.UpdatePattern, updateIntervalSeconds: UInt?, maxNumberOfUpdates: Int? = 0) -> MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig {
        let config = MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig(updatePattern: updatePattern, updateIntervalSeconds: updateIntervalSeconds, maxNumberOfUpdates: maxNumberOfUpdates)
        return config
    }
    
    public func setAutoMigrationEdgeEventsConnection(autoMigrate: Bool) {
        autoMigrationEdgeEventsConnection = autoMigrate
    }
}

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
    
    /// API startEdgeEvents
    /// Starts persistent EdgeEvents connection between client and DME. This connection is used to provide events/information to the client about the application backend.
    /// After starting EdgeEvents and based on the EdgeEventsConfig provided, the MobiledgeX SDK will find a new cloudlet for the client on the specified events.
    /// The new cloudlet will be returned to the client via the newFindCloudletHandler.
    /// For example, if .eventCloudletState is specified in EdgeEventsConfig in the set of newFindCloudletEvents, a new cloudlet will be provided to the newFindCloudletHandler when the cloudlet state changes.
    /// Also, if specified in the EdgeEventsConfig, the SDK will periodically monitor gps location and latency to the application backend. If there is a closer cloudlet or a cloudlet with lower latency from the client, that cloudlet will be provided to the
    /// newFindCloudletHandler
    ///
    /// Workflow should be registerClient -> findCloudlet -> startEdgeEvents
    ///
    /// - Parameters:
    ///   - newFindCloudletHandler: ((MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus, MobiledgeXiOSLibraryGrpc.EdgeEvents.FindCloudletEvent?) -> Void): Function that handles a new, better cloudlet for the current user (eg. Switch over application connection to the new fqdn)
    ///   - config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig: EdgeEvents Configuration. Allows configuration of which events to look for a new cloudlet and how often the client sends latency and gps location updates to DME. Recommeded to get config from matchingEngine.createDefaultEdgeEventsConfig()
    /// - Returns: Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>
    public func startEdgeEvents(newFindCloudletHandler: @escaping ((MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus, MobiledgeXiOSLibraryGrpc.EdgeEvents.FindCloudletEvent?) -> Void), config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promise.reject(error)
            return promise
        }
        let port = DMEConstants.dmeGrpcPort
        return startEdgeEvents(dmeHost: host, dmePort: port, newFindCloudletHandler: newFindCloudletHandler, config: config)
    }
    
    /// API startEdgeEvents
    /// Starts persistent EdgeEvents connection between client and DME. This connection is used to provide events/information to the client about the application backend.
    /// After starting EdgeEvents and based on the EdgeEventsConfig provided, the MobiledgeX SDK will find a new cloudlet for the client on the specified events.
    /// The new cloudlet will be returned to the client via the newFindCloudletHandler.
    /// For example, if .eventCloudletState is specified in EdgeEventsConfig in the set of newFindCloudletEvents, a new cloudlet will be provided to the newFindCloudletHandler when the cloudlet state changes.
    /// Also, if specified in the EdgeEventsConfig, the SDK will periodically monitor gps location and latency to the application backend. If there is a closer cloudlet or a cloudlet with lower latency from the client, that cloudlet will be provided to the
    /// newFindCloudletHandler
    ///
    /// Workflow should be registerClient -> findCloudlet -> startEdgeEvents
    ///
    /// - Parameters:
    ///   - dmeHost: host override of the dme host server. DME must be reachable from current carrier.
    ///   - dmePort: port override of the dme server port
    ///   - newFindCloudletHandler: ((MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus, MobiledgeXiOSLibraryGrpc.EdgeEvents.FindCloudletEvent?) -> Void): Function that handles a new, better cloudlet for the current user (eg. Switch over application connection to the new fqdn)
    ///   - config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig: EdgeEvents Configuration. Allows configuration of which events to look for a new cloudlet and how often the client sends latency and gps location updates to DME. Recommeded to get config from matchingEngine.createDefaultEdgeEventsConfig()
    /// - Returns: Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>
    public func startEdgeEvents(dmeHost: String, dmePort: UInt16, newFindCloudletHandler: @escaping ((MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus, MobiledgeXiOSLibraryGrpc.EdgeEvents.FindCloudletEvent?) -> Void), config: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        self.edgeEventsConnection = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection.init(matchingEngine: self, dmeHost: dmeHost, dmePort: dmePort, tlsEnabled: self.tlsEnabled, newFindCloudletHandler: newFindCloudletHandler, config: config)
        guard let _ = self.edgeEventsConnection else {
            let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
            promise.reject(MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.uninitializedEdgeEventsConnection)
            return promise
        }
        return self.edgeEventsConnection!.start()
    }
    
    /// API startEdgeEventsWithoutConfig
    /// This API is not recommended. The recommended API is startEdgeEvents
    /// Starts persistent EdgeEvents connection between client and DME. This connection is used to provide events/information to the client about the application backend.
    /// The application provided serverEventsHandler will handle receipt of ServerEdgeEvents
    /// To send ClientEdgeEvents, the application must grab the edgeEventsConnection via getEdgeEventsConnection() and then use the provided postLatencyUpdate, postLocationUpdate, testConnectAndPostLatencyUpdate functions
    ///
    /// - Parameters:
    ///   - serverEventsHandler: ((DistributedMatchEngine_ServerEdgeEvent) -> Void): Function that handles application logic on receipt of server events
    /// - Returns: Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>
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
        return startEdgeEventsWithoutConfig(dmeHost: host, dmePort: port, serverEventsHandler: serverEventsHandler)
    }
    
    /// API startEdgeEventsWithoutConfig
    /// This API is not recommended. The recommended API is startEdgeEvents
    /// Starts persistent EdgeEvents connection between client and DME. This connection is used to provide events/information to the client about the application backend.
    /// The application provided serverEventsHandler will handle receipt of ServerEdgeEvents
    /// To send ClientEdgeEvents, the application must grab the edgeEventsConnection via getEdgeEventsConnection() and then use the provided postLatencyUpdate, postLocationUpdate, testConnectAndPostLatencyUpdate functions
    ///
    /// - Parameters:
    ///   - dmeHost: host override of the dme host server. DME must be reachable from current carrier.
    ///   - dmePort: port override of the dme server port
    ///   - serverEventsHandler: ((DistributedMatchEngine_ServerEdgeEvent) -> Void): Function that handles application logic on receipt of server events
    /// - Returns: Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>
    public func startEdgeEventsWithoutConfig(dmeHost: String, dmePort: UInt16, serverEventsHandler: @escaping ((DistributedMatchEngine_ServerEdgeEvent) -> Void)) -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        self.edgeEventsConnection = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection.init(matchingEngine: self, dmeHost: dmeHost, dmePort: dmePort, tlsEnabled: self.tlsEnabled, serverEventsHandler: serverEventsHandler)
        guard let eeConn = self.edgeEventsConnection else {
            let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
            promise.reject(MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.uninitializedEdgeEventsConnection)
            return promise
        }
        return eeConn.start()
    }
    
    /// API stopEdgeEvents
    /// Stops the persistent EdgeEvents connection between client and DME
    ///
    /// - Returns: Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>
    public func stopEdgeEvents() -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> {
        guard let eeConn = self.edgeEventsConnection else {
            let promise = Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>.pending()
            promise.reject(MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.uninitializedEdgeEventsConnection)
            return promise
        }
        return eeConn.close()
    }
    
    /// By default, autoMigrationEdgeEventsConnection is true, which means that when a new cloudlet is found, the MobiledgeX SDK will automatically switch the EdgeEventsConnection to monitor and receive events from the new cloudlet
    /// However, if autoMigrationEdgeEventsConnection is set to false, it is up to the application to call switchedToNewCloudlet after it switches over to the new cloudlet so that the SDK can receive events from the new cloudlet.
    ///
    /// - Returns: Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>
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
    
    /// By default, autoMigrationEdgeEventsConnection is true, which means that when a new cloudlet is found, the MobiledgeX SDK will automatically switch the EdgeEventsConnection to monitor and receive events from the new cloudlet
    /// However, if autoMigrationEdgeEventsConnection is set to false, it is up to the application to call switchedToNewCloudlet after it switches over to the new cloudlet so that the SDK can receive events from the new cloudlet.
    ///
    /// - Parameters:
    ///   - dmeHost: host override of the dme host server. DME must be reachable from current carrier.
    ///   - dmePort: port override of the dme server port
    /// - Returns: Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus>
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
    
    /// Returns the EdgeEventsConnection created after startEdgeEvents
    ///
    /// - Returns: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection?
    public func getEdgeEventsConnection() -> MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConnection? {
        return self.edgeEventsConnection
    }
    
    /// Creates the Default EdgeEventsConfig
    /// This config will determine how the SDK handles events and how often the SDK monitors GPS Location and Latency
    /// A new cloudlet will be returned to newFindCloudletHandler on .eventCloudletState, .eventCloudletMaintenance, .eventAppinstHealth, and .eventLatencyProcessed
    /// Location and Latency will be monitored in the background at an interval. The interval in seconds is up to the application.
    ///
    /// - Parameters:
    ///   - latencyUpdateIntervalSeconds: UInt: The interval in seconds that the SDK will check latency
    ///   - locationUpdateIntervalSeconds: UInt: The interval in seconds that the SDK will check gps location
    ///   - latencyThresholdTriggerMs: Double: The latency threshold at which the application wants to look for a better cloudlet. For example, if latencyThresholdTriggerMs is set to 50 and if the SDK finds that latency is > 50ms, the SDK will check to see if there is a cloudlet with lower latency
    /// - Returns: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig
    public func createDefaultEdgeEventsConfig(latencyUpdateIntervalSeconds: UInt, locationUpdateIntervalSeconds: UInt, latencyThresholdTriggerMs: Double, latencyTestPort: UInt16 = 0) -> MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig {
        let newFindCloudletEvents: Set = [DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventCloudletState, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventCloudletMaintenance, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventAppinstHealth, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventLatencyProcessed, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventLatencyRequest, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventCloudletUpdate, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventError]
        let latencyUpdateConfig = MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig(updatePattern: .onInterval, updateIntervalSeconds: latencyUpdateIntervalSeconds, maxNumberOfUpdates: 0)
        let locationUpdateConfig = MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig(updatePattern: .onInterval, updateIntervalSeconds: locationUpdateIntervalSeconds, maxNumberOfUpdates: 0)
        
        let config = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig(newFindCloudletEvents: newFindCloudletEvents, latencyThresholdTriggerMs: latencyThresholdTriggerMs, latencyTestPort: latencyTestPort, latencyUpdateConfig: latencyUpdateConfig, locationUpdateConfig: locationUpdateConfig)
        return config
    }
    
    /// Creates an EdgeEventsConfig
    /// This config will determine how the SDK handles events and how often the SDK monitors GPS Location and Latency
    ///
    /// - Parameters:
    ///   - newFindCloudletEvents: Set<DistributedMatchEngine_ServerEdgeEvent.ServerEventType>: List of ServerEventTypes that the SDK will look for a new cloudlet on
    ///   - latencyThresholdTriggerMs: Double?: The latency threshold at which the application wants to look for a better cloudlet. For example, if latencyThresholdTriggerMs is set to 50 and if the SDK finds that latency is > 50ms, the
    ///   SDK will check to see if there is a cloudlet with lower latency
    ///   - latencyTestPort: UInt16: Port to do latency test on (must be a TCP port)
    ///   - latencyUpdateConfig: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig: Configures how often and when the SDK will test latency
    ///   - locationUpdateConfig; MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig: Configures how often and when the SDK will check gps location changes
    /// - Returns: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig
    public func createEdgeEventsConfig(newFindCloudletEvents: Set<DistributedMatchEngine_ServerEdgeEvent.ServerEventType>, latencyThresholdTriggerMs: Double?, latencyTestPort: UInt16?, latencyUpdateConfig: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig?, locationUpdateConfig: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig?) -> MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig {
        let config = MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsConfig(newFindCloudletEvents: newFindCloudletEvents, latencyThresholdTriggerMs: latencyThresholdTriggerMs, latencyTestPort: latencyTestPort, latencyUpdateConfig: latencyUpdateConfig, locationUpdateConfig: locationUpdateConfig)
        return config
    }
    
    
    // TODO: ADD createDefaultClientEventsConfig
    
    /// Creates a ClientEventsConfig
    /// This config determines how the SDK handles ClientEdgeEvents (ie. Sending latency updates and gps location updates)
    ///
    /// - Parameters:
    ///   - updatePattern: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig.UpdatePattern: Options are .onStart, .onTrigger, or .onInterval
    ///   - updateIntervalSeconds: UInt?: Interval in seconds between updates
    ///   - maxNumberOfUpdates: Int?: Maximum number of updates SDK can do. Default is 0, which will not limit the number of updates
    /// - Returns: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig
    public func createClientEventsConfig(updatePattern: MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig.UpdatePattern, updateIntervalSeconds: UInt?, maxNumberOfUpdates: Int? = 0) -> MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig {
        let config = MobiledgeXiOSLibraryGrpc.EdgeEvents.ClientEventsConfig(updatePattern: updatePattern, updateIntervalSeconds: updateIntervalSeconds, maxNumberOfUpdates: maxNumberOfUpdates)
        return config
    }
    
    /// Sets the autoMigrationEdgeEventsConnection variable
    /// If autoMigrationEdgeEventsConnection is true, the SDK will automatically start and EdgeEvents connection to a new cloudlet when a better cloudlet is found
    /// If autoMigrationEdgeEventsConnection is fale, it is up to the application to start a new EdgeEvents connection or call switchedToNewCloudlet() to notify the SDK to start a new EdgeEvents connection when/if the application switches
    /// cloudlets.
    /// Default is true.
    ///
    /// - Parameters:
    ///   - autoMigrate: Bool
    public func setAutoMigrationEdgeEventsConnection(autoMigrate: Bool) {
        autoMigrationEdgeEventsConnection = autoMigrate
    }
}

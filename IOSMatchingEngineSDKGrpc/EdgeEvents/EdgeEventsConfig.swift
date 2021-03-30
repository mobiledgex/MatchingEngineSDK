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
//  EdgeEventsConfig.swift
//

import Foundation
import GRPC
import os.log
import Promises

extension MobiledgeXiOSLibraryGrpc.EdgeEvents {
    
    public struct EdgeEventsConfig {
        // Configure how to send events
        var latencyPort: UInt16 // port information for latency testing
        var latencyUpdateConfig: ClientEventsConfig // config for latency updates
        var locationUpdateConfig: ClientEventsConfig // config for gps location updates
          
        // Configure how to respond to events
        var latencyThresholdTrigger: Double // latency threshold in ms when new FindCloudlet is triggered
        var newFindCloudletEvents: Set<DistributedMatchEngine_ServerEdgeEvent.ServerEventType> // events that application wants a new find cloudlet for
    }
    
    public struct ClientEventsConfig {
        var updatePattern: UpdatePattern
        var updateInterval: Int // update interval in seconds
        var numberOfUpdates: Int // number of updates throughout app lifetime
        
        public enum UpdatePattern {
            case onStart // only update on start
            case onTrigger // application will call post[]update functions
            case onInterval // update every updateInterval seconds
        }
    }
    
    public static func getDefaultEdgeEventsConfig() -> EdgeEventsConfig {
        let latencyUpdateConfig = ClientEventsConfig(updatePattern: .onInterval, updateInterval: 60, numberOfUpdates: 5)
        let locationUpdateConfig = ClientEventsConfig(updatePattern: .onInterval, updateInterval: 30, numberOfUpdates: 10)
        let newFindCloudletEvents: Set = [DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventCloudletState, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventCloudletMaintenance, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventAppinstHealth, DistributedMatchEngine_ServerEdgeEvent.ServerEventType.eventLatencyProcessed]
        
        let config = EdgeEventsConfig(latencyPort: 0, latencyUpdateConfig: latencyUpdateConfig, locationUpdateConfig: locationUpdateConfig, latencyThresholdTrigger: 100, newFindCloudletEvents: newFindCloudletEvents)
        return config
    }
    
    public func createEdgeEventsConfig(latencyPort: UInt16, latencyUpdateConfig: ClientEventsConfig, locationUpdateConfig: ClientEventsConfig, latencyThresholdTrigger: Double, newFindCloudletEvents: Set<DistributedMatchEngine_ServerEdgeEvent.ServerEventType>) -> EdgeEventsConfig {
        let config = EdgeEventsConfig(latencyPort: latencyPort, latencyUpdateConfig: latencyUpdateConfig, locationUpdateConfig: locationUpdateConfig, latencyThresholdTrigger: latencyThresholdTrigger, newFindCloudletEvents: newFindCloudletEvents)
        return config
    }
    
    public func createClientEventsConfig(updatePattern: ClientEventsConfig.UpdatePattern, updateInterval: Int, numberOfUpdates: Int) -> ClientEventsConfig {
        let config = ClientEventsConfig(updatePattern: updatePattern, updateInterval: updateInterval, numberOfUpdates: numberOfUpdates)
        return config
    }
}

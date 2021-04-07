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

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.EdgeEvents {
    
    public struct EdgeEventsConfig {
        // Configure how to respond to events
        public var newFindCloudletEvents: Set<DistributedMatchEngine_ServerEdgeEvent.ServerEventType> // events that application wants a new find cloudlet for
        public var latencyThresholdTriggerMs: Double? // latency threshold in ms when new FindCloudlet is triggered if eventLatencyProcessed is in newFindCloudletEvents
        
        // Configure how to send events
        public var latencyTestPort: UInt16 // port information for latency testing, use 0 if you don't care which port is used
        public var latencyUpdateConfig: ClientEventsConfig // config for latency updates
        public var locationUpdateConfig: ClientEventsConfig // config for gps location updates
    }
    
    public struct ClientEventsConfig {
        public var updatePattern: UpdatePattern
        public var updateIntervalSeconds: UInt? // update interval in seconds if updatePattern is .onInterval
        public var maxNumberOfUpdates: Int? // max number of updates throughout app lifetime (values <= 0 will update until EdgeEventsConnection is closed) if updatePattern is .onInterval
        
        public enum UpdatePattern {
            case onStart // only update on start
            case onTrigger // application will call post[]update functions
            case onInterval // update every updateInterval seconds
        }
    }
    
    // TODO: DeviceInfoConfig
}

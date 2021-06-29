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
@_implementationOnly import GRPC
import os.log
import Promises

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.EdgeEvents {
    
    /// Configuration for EdgeEventsConnection
    /// Determines on what events the SDK will search for a new cloudlet
    /// Determines how and when the SDK will send latency and location updates
    public struct EdgeEventsConfig {
        // Configure how to respond to events
        public var newFindCloudletEventTriggers: Set<FindCloudletEventTrigger> // events that application wants a new find cloudlet for
        public var latencyThresholdTriggerMs: Double? // latency threshold in ms when new FindCloudlet is triggered if eventLatencyProcessed is in newFindCloudletEvents
        public var performanceSwitchMargin: Double? // Values range from: 0.0-1.0, latency of a new cloudlet must be better than oldCloudlet.avg - (oldCloudlet.avg * performanceSwitchMargin) before switching to the new cloudlet
        public var latencyTestNetwork: String?
        
        // Configure how to send events
        public var latencyTestPort: UInt16? // port information for latency testing, use 0 if you don't care which port is used
        public var latencyUpdateConfig: UpdateConfig? // config for latency updates
        public var locationUpdateConfig: UpdateConfig? // config for gps location updates
    }
    
    /// Configuration for sending client events
    /// Used for latencyUpdateConfig and locationUpdateConfig in EdgeEventsConfig
    /// Client events can be send .onStart, .onTrigger, or .onInterval
    /// If .onInterval, then an updateIntervalSeconds must be provided
    public struct UpdateConfig {
        public var updatePattern: UpdatePattern
        public var updateIntervalSeconds: UInt? // update interval in seconds if updatePattern is .onInterval
        public var maxNumberOfUpdates: Int? // max number of updates throughout app lifetime (values <= 0 will update until EdgeEventsConnection is closed) if updatePattern is .onInterval
        
        /// UpdatePattern for sending client events
        /// onStart will send one update when startEdgeEvents is called
        /// onInterval will send updates at the specified interval
        /// onTrigger will send no updates unless the application itself calls postLatencyUpdate, postLocationUpdate, etc.
        public enum UpdatePattern {
            case onInterval // update every updateInterval seconds
            case onStart // only update on start
            case onTrigger // application will call post[]update functions
        }
    }
    
    // TODO: DeviceInfoConfig
}

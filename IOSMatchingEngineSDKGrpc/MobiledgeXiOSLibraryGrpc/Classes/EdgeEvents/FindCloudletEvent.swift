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
//  FindCloudletEvent.swift
//

import Foundation

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.EdgeEvents {
    
    /// FindCloudletEvent is sent to newFindCloudletHandler
    /// Contains information about a closer or better cloudlet and the reason why a new cloudlet was found
    public struct FindCloudletEvent {
        public var newCloudlet: DistributedMatchEngine_FindCloudletReply
        public var trigger: FindCloudletEventTrigger
    }
    
    /// The reason why a new cloudlet was found
    /// For example, if on a location update, the DME finds a closer cloudlet, the FindCloudletEventTrigger will be .closerCloudlet
    public enum FindCloudletEventTrigger {
        case closerCloudlet
        case cloudletStateChanged
        case appInstHealthChanged
        case cloudletMaintenanceStateChanged
        case latencyTooHigh
        // TODO: cpuUsageTooHigh, autoprovUpdate, etc.
    }
}

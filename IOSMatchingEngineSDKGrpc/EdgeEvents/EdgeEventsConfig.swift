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
        
    }
    
    public struct ClientEventsConfig {
        var updatePattern: Int
        var updateInterval: Double
        var numberOfUpdates: Int
    }
    
    public static func getDefaultEdgeEventsConfig() -> EdgeEventsConfig {
        return EdgeEventsConfig()
    }
}

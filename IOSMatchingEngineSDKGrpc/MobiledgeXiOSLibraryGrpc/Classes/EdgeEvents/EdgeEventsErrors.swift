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
//  EdgeEventsErrors.swift
//

import Foundation
import GRPC
import os.log
import Promises

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.EdgeEvents {
    
    /// Errors on EdgeEvents
    public enum EdgeEventsError: Error {
        case missingSessionCookie
        case missingEdgeEventsCookie
        case unableToGetLastLocation
        case missingGetLastLocationFunction
        case missingEdgeEventsConfig
        case missingNewFindCloudletHandler
        case missingServerEventsHandler
        case missingLatencyThreshold
        case invalidLatencyThreshold
        case missingUpdateInterval
        case invalidUpdateInterval
        case hasNotDoneFindCloudlet
        case emptyAppPorts
        case portDoesNotExist
        case uninitializedEdgeEventsConnection
        case failedToClose
        case connectionAlreadyClosed
        
        case eventTriggeredButCurrentCloudletIsBest
        case eventError(msg: String)
        
        public static func ==(lhs: EdgeEventsError, rhs: EdgeEventsError) -> Bool {
            switch lhs {
            case .eventError(let msg1):
                switch rhs {
                case .eventError(let msg2):
                    return msg1 == msg2
                default:
                    return false
                }
            default:
                switch rhs {
                case .eventError:
                    return false
                default:
                    return lhs.localizedDescription == rhs.localizedDescription                }
            }
        }
        
        public static func !=(lhs: EdgeEventsError, rhs: EdgeEventsError) -> Bool {
            let equals = lhs == rhs
            return !equals
        }
    }
    
    /// Status of EdgeEvents functions
    public enum EdgeEventsStatus {
        case success
        case fail(error: Error)
        
        public static func ==(lhs: EdgeEventsStatus, rhs: EdgeEventsStatus) -> Bool {
            switch lhs {
            case .success:
                switch rhs {
                case .success:
                    return true
                case .fail:
                    return false
                }
            case .fail(let error1):
                switch rhs {
                case .success:
                    return false
                case .fail(let error2):
                    return error1.localizedDescription == error2.localizedDescription
                }
            }
        }
        
        public static func !=(lhs: EdgeEventsStatus, rhs: EdgeEventsStatus) -> Bool {
            let equals = lhs == rhs
            return !equals
        }
    }
}


// Copyright 2020 MobiledgeX, Inc. All rights and licenses reserved.
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
//  MobiledgeXiOSLibrary.swift
//  MobiledgeXiOSLibrary
//

// Used for "namespacing" purposes to prevent naming conflicts from common names (Util,
// NetworkInterface, etc.)

public enum MobiledgeXiOSLibrary {
    
    public enum DmeDnsError: Error {
        case verifyDmeHostFailure(host: String, systemError: SystemError)
        case missingMCC
        case missingMNC
        case missingCellularProviderInfo
        case outdatedIOS
        
        public var errorDescription: String? {
            switch self {
            case .verifyDmeHostFailure(let host, let systemError): return "Could not verify host: \(host). Error: \(systemError.localizedDescription)"
            case .missingMCC: return "Unable to get Mobile Country Code"
            case .missingMNC: return "Unable to get Mobile Network Code"
            case .missingCellularProviderInfo: return "Unable to find Subscriber Cellular Provider Info"
            case .outdatedIOS: return "iOS is outdated. Requires 12.0+"
            }
        }
    }

    public enum SystemError: Error {
        case getaddrinfo(Int32, Int32?)
        case socket(Int32, Int32?)
        case bind(Int32, Int32?)
        case connect(Int32, Int32?)
    }
}

public extension Dictionary
{
    static func += (lhs: inout [Key: Value], rhs: [Key: Value])
    {
        lhs.merge(rhs) { $1 }
    }
    
    static func + (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value]
    {
        return lhs.merging(rhs) { $1 }
    }
}


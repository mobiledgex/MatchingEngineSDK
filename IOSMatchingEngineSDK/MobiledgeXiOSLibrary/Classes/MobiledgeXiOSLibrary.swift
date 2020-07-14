
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
//  MobiledgeXiOSLibrary.swift
//  MobiledgeXiOSLibrary
//

// Used for "namespacing" purposes to prevent naming conflicts from common names (Util,
// NetworkInterface, etc.)

import Foundation

public enum MobiledgeXiOSLibrary {
    
    public enum DmeDnsError: Error {
        case verifyDmeHostFailure(host: String, systemError: SystemError)
        case invalidMCCMNC(mcc: String, mnc: String)
        case unabledToFindMCCOrMNC(internalErr: Error)
        
        public var errorDescription: String? {
            switch self {
            case .verifyDmeHostFailure(let host, let systemError): return "Could not verify host: \(host). Error: \(systemError.localizedDescription)"
            case .invalidMCCMNC(let mcc, let mnc): return "Mcc \(mcc) and mnc \(mnc) combination are not valid"
            case .unabledToFindMCCOrMNC(let internalErr): return "\(internalErr)"
            }
        }
    }

    public enum SystemError: Error {
        case getaddrinfo(Int32, Int32?)
        case socket(Int32, Int32?)
        case bind(Int32, Int32?)
        case connect(Int32, Int32?)
    }
    
    public enum MobiledgeXError: Error {
        case outdatedIOS(requiredIOS: Int, action: String)
        
        public var errorDescription: String? {
            switch self {
            case .outdatedIOS(let requiredIOS, let action): return "IOS version \(requiredIOS)+ required to perform \(action)"
            }
        }

    }
    
    public struct Socket {
        var addrInfo: UnsafeMutablePointer<addrinfo>
        var sockfd: Int32
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


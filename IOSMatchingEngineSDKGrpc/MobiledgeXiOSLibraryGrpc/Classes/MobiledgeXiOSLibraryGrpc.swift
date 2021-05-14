
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

import Foundation
@_implementationOnly import GRPC
@_implementationOnly import NIO
import os.log
import Promises

/// Swift MobiledgeX SDK namespace
/// Used for "namespacing" purposes to prevent naming conflicts from common names (Util,
/// NetworkInterface, etc.)
public enum MobiledgeXiOSLibraryGrpc {
    
    /// Occurs when MobiledgeX does not have user's MCC and MNC mapped to a DME
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

    /// Occurs when GetConnection function using bsd sockets has an error
    public enum SystemError: Error {
        case getaddrinfo(Int32, Int32?)
        case socket(Int32, Int32?)
        case bind(Int32, Int32?)
        case connect(Int32, Int32?)
    }
    
    /// Generic error from MobiledgeX SDK
    public enum MobiledgeXError: Error {
        case outdatedIOS(requiredIOS: Int, action: String)
        
        public var errorDescription: String? {
            switch self {
            case .outdatedIOS(let requiredIOS, let action): return "IOS version \(requiredIOS)+ required to perform \(action)"
            }
        }

    }
    
    /// Socket struct returned by some GetConnection functions
    public struct Socket {
        var addrInfo: UnsafeMutablePointer<addrinfo>
        var sockfd: Int32
    }
    
    struct GrpcClient {
        var group: EventLoopGroup
        var apiclient: DistributedMatchEngine_MatchEngineApiClient
    }
    
    static func getGrpcClient(host: String, port: UInt16, tlsEnabled: Bool) -> GrpcClient {
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let channel = tlsEnabled ? ClientConnection.secure(group: group).connect(host: host, port: Int(port)) : ClientConnection.insecure(group: group).connect(host: host, port: Int(port))
        let apiclient = DistributedMatchEngine_MatchEngineApiClient.init(channel: channel)
        return GrpcClient(group: group, apiclient: apiclient)
    }
    
    static func closeGrpcClient(client: GrpcClient) -> Promise<Bool> {
        let queue = DispatchQueue(label: "closeGrpc")
        return Promise<Bool>(on: queue) { fulfill, reject in
            do {
                try client.apiclient.channel.close().wait()
                try client.group.syncShutdownGracefully()
                fulfill(true)
            } catch {
                os_log("Unable to close grpc client. Error is %@", log: OSLog.default, type: .debug, error.localizedDescription)
                reject(error)
            }
        }
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


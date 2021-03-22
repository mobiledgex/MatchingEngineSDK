
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
//  MatchingEngineSDK.swift
//  MatchingEngineSDK
//

import os.log
import Promises
import CoreTelephony
import GRPC
import NIO

extension MobiledgeXiOSLibraryGrpc {
    
    /// MatchingEngine class
    /// MobiledgeX MatchingEngine APIs
    public class MatchingEngine {
        
        public enum DMEConstants {
            public static let baseDmeHost: String = "dme.mobiledgex.net"
            public static let dmeGrpcPort: UInt16 = 50051
            public static let fallbackCarrierName: String = ""
            public static let wifiAlias: String = "wifi"
        }
        
        struct GrpcClient {
            var group: EventLoopGroup
            var apiclient: DistributedMatchEngine_MatchEngineApiClient
        }
        
        let headers = [
                    "Accept": "application/json",
                    "Content-Type": "application/json", // This is the default
                    "Charsets": "utf-8",
                ]

        public var state: MatchingEngineState
        var tlsEnabled = true
        var allowSelfSignedCertsGetConnection = false

        /// MatchingEngine constructor
        public init() {
            state = MatchingEngineState()
        }
        
        /// MatchingEngine destructor
        public func close() {
            // code for cleaning up
        }
        
        func getGrpcClient(host: String, port: UInt16) -> GrpcClient {
            let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
            let channel = tlsEnabled ? ClientConnection.secure(group: group).connect(host: host, port: Int(port)) : ClientConnection.insecure(group: group).connect(host: host, port: Int(port))
            let apiclient = DistributedMatchEngine_MatchEngineApiClient.init(channel: channel)
            return GrpcClient(group: group, apiclient: apiclient)
        }
        
        func closeGrpcClient(client: GrpcClient) {
            do {
                try client.apiclient.channel.close().wait()
                try client.group.syncShutdownGracefully()
            } catch {
                os_log("Unable to close grpc client. Error is %@", log: OSLog.default, type: .debug, error.localizedDescription)
            }
        }
    }
}
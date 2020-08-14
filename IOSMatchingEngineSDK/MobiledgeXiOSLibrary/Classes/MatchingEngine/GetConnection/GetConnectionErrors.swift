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
//  GetConnectionErrors.swift
//

import os.log

extension MobiledgeXiOSLibrary.MatchingEngine {

    public enum GetConnectionError: Error {
        case invalidNetworkInterface
        case missingServerFqdn
        case missingServerPort
        case unableToCreateSocket
        case unableToCreateStream
        case variableConversionError(message: String)
        case unableToSetSSLProperty
        case unableToConnectToServer
        case connectionTimeout
        case invalidTimeout
        case unableToCreateSocketSignature
        case outdatedIOS
        case unableToBind
        case incorrectURLSyntax
        case notTLSConfigured
        case isTLSConfigured
        case notValidPort(port: UInt16)
        case portNotInAppPortRange(port: UInt16)
        case unableToValidatePort
        
        public var errorDescription: String? {
            switch self {
            case .variableConversionError(let message): return message
            case .notValidPort(let port): return "\(port) specified is not a valid port number"
            case .portNotInAppPortRange(let port): return "\(port) specified is not in AppPort range"
            default: return self.localizedDescription
            }
        }
    }
    
    public enum EdgeError: Error {
        case wifiOnly(message: String)
        case missingCellularInterface(message: String)
        case defaultWifiInterface(message: String)
        case missingCellularIP(message: String)
    }
}

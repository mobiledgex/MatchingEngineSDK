
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

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    /// MatchingEngine API errors
    public enum MatchingEngineError: Error {
        case networkFailure
        case unknownAppInsts
        
        case missingAppName
        case missingAppVers
        
        case missingCarrierName
        case missingSessionCookie
        case invalidInternalPort
        
        case missingGPSLocation
        case invalidGPSLongitude
        case invalidGPSLatitude
        case missingGPSLocationStatus
        case missingQosPositionList
        
        case missingTokenServerURI
        case missingTokenServerToken
        
        case registerFailed
        case findCloudletFailed
        case verifyLocationFailed
        case getLocationFailed
        case getQosPositionFailed
        case getAppInstListFailed
        case addUserToGroupFailed
        
        case wifiIsNotConnected
        case cellularIsNotConnected
    }
    
    /// Occurs when VerifyLocation API is unable to communicate with token server
    public enum InvalidTokenServerTokenError: Error  {
        case invalidTokenServerUri
        case cannotContactServer
        case invalidToken
        case invalidTokenServerResponse
    }
    
    /// Occurs on bad HTTP requests
    public enum UrlSessionError: Error {
        case transportError(errorMessage: String)
        case invalidHttpUrlResponse
        case badStatusCode(status: Int, errorMessage: String)
        
        public var errorDescription: String? {
            switch self {
            case .transportError(let errorMessage): return "Transport error: \(errorMessage)"
            case .invalidHttpUrlResponse: return "Unable to convert URLResponse to HTTPURLResponse"
            case .badStatusCode(let status, let errorMessage): return "Bad HTTP Status Code: \(status). Error message is: \(errorMessage)"
            }
        }
    }
}

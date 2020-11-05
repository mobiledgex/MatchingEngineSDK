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
//  RegisterClient.swift
//

import os.log
import Promises

// RegisterClient code.
// TODO: GRPC for Swift (none available).

extension MobiledgeXiOSLibrary.MatchingEngine
{
    // RegisterClientRequest struct
    public struct RegisterClientRequest: Encodable {
        // Required fields
        public var ver: uint
        public var org_name: String
        public var app_name: String
        public var app_vers: String
        // Optional fields
        public var auth_token: String?
        public var cell_id: uint?
        public var unique_id_type: String?
        public var unique_id: String?
        public var tags: [String: String]?
    }

    // RegisterClientReply struct
    public struct RegisterClientReply: Decodable {
        // Required fields
        public var ver: uint
        public var status: ReplyStatus
        public var session_cookie: String
        public var token_server_uri: String
        // Optional fields
        public var unique_id_type: String?
        public var unique_id: String?
        public var tags: [String: String]?
    }
    
    func registerClientResult(_ registerClientReply: RegisterClientReply) {
        let line1 = "\nREST RegisterClient Status: \n"
        let line2 = "Version: \(registerClientReply.ver)"
        let line3 = ",\n Client Status: \(registerClientReply.status)"
        let line4 = ",\n SessionCookie: \(registerClientReply.session_cookie)"
        
        Swift.print(line1 + line2 + line3 + line4 + "\n\n")
        Swift.print("Token Server URI: \(registerClientReply.token_server_uri)\n")
    }
    
    /// API createRegisterClientRequest
    ///
    /// - Parameters:
    ///   - orgName: Name of the developer
    ///   - appName: Name of the application
    ///   - appVers: Version of the application.
    ///   - authToken: An optional opaque string to authenticate the client.
    /// - Returns: API Dictionary/json
    public func createRegisterClientRequest(orgName: String, appName: String?, appVers: String?, authToken: String? = nil, cellID: UInt32? = nil, tags: [String: String]? = nil)
        -> RegisterClientRequest { // Dictionary/json
            
            
        return RegisterClientRequest(
            ver: 1,
            org_name: orgName,
            app_name: appName ?? getAppName(),
            app_vers: appVers ?? getAppVersion(),
            auth_token: authToken,
            cell_id: cellID,
            unique_id_type: nil,
            unique_id: nil,
            tags: tags)
    }
    
    /// API registerClient
    ///
    /// Takes a RegisterClient request, and contacts the Distributed MatchingEngine host for the current
    /// carrier, if any.
    /// - Parameters:
    ///   - request: RegisterClient dictionary, from createRegisterClientReqwuest.
    /// - Returns: API Dictionary/json
    public func registerClient(request: RegisterClientRequest) -> Promise<RegisterClientReply> {
        os_log("registerClient", log: OSLog.default, type: .debug)
        
        let promiseInputs: Promise<RegisterClientReply> = Promise<RegisterClientReply>.pending()
        
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeRestPort
        // Return a promise:
        return self.registerClient(host: host, port: port, request: request)
    }
    
    /// API registerClient
    ///
    /// Takes a RegisterClient request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: RegisterClient dictionary, from createRegisterClientReqwuest.
    /// - Returns: API Dictionary/json
    public func registerClient(host: String, port: UInt16, request: RegisterClientRequest) -> Promise<RegisterClientReply> {
        
        let promiseInputs: Promise<RegisterClientReply> = Promise<RegisterClientReply>.pending()
        os_log("registerClient", log: OSLog.default, type: .debug)
        
        // Set UniqueID and UniqueIDType
        var requestWithUniqueID = request
        let uniqueID = getUniqueID()
        var uniqueIDType: String? = nil
        if uniqueID != nil {
            uniqueIDType = getUniqueIDType()
        }
        requestWithUniqueID.unique_id = uniqueID
        requestWithUniqueID.unique_id_type = uniqueIDType
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.registerAPI
        
        // Return a promise chain:
        return self.postRequest(uri: urlStr, request: requestWithUniqueID, type: RegisterClientReply.self).then { reply in
            
            let registerClientReply = reply

            self.state.setSessionCookie(sessionCookie: registerClientReply.session_cookie)
            os_log("saved sessioncookie", log: OSLog.default, type: .debug)
            
            self.state.setTokenServerUri(tokenServerUri: registerClientReply.token_server_uri)
            os_log("saved tokenserveruri\n", log: OSLog.default, type: .debug)
            
            promiseInputs.fulfill(registerClientReply)
            return
        }
    }
} // end RegisterClient

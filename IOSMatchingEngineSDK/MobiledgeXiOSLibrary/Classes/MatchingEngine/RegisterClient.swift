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
//  RegisterClient.swift
//

import os.log
import Promises

// RegisterClient code.
// TODO: GRPC for Swift (none available).

extension MobiledgeXiOSLibrary.MatchingEngine
{
    // RegisterClientRequest fields
    public class RegisterClientRequest {
       public static let ver = "ver"
       public static let dev_name = "dev_name"
       public static let app_name = "app_name"
       public static let app_vers = "app_vers"
       public static let carrier_name = "carrier_name"
       public static let auth_token = "auth_token"
       public static let cell_id = "cell_id"
       public static let unique_id = "unique_id"
       public static let unique_id_type = "unique_id_type"
       public static let tags = "tags"
    }

    // RegisterClientReply fields
    public class RegisterClientReply {
       public static let ver = "ver"
       public static let status = "status"
       public static let session_cookie = "session_cookie"
       public static let token_server_uri = "token_server_uri"
       public static let unique_id_type = "unique_id_type"
       public static let unique_id = "unique_id"
       public static let tags = "tags"
    }
    
    func registerClientResult(_ registerClientReply: [String: Any])
    {
        if registerClientReply.count == 0
        {
            Swift.print("REST RegisterClient Error: NO RESPONSE.")
        }
        else
        {
            let line1 = "\nREST RegisterClient Status: \n"
            let line2 = "Version: " + (registerClientReply[RegisterClientReply.ver] as? String ?? "0")
            let line3 = ",\n Client Status:" + (registerClientReply[RegisterClientReply.status] as? String ?? "")
            let line4 = ",\n SessionCookie:" + (registerClientReply[RegisterClientReply.session_cookie] as? String ?? "")
            
            Swift.print(line1 + line2 + line3 + line4 + "\n\n")
            Swift.print("Token Server URI: " + (registerClientReply[RegisterClientReply.token_server_uri] as? String ?? "") + "\n")
        }
    }
    
    /// API createRegisterClientRequest
    ///
    /// - Parameters:
    ///   - devName: Name of the developer
    ///   - appName: Name of the application
    ///   - appVers: Version of the application.
    ///   - carrierName: Name of the mobile carrier.
    ///   - authToken: An optional opaque string to authenticate the client.
    /// - Returns: API Dictionary/json
    public func createRegisterClientRequest(devName: String, appName: String?, appVers: String?, carrierName: String?, authToken: String?, uniqueIDType: String?, uniqueID: String?, cellID: UInt32?, tags: [[String: String]]?) // need [[String: String]?]?
        -> [String: Any] // Dictionary/json
    {
        var regClientRequest = [String: Any]() // Dictionary/json regClientRequest
        
        regClientRequest[RegisterClientRequest.ver] = 1
        regClientRequest[RegisterClientRequest.dev_name] = devName
        regClientRequest[RegisterClientRequest.app_name] = appName ?? getAppName()
        regClientRequest[RegisterClientRequest.app_vers] = appVers ?? getAppVersion()
        regClientRequest[RegisterClientRequest.carrier_name] = carrierName ?? getCarrierName()
        regClientRequest[RegisterClientRequest.auth_token] = authToken
        regClientRequest[RegisterClientRequest.unique_id_type] = uniqueIDType
        regClientRequest[RegisterClientRequest.unique_id] = uniqueID
        regClientRequest[RegisterClientRequest.cell_id] = cellID
        regClientRequest[RegisterClientRequest.tags] = tags
        
        return regClientRequest
    }
    
    public func validateRegisterClientRequest(request: [String: Any]) throws
    {
        guard let _ = request[RegisterClientRequest.app_name] else {
            throw MatchingEngineError.missingAppName
        }
        guard let _ = request[RegisterClientRequest.app_vers] else {
            throw MatchingEngineError.missingAppVersion
        }
        guard let _ = request[RegisterClientRequest.dev_name] else {
            throw MatchingEngineError.missingDevName
        }
        guard let _ = request[RegisterClientRequest.carrier_name] else {
            throw MatchingEngineError.missingCarrierName
        }
    }
    
    /// API registerClient
    ///
    /// Takes a RegisterClient request, and contacts the Distributed MatchingEngine host for the current
    /// carrier, if any.
    /// - Parameters:
    ///   - request: RegisterClient dictionary, from createRegisterClientReqwuest.
    /// - Returns: API Dictionary/json
    public func registerClient(request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        os_log("registerClient", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        let carrierName = state.carrierName
        var host: String
        do {
            host = try generateDmeHost(carrierName: carrierName)
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
    public func registerClient(host: String, port: UInt, request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        os_log("registerClient", log: OSLog.default, type: .debug)
        
        let baseuri = generateBaseUri(host: host, port: port)
        os_log("BaseURI: %@", log: OSLog.default, type: .debug, baseuri)
        let urlStr = baseuri + APIPaths.registerAPI
        
        do {
            try validateRegisterClientRequest(request: request)
        }
        catch {
            promiseInputs.reject(error) // catch and reject
            return promiseInputs
        }
        
        // Return a promise chain:
        return self.postRequest(uri: urlStr, request: request).then { replyDict in
            guard let sessionCookie = replyDict[RegisterClientReply.session_cookie] as? String else {
                self.state.setSessionCookie(sessionCookie: nil);
                return Promise<[String: AnyObject]>.pending().reject(MatchingEngineError.missingSessionCookie)
            }
            self.state.setSessionCookie(sessionCookie: sessionCookie)
            os_log("saved sessioncookie", log: OSLog.default, type: .debug)
            
            guard let tokenServerUri = replyDict[RegisterClientReply.token_server_uri] as? String else {
                self.state.setTokenServerUri(tokenServerUri: nil);
                return Promise<[String: AnyObject]>.pending().reject(MatchingEngineError.missingTokenServerURI)
            }
            self.state.setTokenServerUri(tokenServerUri: tokenServerUri)
            os_log("saved tokenserveruri\n", log: OSLog.default, type: .debug)
            
            // Implicit return replyDict.
        }
    }
       
} // end RegisterClient
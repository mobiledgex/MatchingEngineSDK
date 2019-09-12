// Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.
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

import Foundation
import NSLogger
import Promises

// MARK: RegisterClient code.
// TODO: GRPC for Swift (none available).

// MARK: RegisterClient Extension

//RegisterClientRequest fields
class RegisterClientRequest {
    public static let ver = "ver"
    public static let dev_name = "dev_name"
    public static let app_name = "app_name"
    public static let app_vers = "app_vers"
    public static let carrier_name = "carrier_name"
    public static let auth_token = "auth_token"
}

//RegisterClientReply fields
class RegisterClientReply {
    public static let ver = "ver"
    public static let status = "status"
    public static let session_cookie = "session_cookie"
    public static let token_server_uri = "token_server_uri"
}

extension MatchingEngine
{
    // MARK:
    
    // Sets: sessioncookie, tokenserveruri
    
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
    public func createRegisterClientRequest(devName: String?, appName: String?, appVers: String?, carrierName: String?, authToken: String?)
        -> [String: Any] // Dictionary/json
    {
        var regClientRequest = [String: Any]() // Dictionary/json regClientRequest
        
        regClientRequest[RegisterClientRequest.ver] = 1
        regClientRequest[RegisterClientRequest.app_name] = appName ?? getAppName()
        regClientRequest[RegisterClientRequest.app_vers] = appVers ?? getAppVersion()
        regClientRequest[RegisterClientRequest.dev_name] = devName
        regClientRequest[RegisterClientRequest.carrier_name] = carrierName ?? getCarrierName()
        regClientRequest[RegisterClientRequest.auth_token] = authToken ?? ""
        
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
        Logger.shared.log(.network, .debug, "registerClient")
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        guard let carrierName = state.carrierName ?? getCarrierName() else {
            Logger.shared.log(.network, .info, "MatchingEngine is unable to retrieve a carrierName to create a network request.")
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        
        let host = MexUtil.shared.generateDmeHost(carrierName: carrierName)
        let port = state.defaultRestDmePort
        
        // Return a promise:
        return registerClient(host: host, port: port, request: request)
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
        Logger.shared.log(.network, .debug, "registerClient")
        
        let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
        Logger.shared.log(.network, .debug, "BaseURI: \(baseuri)")
        let urlStr = baseuri + MexUtil.shared.registerAPI
        
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
            Logger.shared.log(.network, .debug, " saved sessioncookie")
            
            guard let tokenServerUri = replyDict[RegisterClientReply.token_server_uri] as? String else {
                self.state.setTokenServerUri(tokenServerUri: nil);
                return Promise<[String: AnyObject]>.pending().reject(MatchingEngineError.missingTokenServerURI)
            }
            self.state.setTokenServerUri(tokenServerUri: tokenServerUri)
            Logger.shared.log(.network, .debug, " saved tokenserveruri\n")
            
            // Implicit return replyDict.
        }
    }
       
} // end RegisterClient

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

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    func registerClientResult(_ registerClientReply: DistributedMatchEngine_RegisterClientReply) {
        let line1 = "\nGRPC RegisterClient Status: \n"
        let line2 = "Version: \(registerClientReply.ver)"
        let line3 = ",\n Client Status: \(registerClientReply.status)"
        let line4 = ",\n SessionCookie: \(registerClientReply.sessionCookie)"
        
        Swift.print(line1 + line2 + line3 + line4 + "\n\n")
        Swift.print("Token Server URI: \(registerClientReply.tokenServerUri)\n")
    }
    
    /// API createRegisterClientRequest
    /// Creates the RegisterClientRequest object that will be used in the RegisterClient function.The RegisterClientRequest object wraps the parameters that have been provided to this function.
    ///
    /// - Parameters:
    ///   - orgName: Name of the developer
    ///   - appName: Name of the application
    ///   - appVers: Version of the application.
    ///   - authToken: An optional opaque string to authenticate the client.
    /// - Returns: DistributedMatchEngine_RegisterClientRequest
    public func createRegisterClientRequest(orgName: String, appName: String?, appVers: String?, authToken: String? = nil, cellID: UInt32? = nil, tags: [String: String]? = nil)
        -> DistributedMatchEngine_RegisterClientRequest { // Dictionary/json
            
        var req = DistributedMatchEngine_RegisterClientRequest.init()
        req.ver = 1
        req.orgName = orgName
        req.appName = appName ?? getAppName()
        req.appVers = appVers ?? getAppVersion()
        req.authToken = authToken ?? ""
        req.uniqueIDType = ""
        req.uniqueID = ""
        req.tags = tags ?? [String: String]()
        
        return req
    }
    
    /// API registerClient
    /// First DME API called. This will register the client with the MobiledgeX backend and
    /// check to make sure that the app that the user is running exists. (ie. This confirms
    /// that CreateApp in Console/Mcctl has been run successfully). RegisterClientReply
    /// contains a session cookie that will be used (automatically) in later API calls.
    /// It also contains a uri that will be used to get the verifyLocToken used in VerifyLocation.
    ///
    /// Takes a RegisterClient request, and contacts the Distributed MatchingEngine host for the current
    /// carrier, if any.
    /// - Parameters:
    ///   - request: DistributedMatchEngine_RegisterClientRequest struct, from createRegisterClientRequest.
    /// - Returns: Promise<DistributedMatchEngine_RegisterClientReply>
    public func registerClient(request: DistributedMatchEngine_RegisterClientRequest) -> Promise<DistributedMatchEngine_RegisterClientReply> {
        os_log("registerClient", log: OSLog.default, type: .debug)
        
        let promiseInputs: Promise<DistributedMatchEngine_RegisterClientReply> = Promise<DistributedMatchEngine_RegisterClientReply>.pending()
        
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeGrpcPort
        // Return a promise:
        return self.registerClient(host: host, port: port, request: request)
    }
    
    /// API registerClient
    /// RegisterClient overload with hardcoded DME host and port. Only use for testing.
    ///
    /// Takes a RegisterClient request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: DistributedMatchEngine_RegisterClientRequest struct, from createRegisterClientRequest.
    /// - Returns: Promise<DistributedMatchEngine_RegisterClientReply>
    public func registerClient(host: String, port: UInt16, request: DistributedMatchEngine_RegisterClientRequest) -> Promise<DistributedMatchEngine_RegisterClientReply> {
        os_log("registerClient", log: OSLog.default, type: .debug)
        
        // Set UniqueID and UniqueIDType
        var requestWithUniqueID = request
        let uniqueID = getUniqueID()
        var uniqueIDType: String? = nil
        if uniqueID != nil {
            uniqueIDType = getUniqueIDType()
        }
        requestWithUniqueID.uniqueID = uniqueID ?? ""
        requestWithUniqueID.uniqueIDType = uniqueIDType ?? ""
        
        // Return a promise chain:
        return Promise<DistributedMatchEngine_RegisterClientReply>(on: self.state.executionQueue) { fulfill, reject in
            let client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: host, port: port, tlsEnabled: self.tlsEnabled)
            var reply = DistributedMatchEngine_RegisterClientReply.init()
            do {
                reply = try client.apiclient.registerClient(requestWithUniqueID).response.wait()
                os_log("reply: sessionCookie: %@", log: OSLog.default, type: .debug, reply.sessionCookie)
                
                self.state.setSessionCookie(sessionCookie: reply.sessionCookie)
                os_log("saved sessioncookie", log: OSLog.default, type: .debug)
                
                self.state.setTokenServerUri(tokenServerUri: reply.tokenServerUri)
                os_log("saved tokenserveruri\n", log: OSLog.default, type: .debug)
    
                fulfill(reply)
            } catch {
                reject(error)
            }
            MobiledgeXiOSLibraryGrpc.closeGrpcClient(client: client)
        }
    }
}

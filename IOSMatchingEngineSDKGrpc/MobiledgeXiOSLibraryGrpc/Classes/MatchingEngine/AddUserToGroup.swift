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
//  AddUserToGroup.swift
//

import os.log
import Promises

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    /// createDynamicLocGroupRequest
    ///
    /// - Parameters:
    ///   - comm_type
    ///   - user_data
    ///
    /// - Returns: DistributedMatchEngine_DynamicLocGroupRequest
    func createDynamicLocGroupRequest(lg_id: UInt64? = nil, commType: DistributedMatchEngine_DynamicLocGroupRequest.DlgCommType? = nil, userData: String? = nil, cellID: uint? = nil, tags: [String: String]? = nil) throws -> DistributedMatchEngine_DynamicLocGroupRequest {
        
        var req = DistributedMatchEngine_DynamicLocGroupRequest.init()
        req.ver = 1
        req.sessionCookie = state.getSessionCookie() ?? ""
        req.lgID = lg_id ?? 0 // Not implemented (1001)
        req.commType = commType ?? DistributedMatchEngine_DynamicLocGroupRequest.DlgCommType.dlgSecure
        req.userData = userData ?? ""
        req.tags = tags ?? [String: String]()
        
        try validateDynamicLocGroupRequest(request: req)
        return req
    }
    
    func validateDynamicLocGroupRequest(request: DistributedMatchEngine_DynamicLocGroupRequest) throws {
        if request.sessionCookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
    }
    
    /// API addUserToGroup
    ///
    /// Takes a DynamicLocGroup request, and contacts the Distributed MatchingEngine host
    /// - Parameters:
    ///   - request: DistributedMatchEngine_DynamicLocGroupRequest, from createDynamicLocGroupRequest.
    /// - Returns: Promise<DistributedMatchEngine_DynamicLocGroupReply>
    func addUserToGroup (request: DistributedMatchEngine_DynamicLocGroupRequest) -> Promise<DistributedMatchEngine_DynamicLocGroupReply>
    {
        let promiseInputs: Promise<DistributedMatchEngine_DynamicLocGroupReply> = Promise<DistributedMatchEngine_DynamicLocGroupReply>.pending()
                
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeGrpcPort
        return addUserToGroup(host: host, port: port, request: request)
    }
    
    /// API addUserToGroup
    ///
    /// Takes a DynamicLocGroup request, and contacts the Distributed MatchingEngine host
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: DistributedMatchEngine_DynamicLocGroupRequest, from createDynamicLocGroupRequest.
    /// - Returns: Promise<DistributedMatchEngine_DynamicLocGroupReply>
    func addUserToGroup (host: String, port: UInt16, request: DistributedMatchEngine_DynamicLocGroupRequest)
        -> Promise<DistributedMatchEngine_DynamicLocGroupReply>
    {
        os_log("addUserToGroup", log: OSLog.default, type: .debug)
        
        return Promise<DistributedMatchEngine_DynamicLocGroupReply>(on: self.state.executionQueue) { fulfill, reject in
            let client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: host, port: port, tlsEnabled: self.tlsEnabled)
            var reply = DistributedMatchEngine_DynamicLocGroupReply.init()
            do {
                reply = try client.apiclient.addUserToGroup(request).response.wait()
                fulfill(reply)
            } catch {
                reject(error)
            }
            MobiledgeXiOSLibraryGrpc.closeGrpcClient(client: client)
        }
    }
}

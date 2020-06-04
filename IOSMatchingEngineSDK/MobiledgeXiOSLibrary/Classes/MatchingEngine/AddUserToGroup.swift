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

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // DynamicLocGroupRequest struct
    public struct DynamicLocGroupRequest: Encodable {
        public var ver: uint
        public var session_cookie: String
        public var lg_id: UInt64
        public var comm_type: DlgCommType
        public var user_data: String?
        public var cell_id: uint?
        public var tags: [Tag]?
        
        // Values for DynamicLocGroupRequest comm_type field
        public enum DlgCommType: String, Encodable {
            case DLG_UNDEFINED = "DLG_UNDEFINED"
            case DLG_SECURE = "DLG_SECURE"
            case DLG_OPEN = "DLG_OPEN"
        }
    }
    
    // DynamicLocGroupReply struct
    public class DynamicLocGroupReply: Decodable {
        public var ver: uint
        public var status: ReplyStatus
        public var error_code: uint
        public var group_cookie: String
        public var tags: [Tag]?
    }
    
    /// createDynamicLocGroupRequest
    ///
    /// - Parameters:
    ///   - comm_type
    ///   - user_data
    ///
    /// - Returns: API Dictionary/json
    public func createDynamicLocGroupRequest(lg_id: UInt64? = nil, commType: DynamicLocGroupRequest.DlgCommType? = nil, userData: String? = nil, cellID: uint? = nil, tags: [Tag]? = nil) -> DynamicLocGroupRequest {
        
        return DynamicLocGroupRequest(
            ver: 1,
            session_cookie: state.getSessionCookie() ?? "",
            lg_id: lg_id ?? 0, // Not implemented (1001)
            comm_type: commType ?? DynamicLocGroupRequest.DlgCommType.DLG_SECURE,
            user_data: userData,
            cell_id: cellID,
            tags: tags)
    }
    
    func validateDynamicLocGroupRequest(request: DynamicLocGroupRequest) throws {
        if request.session_cookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
    }
    
    /// API addUserToGroup
    ///
    /// Takes a DynamicLocGroup request, and contacts the Distributed MatchingEngine host
    /// - Parameters:
    ///   - request: DynamicLocGroupRequest dictionary, from createDynamicLocGroupRequest.
    /// - Returns: API Dictionary/json
    public func addUserToGroup (request: DynamicLocGroupRequest) -> Promise<DynamicLocGroupReply>
    {
        let promiseInputs: Promise<DynamicLocGroupReply> = Promise<DynamicLocGroupReply>.pending()
                
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeRestPort
        return addUserToGroup(host: host, port: port, request: request)
    }
    
    /// API addUserToGroup
    ///
    /// Takes a DynamicLocGroup request, and contacts the Distributed MatchingEngine host
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: DynamicLocGroupRequest dictionary, from createDynamicLocGroupRequest.
    /// - Returns: API Dictionary/json
    public func addUserToGroup (host: String, port: UInt16, request: DynamicLocGroupRequest)
        -> Promise<DynamicLocGroupReply>
    {
        let promiseInputs: Promise<DynamicLocGroupReply> = Promise<DynamicLocGroupReply>.pending()
        os_log("addUserToGroup", log: OSLog.default, type: .debug)
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.addusertogroupAPI
        
        do {
            try validateDynamicLocGroupRequest(request: request)
        }
        catch {
            promiseInputs.reject(error) // catch and reject
            return promiseInputs
        }
        
        return self.postRequest(uri: urlStr, request: request, type: DynamicLocGroupReply.self)
    }
}

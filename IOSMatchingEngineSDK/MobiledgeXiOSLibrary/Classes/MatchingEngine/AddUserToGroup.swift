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
//  AddUserToGroup.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // DynamicLocGroupRequest fields
    public class DynamicLocGroupRequest {
        public static let ver = "ver"
        public static let session_cookie = "session_cookie"
        public static let lg_id = "lg_id"  //Dynamic Location Group ID
        public static let comm_type = "comm_type"
        public static let user_data = "user_data"
        public static let cell_id = "cell_id"
        public static let tags = "tags"
        
        // Values for DynamicLocGroupRequest comm_type field
        public enum DlgCommType {
            public static let DLG_UNDEFINED = "DLG_UNDEFINED"
            public static let DLG_SECURE = "DLG_UNDEFINED"
            public static let DLG_OPEN = "DLG_UNDEFINED"
        }
    }
    
    // DynamicLocGroupReply fields
    public class DynamicLocGroupReply {
        public static let ver = "ver"
        public static let status = "status"
        public static let error_code = "error_code"
        public static let group_cookie = "group_cookie"
        public static let tags = "tags"
    }
    
    /// createDynamicLocGroupRequest
    ///
    /// - Parameters:
    ///   - comm_type
    ///   - user_data
    ///
    /// - Returns: API Dictionary/json
    public func createDynamicLocGroupRequest(lg_id: UInt64?, commType: String?, userData: String?, cellID: UInt32?, tags: [[String: String]]?) -> [String: Any]
    {
        var dynamicLocGroupRequest = [String: Any]() // Dictionary/json
        
        dynamicLocGroupRequest[DynamicLocGroupRequest.ver] = 1
        dynamicLocGroupRequest[DynamicLocGroupRequest.session_cookie] = state.getSessionCookie()
        dynamicLocGroupRequest[DynamicLocGroupRequest.lg_id] = lg_id ?? 1001 //NOT IMPLEMENTED
        dynamicLocGroupRequest[DynamicLocGroupRequest.user_data] = userData
        dynamicLocGroupRequest[DynamicLocGroupRequest.cell_id] = cellID
        dynamicLocGroupRequest[DynamicLocGroupRequest.tags] = tags
        
        guard let commType = commType, commType != DynamicLocGroupRequest.DlgCommType.DLG_UNDEFINED else {
            dynamicLocGroupRequest[DynamicLocGroupRequest.comm_type] = DynamicLocGroupRequest.DlgCommType.DLG_SECURE
            return dynamicLocGroupRequest
        }
        dynamicLocGroupRequest[DynamicLocGroupRequest.comm_type] = commType
        return dynamicLocGroupRequest
    }
    
    func validateDynamicLocGroupRequest(request: [String: Any]) throws
    {
        guard let _ = request[DynamicLocGroupRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
    }
    
    /// API addUserToGroup
    ///
    /// Takes a DynamicLocGroup request, and contacts the Distributed MatchingEngine host
    /// - Parameters:
    ///   - request: DynamicLocGroupRequest dictionary, from createDynamicLocGroupRequest.
    /// - Returns: API Dictionary/json
    public func addUserToGroup (request: [String: Any]) -> Promise<[String: AnyObject]>
    {
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
    public func addUserToGroup (host: String, port: UInt, request: [String: Any])
        -> Promise<[String: AnyObject]>
    {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        os_log("addUserToGroup", log: OSLog.default, type: .debug)
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.addusertogroupAPI
        
        do {
            try validateQosKPIRequest(request: request)
        }
        catch {
            promiseInputs.reject(error) // catch and reject
            return promiseInputs
        }
        
        return self.postRequest(uri: urlStr, request: request)
    }
}

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
//  AddUserToGroup.swift
//

import Foundation
import os.log
import Promises

class DynamicLocGroupRequest {
    public static let ver = "ver"
    public static let session_cookie = "session_cookie"
    public static let lg_id = "lg_id"  //Dynamic Location Group ID
    public static let comm_type = "comm_type" //DLG_UNDEFINED, DLG_SECURE, DLG_OPEN
    public static let user_data = "user_data"
}

class DynamicLocGroupReply {
    public static let ver = "ver"
    public static let status = "status"
    public static let error_code = "error_code"
    public static let group_cookie = "group_cookie"
}

extension MatchingEngine {
    
    /// createDynamicLocGroupRequest
    ///
    /// - Parameters:
    ///   - comm_type
    ///   - user_data
    ///
    /// - Returns: API Dictionary/json
    public func createDynamicLocGroupRequest(commType: String?, userData: String?) -> [String: Any]
    {
        var dynamicLocGroupRequest = [String: Any]() // Dictionary/json
        
        dynamicLocGroupRequest[DynamicLocGroupRequest.ver] = 1
        dynamicLocGroupRequest[DynamicLocGroupRequest.session_cookie] = state.getSessionCookie()
        dynamicLocGroupRequest[DynamicLocGroupRequest.lg_id] = 1001 //NOT IMPLEMENTED
        dynamicLocGroupRequest[DynamicLocGroupRequest.user_data] = userData
        
        guard let commType = commType, commType != "DLG_UNDEFINED" else {
            dynamicLocGroupRequest[DynamicLocGroupRequest.comm_type] = "DLG_SECURE"
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
        guard let carrierName = state.carrierName ?? getCarrierName() else {
            os_log("MatchingEngine is unable to retrieve a carrierName to create a network request.", log: OSLog.default, type: .debug)
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        var host: String
        do {
            host = try MexUtil.shared.generateDmeHost(carrierName: carrierName)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = self.state.defaultRestDmePort
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
        
        let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
        let urlStr = baseuri + MexUtil.shared.addusertogroupAPI
        
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

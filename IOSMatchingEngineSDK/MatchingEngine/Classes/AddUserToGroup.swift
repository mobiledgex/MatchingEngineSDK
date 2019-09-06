//
//  AddUserToGroup.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
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
    public func addUserToGroup (request: [String: Any])
        -> Promise<[String: AnyObject]>
    {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        guard let carrierName = state.carrierName ?? getCarrierName() else {
            Logger.shared.log(.network, .info, "MatchingEngine is unable to retrieve a carrierName to create a network request.")
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        
        let host = MexUtil.shared.generateDmeHost(carrierName: carrierName)
        let port = state.defaultRestDmePort
        
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
        Logger.shared.log(.network, .debug, "addUserToGroup")
        
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
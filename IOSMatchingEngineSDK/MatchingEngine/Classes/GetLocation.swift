//
//  GetLocation.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

class GetLocationRequest {
    public static let ver = "ver"
    public static let session_cookie = "session_cookie"
    public static let carrier_name = "carrier_name"
}

class GetLocationReply {
    public static let ver = "ver"
    public static let status = "status"    //LOC_UNKNOWN, LOC_FOUND, LOC_DENIED
    public static let carrier_name = "carrier_name"
    public static let tower = "tower"
    public static let network_location = "network_location"
}

extension MatchingEngine {
    
    /// createGetLocationRequest
    ///
    /// - Parameters:
    ///   - carrierName: carrierName description
    /// - Returns: API  Dictionary/json
    public func createGetLocationRequest(carrierName: String) -> [String: Any]
    {
        var getLocationRequest = [String: Any]() // Dictionary/json qosKPIRequest
        
        getLocationRequest[GetLocationRequest.ver] = 1
        getLocationRequest[GetLocationRequest.session_cookie] = self.state.getSessionCookie()
        getLocationRequest[GetLocationRequest.carrier_name] = carrierName
        
        return getLocationRequest
    }
    
    func validateGetLocationRequest(request: [String: Any]) throws
    {
        guard let _ = request[GetLocationRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request[GetLocationRequest.carrier_name] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
    }
    
    /// API getLocation
    ///
    /// Takes a GetLocation request, and contacts the Distributed MatchingEngine host to get the network verified location of the device
    /// - Parameters:
    ///   - request: GetLocationRequest dictionary, from createGetLocationRequest.
    /// - Returns: API Dictionary/json
    public func getLocation(request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        Logger.shared.log(.network, .debug, "getLocation")
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        guard let carrierName = state.carrierName ?? getCarrierName() else {
            Logger.shared.log(.network, .info, "MatchingEngine is unable to retrieve a carrierName to create a network request.")
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        
        let host = MexUtil.shared.generateDmeHost(carrierName: carrierName)
        let port = state.defaultRestDmePort
        
        return getLocation(host: host, port: port, request: request);
    }
    
    /// API getLocation
    ///
    /// Takes a GetLocation request, and contacts the Distributed MatchingEngine host to get the network verified location of the device
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: GetLocationRequest dictionary, from createGetLocationRequest.
    /// - Returns: API Dictionary/json
    public func getLocation(host: String, port: UInt, request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        Logger.shared.log(.network, .debug, "getLocation")
        
        let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
        let urlStr = baseuri + MexUtil.shared.getlocationAPI
        
        do {
            try validateGetLocationRequest(request: request)
        }
        catch {
            promiseInputs.reject(error) // catch and reject
            return promiseInputs
        }
        
        return self.postRequest(uri: urlStr, request: request)
    }
}

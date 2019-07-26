//
//  AppInstList.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

//AppInstListRequest fields
class AppInstListRequest {
    public static let ver = "ver"
    public static let session_cookie = "session_cookie"
    public static let carrier_name = "carrier_name"
    public static let gps_location = "gps_location"
}

//AppInstListReply fields
class AppInstListReply {
    public static let ver = "ver"
    public static let status = "status"
    public static let cloudlets = "cloudlets"
}

extension MatchingEngine {
    /// createGetAppInstListRequest
    ///
    /// - Parameters:
    ///   - carrierName: Carrier name. This value can change depending on cell tower.
    ///   - gpslocation: A dictionary with at least longitude and latitude key values.
    ///
    /// - Returns: API Dictionary/json
    public func createGetAppInstListRequest(carrierName: String?, gpsLocation: [String: Any]) -> [String: Any]
    {
        var appInstListRequest = [String: Any]() // Dictionary/json
        Swift.print("blaaahhh appinst")
        
        appInstListRequest[AppInstListRequest.ver] = 1
        appInstListRequest[AppInstListRequest.session_cookie] = state.getSessionCookie()
        appInstListRequest[AppInstListRequest.carrier_name] = carrierName ?? state.carrierName
        appInstListRequest[AppInstListRequest.gps_location] = gpsLocation
        
        return appInstListRequest
    }
    
    func validateAppInstListRequest(request: [String: Any]) throws
    {
        guard let _ = request[AppInstListRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request[AppInstListRequest.carrier_name] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
        guard let gpsLocation = request[AppInstListRequest.gps_location] as? [String: Any] else {
            throw MatchingEngineError.missingGPSLocation
        }
        let _ = try validateGpsLocation(gpsLocation: gpsLocation)
    }
    
    public func getAppInstList(request: [String: Any])
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
        
        return getAppInstList(host: host, port: port, request: request)
    }
    
    public func getAppInstList(host: String, port: UInt, request: [String: Any])
        -> Promise<[String: AnyObject]>
    {
        Logger.shared.log(.network, .debug, "Finding nearby appInsts matching this MatchingEngine client.")
        Logger.shared.log(.network, .debug, "============================================================")
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
        let urlStr = baseuri + MexUtil.shared.appinstlistAPI
        
        do {
            try validateAppInstListRequest(request: request)
        }
        catch
        {
            promiseInputs.reject(error) // catch and reject
            return promiseInputs
        }
        
        // postRequest is dispatched to background by default:
        return self.postRequest(uri: urlStr, request: request)
    }
}

//
//  AppInstList.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

extension MatchingEngine {
    /// createGetAppInstListRequest
    ///
    /// - Parameters:
    ///   - carrierName: <#carrierName description#>   // Carrier name can change depending on cell tower.
    ///   - gpslocation: <#gpslocation description#>
    ///
    /// - Returns: API Dictionary/json
    
    public func createGetAppInstListRequest(carrierName: String?, gpsLocation: [String: Any]) -> [String: Any]
    {
        //   json findCloudletRequest;
        var appInstListRequest = [String: Any]() // Dictionary/json
        
        appInstListRequest["vers"] = 1
        appInstListRequest["SessionCookie"] = state.getSessionCookie()
        appInstListRequest["CarrierName"] = carrierName ?? state.carrierName
        appInstListRequest["GpsLocation"] = gpsLocation
        
        return appInstListRequest
    }
    
    func validateAppInstListRequest(request: [String: Any]) throws
    {
        guard let _ = request["SessionCookie"] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request["CarrierName"] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
        guard let gpsLocation = request["GpsLocation"] as? [String: Any] else {
            throw MatchingEngineError.missingGPSLocation
        }
        let _ = try validateGpsLocation(gpsLocation: gpsLocation)
    }
    
    // TODO: overload findCloudlet to take more parameters, add platformIntegrtion.swift.
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

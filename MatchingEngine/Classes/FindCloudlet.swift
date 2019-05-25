//
//  FindCloudlet.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

extension MatchingEngine {
    // Carrier name can change depending on cell tower.
    //
    
    /// createFindCloudletRequest
    ///
    /// - Parameters:
    ///   - carrierName: <#carrierName description#>
    ///   - gpslocation: <#gpslocation description#>
    /// - Returns: API  Dictionary/json
    
    // Carrier name can change depending on cell tower.
    public func createFindCloudletRequest(carrierName: String, gpsLocation: [String: Any],
                                          devName: String, appName: String?, appVers: String?)
        -> [String: Any]
    {
        //    findCloudletRequest;
        var findCloudletRequest = [String: Any]() // Dictionary/json
        
        findCloudletRequest["ver"] = 1
        findCloudletRequest["SessionCookie"] = self.state.getSessionCookie()
        findCloudletRequest["CarrierName"] = carrierName
        findCloudletRequest["GpsLocation"] = gpsLocation
        findCloudletRequest["DevName"] = devName
        findCloudletRequest["AppName"] = appName ?? state.appName
        findCloudletRequest["AppVers"] = appVers ?? state.appVersion
        
        return findCloudletRequest
    }
    
    func validateFindCloudletRequest(request: [String: Any]) throws
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

        guard let _ = request["DevName"] as? String else {
            throw MatchingEngineError.missingDevName
        }
        guard let _ = request["AppName"] as? String else {
            throw MatchingEngineError.missingAppName
        }
        guard let _ = request["AppVers"] as? String else {
            throw MatchingEngineError.missingAppVersion
        }
    }
    
    // TODO: overload findCloudlet to take more parameters, add platformIntegrtion.swift.
    public func findCloudlet(request: [String: Any])
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
        
        return try findCloudlet(host: host, port: port, request: request)
    }
    
    
    public func findCloudlet(host: String, port: UInt, request: [String: Any])
        -> Promise<[String: AnyObject]>
    {
        Logger.shared.log(.network, .debug, "Finding nearest Cloudlet appInsts matching this MatchingEngine client.")
        Logger.shared.log(.network, .debug, "======================================================================")
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
        let urlStr = baseuri + MexUtil.shared.findcloudletAPI
        
        do
        {
            try validateFindCloudletRequest(request: request)
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

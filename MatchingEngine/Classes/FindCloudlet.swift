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
    ///   - carrierName: carrierName description
    ///   - gpslocation: gpslocation description
    /// - Returns: API  Dictionary/json
    
    // Carrier name can change depending on cell tower.
    public func createFindCloudletRequest(carrierName: String, gpsLocation: [String: Any],
                                          devName: String, appName: String?, appVers: String?)
        -> [String: Any]
    {
        //    findCloudletRequest;
        var findCloudletRequest = [String: Any]() // Dictionary/json
        
        findCloudletRequest["ver"] = 1
        findCloudletRequest["session_cookie"] = self.state.getSessionCookie()
        findCloudletRequest["carrier_name"] = carrierName
        findCloudletRequest["gps_location"] = gpsLocation
        findCloudletRequest["dev_name"] = devName
        findCloudletRequest["app_name"] = appName ?? state.appName
        findCloudletRequest["app_vers"] = appVers ?? state.appVersion
        
        return findCloudletRequest
    }
    
    func validateFindCloudletRequest(request: [String: Any]) throws
    {
        guard let _ = request["session_cookie"] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request["carrier_name"] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
        guard let gpsLocation = request["gps_location"] as? [String: Any] else {
            throw MatchingEngineError.missingGPSLocation
        }
        let _ = try validateGpsLocation(gpsLocation: gpsLocation)

        guard let _ = request["dev_name"] as? String else {
            throw MatchingEngineError.missingDevName
        }
        guard let _ = request["app_name"] as? String else {
            throw MatchingEngineError.missingAppName
        }
        guard let _ = request["app_vers"] as? String else {
            throw MatchingEngineError.missingAppVersion
        }
    }
    
    /// API findCloudlet
    ///
    /// Takes a FindCloudlet request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - request: FindCloudlet dictionary, from createFindCloudletReqwuest.
    /// - Returns: API Dictionary/json
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
        
        return findCloudlet(host: host, port: port, request: request)
    }
    
    /// API findCloudlet
    ///
    /// Takes a FindCloudlet request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: FindCloudlet dictionary, from createFindCloudletReqwuest.
    /// - Returns: API Dictionary/json
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

//
//  QosPositionKpi.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

extension MatchingEngine {
    
    public func createQosKPIRequest(requests: [String: Any]) -> [String: Any]   //requests are QosPositions (map from id to gps location)
    {
        var qosKPIRequest = [String: Any]() // Dictionary/json qosKPIRequest
        
        qosKPIRequest["session_cookie"] = self.state.getSessionCookie()
        qosKPIRequest["qos_positions"] = requests
        
        return qosKPIRequest
    }
    
    func validateQosKPIRequest(request: [String: Any]) throws
    {
        guard let _ = request["session_cookie"] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
    }
    
    public func getQosKPIPosition(request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        Logger.shared.log(.network, .debug, "getQosKPIPosition")
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        guard let carrierName = state.carrierName ?? getCarrierName() else {
            Logger.shared.log(.network, .info, "MatchingEngine is unable to retrieve a carrierName to create a network request.")
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        
        let host = MexUtil.shared.generateDmeHost(carrierName: carrierName)
        let port = state.defaultRestDmePort
        
        return getQosKPIPosition(host: host, port: port, request: request);
    }
    
    public func getQosKPIPosition(host: String, port: UInt, request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        Logger.shared.log(.network, .debug, "getQosKPIPosition")
        
        do {
            try validateQosKPIRequest(request: request)
        }
        catch {
            promiseInputs.reject(error) // catch and reject
            return promiseInputs
        }
        
        let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
        let urlStr = baseuri + MexUtil.shared.qospositionkpiAPI
        
        return self.postRequest(uri: urlStr, request: request)
    }
}

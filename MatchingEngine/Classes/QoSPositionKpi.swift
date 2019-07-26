//
//  QosPositionKpi.swift
//  Pods
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation
import NSLogger
import Promises

//QosPosition fields (right QosPosition is just Dict: positionid -> gps_location)
class QosPosition {
    public static let positionid = "positionid"
    public static let gps_location = "gps_location"
}

//QosPositionKpiRequest fields
class QosPositionKpiRequest {
    public static let ver = "ver"
    public static let session_cookie = "session_cookie"
    public static let positions = "positions"
}

//QosPositionKpiResult fields
class QosPositionKpiResult {
    public static let positionid = "positionid"
    public static let gps_location = "gps_location"
    public static let dluserthroughput_min = "dluserthroughput_min"
    public static let dluserthroughput_avg = "dluserthroughput_avg"
    public static let dluserthroughput_max = "dluserthroughput_max"
    public static let uluserthroughput_min = "uluserthroughput_min"
    public static let uluserthroughput_avg = "uluserthroughput_avg"
    public static let uluserthroughput_max = "uluserthroughput_max"
    public static let latency_min = "latency_min"
    public static let latency_avg = "latency_avg"
    public static let latency_max = "latency_max"
}

//QosPositionKpiReply fields
class QosPositionKpiReply {
    public static let ver = "ver"
    public static let status = "status"
    public static let position_results = "position_results"
}

extension MatchingEngine {
    
    /// createQosKPIRequest
    ///
    /// - Parameters:
    ///   -requests: QosPositions (Dict: id -> gps location)
    /// - Returns: API  Dictionary/json
    public func createQosKPIRequest(requests: [String: Any]) -> [String: Any]
    {
        Swift.print("blaaaaaa qoskpi")
        var qosKPIRequest = [String: Any]() // Dictionary/json qosKPIRequest
        
        qosKPIRequest[QosPositionKpiRequest.ver] = 1
        qosKPIRequest[QosPositionKpiRequest.session_cookie] = self.state.getSessionCookie()
        qosKPIRequest[QosPositionKpiRequest.positions] = requests
        
        return qosKPIRequest
    }
    
    func validateQosKPIRequest(request: [String: Any]) throws
    {
        guard let _ = request[QosPositionKpiRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
    }
    
    /// API getQosKPIPosition
    ///
    /// Takes a QosKPIRequest request, and contacts the Distributed MatchingEngine host for quality of service at specified locations
    /// - Parameters:
    ///   - request: QosKPIRequest dictionary, from createQosKPIRequest.
    /// - Returns: API Dictionary/json
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
    
    /// API getQosKPIPosition
    ///
    /// Takes a QosKPIRequest request, and contacts the Distributed MatchingEngine host for quality of service at specified locations
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: QosKPIRequest dictionary, from createQosKPIRequest.
    /// - Returns: API Dictionary/json
    public func getQosKPIPosition(host: String, port: UInt, request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        Logger.shared.log(.network, .debug, "getQosKPIPosition")
        
        let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
        let urlStr = baseuri + MexUtil.shared.appinstlistAPI
        
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

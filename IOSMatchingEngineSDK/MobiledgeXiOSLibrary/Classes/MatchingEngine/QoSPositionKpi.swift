// Copyright 2018-2020 MobiledgeX, Inc. All rights and licenses reserved.
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
//  QosPositionKpi.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // QosPositionKpiRequest fields
    public class QosPositionRequest {
        public static let ver = "ver"
        public static let session_cookie = "session_cookie"
        public static let positions = "positions"
        public static let lte_category = "lte_category"
        public static let band_selection = "band_selection"
        public static let cell_id = "cell_id"
        public static let tags = "tags"
        
        // Object in positions field in QosPositionRequest
        public class QosPosition {
            public static let positionid = "positionid"
            public static let gps_location = "gps_location"
        }
        
        // Object in QosPositionRequest band_selection field
        // Each field's value is an array of Strings
        public class BandSelection {
            public static let rat_2g = "rat_2g"
            public static let rat_3g = "rat_3g"
            public static let rat_4g = "rat_4g"
            public static let rat_5g = "rat_5g"
        }
    }

    // QosPositionKpiReply fields
    public class QosPositionKpiReply {
        public static let ver = "ver"
        public static let status = "status"
        public static let position_results = "position_results"
        public static let tags = "tags"
        
        // Object returned in position_results field of QosPositionKpiReply
        public class QosPositionKpiResult {
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
    }
    
    /// createQosKPIRequest
    ///
    /// - Parameters:
    ///   -requests: QosPositions (Dict: id -> gps location)
    /// - Returns: API  Dictionary/json
    public func createQosKPIRequest(requests: [[String: Any]], lte_category: Int32?, band_selection: [String: Any]?, cellID: UInt32?, tags: [[String: String]]?) -> [String: Any]
    {
        var qosKPIRequest = [String: Any]() // Dictionary/json qosKPIRequest
        
        qosKPIRequest[QosPositionRequest.ver] = 1
        qosKPIRequest[QosPositionRequest.session_cookie] = self.state.getSessionCookie()
        qosKPIRequest[QosPositionRequest.positions] = requests
        qosKPIRequest[QosPositionRequest.lte_category] = lte_category
        qosKPIRequest[QosPositionRequest.band_selection] = band_selection
        qosKPIRequest[QosPositionRequest.cell_id] = cellID
        qosKPIRequest[QosPositionRequest.tags] = tags
        
        return qosKPIRequest
    }
    
    func validateQosKPIRequest(request: [String: Any]) throws
    {
        guard let _ = request[QosPositionRequest.session_cookie] as? String else {
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
        os_log("getQosKPIPosition", log: OSLog.default, type: .debug)
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
    public func getQosKPIPosition(host: String, port: UInt16, request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        os_log("getQosKPIPosition", log: OSLog.default, type: .debug)
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.qospositionkpiAPI
        
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

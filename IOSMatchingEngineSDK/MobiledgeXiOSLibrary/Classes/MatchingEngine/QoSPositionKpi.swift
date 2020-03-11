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
    
    // QosPositionKpiRequest struct
    public struct QosPositionRequest: Encodable {
        public var ver: uint
        public var session_cookie: String
        public var positions: [QosPosition]
        public var lte_category: Int32?
        public var band_selection: BandSelection?
        public var cell_id: uint?
        public var tags: [Tag]?
    }
    
    // Object in positions field in QosPositionRequest
    public struct QosPosition: Encodable {
        
        public init(positionId: Int64, gpsLocation: Loc) {
            self.positionid = positionId
            self.gps_location = gpsLocation
        }
        
        public var positionid: Int64
        public var gps_location: Loc
    }
    
    // Object in QosPositionRequest band_selection field
    // Each field's value is an array of Strings
    public struct BandSelection: Encodable {
        public var rat_2g: [String]
        public var rat_3g: [String]
        public var rat_4g: [String]
        public var rat_5g: [String]
    }
    
    // Stream reply struct
    struct QosPositionKpiReplyStream: Decodable {
        public var result: QosPositionKpiReply
    }

    // QosPositionKpiReply struct
    public struct QosPositionKpiReply: Decodable {
        public var ver: uint
        public var status: ReplyStatus
        public var position_results: [QosPositionKpiResult]
        public var tags: [Tag]?
    }
    
    // Object returned in position_results field of QosPositionKpiReply
    public struct QosPositionKpiResult: Decodable {
        //public var positionid: Int64
        public var positionid: String // Can only decode as a String for some reason
        public var gps_location: Loc
        public var dluserthroughput_min: Float
        public var dluserthroughput_avg: Float
        public var dluserthroughput_max: Float
        public var uluserthroughput_min: Float
        public var uluserthroughput_avg: Float
        public var uluserthroughput_max: Float
        public var latency_min: Float
        public var latency_avg: Float
        public var latency_max: Float
    }
    
    /// createQosKPIRequest
    ///
    /// - Parameters:
    ///   -requests: QosPositions (Dict: id -> gps location)
    /// - Returns: API  Dictionary/json
    public func createQosKPIRequest(requests: [QosPosition], lteCategory: Int32?, bandSelection: BandSelection?, cellID: uint?, tags: [Tag]?) -> QosPositionRequest {
        
        return QosPositionRequest(
            ver: 1,
            session_cookie: state.getSessionCookie() ?? "",
            positions: requests,
            lte_category: lteCategory,
            band_selection: bandSelection,
            cell_id: cellID,
            tags: tags)
    }
    
    func validateQosKPIRequest(request: QosPositionRequest) throws {
        if request.session_cookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
        if request.positions.count == 0 {
            throw MatchingEngineError.missingQosPositionList
        }
    }
    
    private class QosPositionDelegate: NSObject, URLSessionTaskDelegate, URLSessionDataDelegate {
        
        var qosPositionReply = Promise<QosPositionKpiReply>.pending()
        var data = Data()
        
        func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
            self.data += data
        }
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError: Error?) {
            
            if (didCompleteWithError != nil) {
                qosPositionReply.reject(didCompleteWithError!)
            } else {
                do {
                    // Decode data into type specified in parameter list
                    let reply = try JSONDecoder().decode(QosPositionKpiReplyStream.self, from: data)
                    os_log("reply json\n %@ \n", log: OSLog.default, type: .debug, String(describing: reply))
                    qosPositionReply.fulfill(reply.result)
                } catch {
                    os_log("json test = %@. Decoding error is %@", log: OSLog.default, type: .debug, String(data: data, encoding: .utf8)!, error.localizedDescription)
                    qosPositionReply.reject(error)
                }
            }
            session.finishTasksAndInvalidate()
        }
    }
    
    
    // Use Delegate instead of completion handler to handle stream
    public func postQosPositionRequest(uri: String, request: QosPositionRequest) -> Promise<QosPositionKpiReply> {
            
        let qosPositionPromise = Promise<QosPositionKpiReply>.pending()
                
        //create URLRequest object
        let url = URL(string: uri)
        var urlRequest = URLRequest(url: url!)
        urlRequest.httpMethod = "POST"
        urlRequest.allHTTPHeaderFields = self.headers
        urlRequest.allowsCellularAccess = true
                
        //fill in body/configure URLRequest
        do {
            let jsonData = try JSONEncoder().encode(request)
            urlRequest.httpBody = jsonData
        } catch {
            os_log("Request JSON encoding error %@", log: OSLog.default, type: .debug, error.localizedDescription)
            qosPositionPromise.reject(error)
            return qosPositionPromise
        }
                
        os_log("URL Request is %@", log: OSLog.default, type: .debug, urlRequest.debugDescription)

        let delegate = QosPositionDelegate()
            
        let session = URLSession(configuration: URLSessionConfiguration.default, delegate: delegate, delegateQueue: OperationQueue.main)
                
        // Send request via URLSession API
        let task = session.dataTask(with: urlRequest as URLRequest)
        task.resume()
        
        return delegate.qosPositionReply
    }
    
    /// API getQosKPIPosition
    ///
    /// Takes a QosKPIRequest request, and contacts the Distributed MatchingEngine host for quality of service at specified locations
    /// - Parameters:
    ///   - request: QosKPIRequest dictionary, from createQosKPIRequest.
    /// - Returns: API Dictionary/json
    public func getQosKPIPosition(request: QosPositionRequest) -> Promise<QosPositionKpiReply>
    {
        os_log("getQosKPIPosition", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<QosPositionKpiReply> = Promise<QosPositionKpiReply>.pending()
        
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
    public func getQosKPIPosition(host: String, port: UInt16, request: QosPositionRequest) -> Promise<QosPositionKpiReply>
    {
        let promiseInputs: Promise<QosPositionKpiReply> = Promise<QosPositionKpiReply>.pending()
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

        return self.postQosPositionRequest(uri: urlStr, request: request)
    }
}

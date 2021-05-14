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
@_implementationOnly import GRPC

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    /// createQosKPIRequest
    /// Creates the QosPositionRequest object that will be used in CreateQosPositionRequest
    ///
    /// - Parameters:
    ///   - requests: DistributedMatchEngine_QosPositions (Dict: id -> gps location)
    ///   - lteCategory: Optional lteCategory
    ///   - bandSelection: Optional BandSelection
    ///   - cellID: Optional cellID
    ///   - tags: Optional dict
    /// - Returns: DistributedMatchEngine_QosPositionRequest
    public func createQosKPIRequest(requests: [DistributedMatchEngine_QosPosition], lteCategory: Int32? = nil, bandSelection: DistributedMatchEngine_BandSelection? = nil, cellID: uint? = nil, tags: [String: String]? = nil) throws -> DistributedMatchEngine_QosPositionRequest {
        
        var req = DistributedMatchEngine_QosPositionRequest.init()
        req.ver = 1
        req.sessionCookie = state.getSessionCookie() ?? ""
        req.positions = requests
        req.lteCategory = lteCategory ?? 0
        req.bandSelection = bandSelection ?? DistributedMatchEngine_BandSelection.init()
        req.cellID = cellID ?? 0
        req.tags = tags ?? [String: String]()
        
        try validateQosKPIRequest(request: req)
        return req
    }
    
    func validateQosKPIRequest(request: DistributedMatchEngine_QosPositionRequest) throws {
        if request.sessionCookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
        if request.positions.count == 0 {
            throw MatchingEngineError.missingQosPositionList
        }
    }
    
    /// API getQosKPIPosition
    /// Returns quality of service metrics for each location provided in qos position request
    ///
    /// Takes a QosKPIRequest request, and contacts the Distributed MatchingEngine host for quality of service at specified locations
    /// - Parameters:
    ///   - request: DistributedMatchEngine_QosKPIRequest struct from createQosKPIRequest.
    /// - Returns: Promise<DistributedMatchEngine_QosPositionKpiReply>
    public func getQosKPIPosition(request: DistributedMatchEngine_QosPositionRequest) -> Promise<DistributedMatchEngine_QosPositionKpiReply>
    {
        os_log("getQosKPIPosition", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<DistributedMatchEngine_QosPositionKpiReply> = Promise<DistributedMatchEngine_QosPositionKpiReply>.pending()
                
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeGrpcPort
        return getQosKPIPosition(host: host, port: port, request: request);
    }
    
    /// API getQosKPIPosition
    /// GetQosPositionKpi overload with hardcoded DME host and port. Only use for testing.
    ///
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: DistributedMatchEngine_QosKPIRequest from createQosKPIRequest.
    /// - Returns: Promise<DistributedMatchEngine_QosPositionKpiReply>
    public func getQosKPIPosition(host: String, port: UInt16, request: DistributedMatchEngine_QosPositionRequest) -> Promise<DistributedMatchEngine_QosPositionKpiReply>
    {
        os_log("getQosKPIPosition", log: OSLog.default, type: .debug)
        print("request is \(request)")
        
        return Promise<DistributedMatchEngine_QosPositionKpiReply>(on: self.state.executionQueue) { fulfill, reject in
            let client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: host, port: port, tlsEnabled: self.tlsEnabled)
            
            let stream = client.apiclient.getQosPositionKpi(request) { response in
                fulfill(response)
            }
            
            do {
                let status = try stream.status.wait()
                if !status.isOk {
                    os_log("qos position stream bad status %@, message %@", log: OSLog.default, type: .debug, status.description, status.message.debugDescription)
                    reject(MatchingEngineError.getQosPositionFailed)
                }
                os_log("qos stream complete", log: OSLog.default, type: .debug)
            } catch {
                reject(error)
            }
                
            MobiledgeXiOSLibraryGrpc.closeGrpcClient(client: client)
        }
    }
}

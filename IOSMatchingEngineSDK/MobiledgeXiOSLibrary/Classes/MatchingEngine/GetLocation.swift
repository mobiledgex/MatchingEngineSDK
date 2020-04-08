
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

//
//  GetLocation.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // GetLocationRequest struct
    public struct GetLocationRequest: Encodable {
        public var ver: uint
        public var session_cookie: String
        public var carrier_name: String
        public var cell_id: uint?
        public var tags: [Tag]?
    }

    // GetLocationReply struct
    public struct GetLocationReply: Decodable {
        public var ver: uint
        public var status: LocStatus
        public var carrier_name: String
        public var tower: String
        public var network_location: Loc
        public var tags: [Tag]?
        
        // Values for GetLocationReply status field
        public enum LocStatus: String, Decodable {
            case LOC_UNKNOWN = "LOC_UNKNOWN"
            case LOC_FOUND = "LOC_FOUND"
            case LOC_DENIED = "LOC_DENIED"
        }
    }
    
    /// createGetLocationRequest
    ///
    /// - Parameters:
    ///   - carrierName: carrierName description
    /// - Returns: API  Dictionary/json
    public func createGetLocationRequest(carrierName: String?, cellID: uint? = nil, tags: [Tag]? = nil) -> GetLocationRequest {
        
        return GetLocationRequest(
            ver: 1,
            session_cookie: state.getSessionCookie() ?? "",
            carrier_name: carrierName ?? state.carrierName ?? getCarrierName(),
            cell_id: cellID,
            tags: tags)
    }
    
    func validateGetLocationRequest(request: GetLocationRequest) throws {
        if request.session_cookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
    }
    
    /// API getLocation
    ///
    /// Takes a GetLocation request, and contacts the Distributed MatchingEngine host to get the network verified location of the device
    /// - Parameters:
    ///   - request: GetLocationRequest dictionary, from createGetLocationRequest.
    /// - Returns: API Dictionary/json
    public func getLocation(request: GetLocationRequest) -> Promise<GetLocationReply> {
        
        os_log("getLocation", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<GetLocationReply> = Promise<GetLocationReply>.pending()
        
        let carrierName = state.carrierName
        var host: String
        do {
            host = try generateDmeHost(carrierName: carrierName)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeRestPort
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
    public func getLocation(host: String, port: UInt16, request: GetLocationRequest) -> Promise<GetLocationReply> {
        
        let promiseInputs: Promise<GetLocationReply> = Promise<GetLocationReply>.pending()
        os_log("getLocation", log: OSLog.default, type: .debug)
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.getlocationAPI
        
        do {
            try validateGetLocationRequest(request: request)
        }
        catch {
            promiseInputs.reject(error) // catch and reject
            return promiseInputs
        }
        
        return self.postRequest(uri: urlStr, request: request, type: GetLocationReply.self)
    }
}

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
//  AppInstList.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // AppInstListRequest struct
    public struct AppInstListRequest: Encodable {
        public var ver: uint
        public var session_cookie: String
        public var carrier_name: String
        public var gps_location: Loc
        public var cell_id: uint?
        public var tags: [Tag]?
    }

    // AppInstListReply struct
    public struct AppInstListReply: Decodable {
        public var ver: uint
        public var status: AIStatus
        public var cloudlets: [CloudletLocation]
        public var tags: [Tag]?
        
        // Values for AppInstList status field
        public enum AIStatus: String, Decodable {
            case AI_UNDEFINED = "AI_UNDEFINED"
            case AI_SUCCESS = "AI_SUCCESS"
            case AI_FAIL = "AI_FAIL"
        }
    }

    // Object returned in AppInstListReply cloudlets field
    public struct CloudletLocation: Decodable {
        public var carrier_name: String
        public var cloudlet_name: String
        public var gps_location: Loc
        public var distance: Double
        public var appinstances: [Appinstance]
    }

    // Object returned in CloudletLocation appinstances field
    public struct Appinstance: Decodable {
        public var app_name: String
        public var app_vers: String
        public var fqdn: String
        public var ports: [AppPort]
        public var org_name: String
    }
    
    /// createGetAppInstListRequest
    ///
    /// - Parameters:
    ///   - carrierName: Carrier name. This value can change depending on cell tower.
    ///   - gpslocation: A dictionary with at least longitude and latitude key values.
    ///
    /// - Returns: API Dictionary/json
    public func createGetAppInstListRequest(gpsLocation: Loc, carrierName: String?,  cellID: uint? = nil, tags: [Tag]? = nil) throws -> AppInstListRequest {
        
        let req = AppInstListRequest(
            ver: 1,
            session_cookie: state.getSessionCookie() ?? "",
            carrier_name: carrierName ?? getCarrierName(),
            gps_location: gpsLocation,
            cell_id: cellID,
            tags: tags)
        
        try validateAppInstListRequest(request: req)
        return req
    }
    
    func validateAppInstListRequest(request: AppInstListRequest) throws {
        if request.session_cookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
        let _ = try validateGpsLocation(gpsLocation: request.gps_location)
    }
    
    public func getAppInstList(request: AppInstListRequest) -> Promise<AppInstListReply> {
        let promiseInputs: Promise<AppInstListReply> = Promise<AppInstListReply>.pending()
                
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeRestPort
        
        return getAppInstList(host: host, port: port, request: request)
    }
    
    public func getAppInstList(host: String, port: UInt16, request: AppInstListRequest)
        -> Promise<AppInstListReply> {
        os_log("Finding nearby appInsts matching this MatchingEngine client.", log: OSLog.default, type: .debug)
        os_log("============================================================", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<AppInstListReply> = Promise<AppInstListReply>.pending()
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.appinstlistAPI
        
        // postRequest is dispatched to background by default:
        return self.postRequest(uri: urlStr, request: request, type: AppInstListReply.self)
    }
}

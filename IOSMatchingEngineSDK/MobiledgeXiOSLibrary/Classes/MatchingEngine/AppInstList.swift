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
    
    // AppInstListRequest fields
    public class AppInstListRequest {
        public static let ver = "ver"
        public static let session_cookie = "session_cookie"
        public static let carrier_name = "carrier_name"
        public static let gps_location = "gps_location"
        public static let cell_id = "cell_id"
        public static let tags = "tags"
    }

    // AppInstListReply fields
    public class AppInstListReply {
        public static let ver = "ver"
        public static let status = "status"
        public static let cloudlets = "cloudlets"
        public static let tags = "tags"
        
        // Values for AppInstList status field
        public enum AIStatus {
            public static let AI_UNDEFINED = "AI_UNDEFINED"
            public static let AI_SUCCESS = "AI_SUCCESS"
            public static let AI_FAIL = "AI_FAIL"
        }
        
        // Object returned in AppInstListReply cloudlets field
        public class CloudletLocation {
            public static let carrier_name = "carrier_name"
            public static let cloudlet_name = "cloudlet_name"
            public static let gps_location = "gps_location"
            public static let distance = "distance"
            public static let appinstances = "appinstances"
            
            // Object returned in CloudletLocation appinstances field
            public class Appinstance {
                public static let app_name = "app_name"
                public static let app_vers = "app_vers"
                public static let fqdn = "fqdn"
                public static let ports = "ports"
            }
        }
    }
    
    /// createGetAppInstListRequest
    ///
    /// - Parameters:
    ///   - carrierName: Carrier name. This value can change depending on cell tower.
    ///   - gpslocation: A dictionary with at least longitude and latitude key values.
    ///
    /// - Returns: API Dictionary/json
    public func createGetAppInstListRequest(carrierName: String?, gpsLocation: [String: Any], cellID: UInt32?, tags: [[String: String]]?) -> [String: Any]
    {
        var appInstListRequest = [String: Any]() // Dictionary/json
        
        appInstListRequest[AppInstListRequest.ver] = 1
        appInstListRequest[AppInstListRequest.session_cookie] = state.getSessionCookie()
        appInstListRequest[AppInstListRequest.carrier_name] = carrierName ?? getCarrierName()
        appInstListRequest[AppInstListRequest.gps_location] = gpsLocation
        appInstListRequest[AppInstListRequest.cell_id] = cellID
        appInstListRequest[AppInstListRequest.tags] = tags
        
        return appInstListRequest
    }
    
    func validateAppInstListRequest(request: [String: Any]) throws
    {
        guard let _ = request[AppInstListRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request[AppInstListRequest.carrier_name] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
        guard let gpsLocation = request[AppInstListRequest.gps_location] as? [String: Any] else {
            throw MatchingEngineError.missingGPSLocation
        }
        let _ = try validateGpsLocation(gpsLocation: gpsLocation)
    }
    
    public func getAppInstList(request: [String: Any]) -> Promise<[String: AnyObject]>
    {
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
        
        return getAppInstList(host: host, port: port, request: request)
    }
    
    public func getAppInstList(host: String, port: UInt, request: [String: Any])
        -> Promise<[String: AnyObject]>
    {
        os_log("Finding nearby appInsts matching this MatchingEngine client.", log: OSLog.default, type: .debug)
        os_log("============================================================", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.appinstlistAPI
        
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

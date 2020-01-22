// Copyright 2020 MobiledgeX, Inc. All rights and licenses reserved.
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
//  FindCloudlet.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // FindCloudletRequest fields
    public class FindCloudletRequest {
        public static let ver = "ver"
        public static let session_cookie = "session_cookie"
        public static let carrier_name = "carrier_name"
        public static let gps_location = "gps_location"
        public static let dev_name = "dev_name"
        public static let app_name = "app_name"
        public static let app_vers = "app_vers"
        public static let cell_id = "cell_id"
        public static let tags = "tags"
    }

    // FindCloudletReply fields
    public class FindCloudletReply {
        public static let ver = "ver"
        public static let status = "status"
        public static let fqdn = "fqdn"
        public static let ports = "ports"
        public static let cloudlet_location = "cloudlet_location"
        public static let tags = "tags"
        
        // Values for FindCloudletReply status field
        public enum FindStatus {
            public static let FIND_UNKNOWN = "FIND_UNKNOWN"
            public static let FIND_FOUND = "FIND_FOUND"
            public static let FIND_NOTFOUND = "FIND_NOTFOUND"
        }
    }
    
    // Carrier name can change depending on cell tower.
    //
    
    /// createFindCloudletRequest
    ///
    /// - Parameters:
    ///   - carrierName: carrierName description
    ///   - gpslocation: gpslocation description
    /// - Returns: API  Dictionary/json
    
    // Carrier name can change depending on cell tower.
    public func createFindCloudletRequest(carrierName: String?, gpsLocation: [String: Any],
                                          devName: String, appName: String?, appVers: String?, cellID: UInt32?, tags: [[String: String]]?)
        -> [String: Any]
    {
        var findCloudletRequest = [String: Any]() // Dictionary/json
        
        findCloudletRequest[FindCloudletRequest.ver] = 1
        findCloudletRequest[FindCloudletRequest.session_cookie] = self.state.getSessionCookie()
        findCloudletRequest[FindCloudletRequest.carrier_name] = carrierName ?? getCarrierName()
        findCloudletRequest[FindCloudletRequest.gps_location] = gpsLocation
        findCloudletRequest[FindCloudletRequest.dev_name] = devName
        findCloudletRequest[FindCloudletRequest.app_name] = appName ?? state.appName
        findCloudletRequest[FindCloudletRequest.app_vers] = appVers ?? state.appVersion
        findCloudletRequest[FindCloudletRequest.cell_id] = cellID
        findCloudletRequest[FindCloudletRequest.tags] = tags
        
        return findCloudletRequest
    }
    
    func validateFindCloudletRequest(request: [String: Any]) throws
    {
        guard let _ = request[FindCloudletRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request[FindCloudletRequest.carrier_name] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
        guard let gpsLocation = request[FindCloudletRequest.gps_location] as? [String: Any] else {
            throw MatchingEngineError.missingGPSLocation
        }
        let _ = try validateGpsLocation(gpsLocation: gpsLocation)

        guard let _ = request[FindCloudletRequest.dev_name] as? String else {
            throw MatchingEngineError.missingDevName
        }
        guard let _ = request[FindCloudletRequest.app_name] as? String else {
            throw MatchingEngineError.missingAppName
        }
        guard let _ = request[FindCloudletRequest.app_vers] as? String else {
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
    public func findCloudlet(request: [String: Any]) -> Promise<[String: AnyObject]>
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
        os_log("Finding nearest Cloudlet appInsts matching this MatchingEngine client.", log: OSLog.default, type: .debug)
        os_log("======================================================================", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.findcloudletAPI
        
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
// Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.
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

import Foundation
import os.log
import Promises

//AppInstListRequest fields
class AppInstListRequest {
    public static let ver = "ver"
    public static let session_cookie = "session_cookie"
    public static let carrier_name = "carrier_name"
    public static let gps_location = "gps_location"
}

//AppInstListReply fields
class AppInstListReply {
    public static let ver = "ver"
    public static let status = "status"
    public static let cloudlets = "cloudlets"
}

extension MatchingEngine {
    /// createGetAppInstListRequest
    ///
    /// - Parameters:
    ///   - carrierName: Carrier name. This value can change depending on cell tower.
    ///   - gpslocation: A dictionary with at least longitude and latitude key values.
    ///
    /// - Returns: API Dictionary/json
    public func createGetAppInstListRequest(carrierName: String?, gpsLocation: [String: Any]) -> [String: Any]
    {
        var appInstListRequest = [String: Any]() // Dictionary/json
        
        appInstListRequest[AppInstListRequest.ver] = 1
        appInstListRequest[AppInstListRequest.session_cookie] = state.getSessionCookie()
        appInstListRequest[AppInstListRequest.carrier_name] = carrierName ?? state.carrierName
        appInstListRequest[AppInstListRequest.gps_location] = gpsLocation
        
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
        guard let carrierName = state.carrierName ?? getCarrierName() else {
            os_log("MatchingEngine is unable to retrieve a carrierName to create a network request.", log: OSLog.default, type: .debug)
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        
        var host: String
        do {
            host = try MexUtil.shared.generateDmeHost(carrierName: carrierName)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = self.state.defaultRestDmePort
        
        return getAppInstList(host: host, port: port, request: request)
    }
    
    public func getAppInstList(host: String, port: UInt, request: [String: Any])
        -> Promise<[String: AnyObject]>
    {
        os_log("Finding nearby appInsts matching this MatchingEngine client.", log: OSLog.default, type: .debug)
        os_log("============================================================", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        let baseuri = MexUtil.shared.generateBaseUri(host: host, port: port)
        let urlStr = baseuri + MexUtil.shared.appinstlistAPI
        
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


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

//
//  GetLocation.swift
//

import os.log
import Promises

class GetLocationRequest {
    public static let ver = "ver"
    public static let session_cookie = "session_cookie"
    public static let carrier_name = "carrier_name"
}

class GetLocationReply {
    public static let ver = "ver"
    public static let status = "status"    //LOC_UNKNOWN, LOC_FOUND, LOC_DENIED
    public static let carrier_name = "carrier_name"
    public static let tower = "tower"
    public static let network_location = "network_location"
}

extension MobiledgeXSDK.MatchingEngine {
    
    /// createGetLocationRequest
    ///
    /// - Parameters:
    ///   - carrierName: carrierName description
    /// - Returns: API  Dictionary/json
    public func createGetLocationRequest(carrierName: String?) -> [String: Any]
    {
        var getLocationRequest = [String: Any]() // Dictionary/json qosKPIRequest
        
        getLocationRequest[GetLocationRequest.ver] = 1
        getLocationRequest[GetLocationRequest.session_cookie] = self.state.getSessionCookie()
        getLocationRequest[GetLocationRequest.carrier_name] = carrierName ?? getCarrierName()
        
        return getLocationRequest
    }
    
    func validateGetLocationRequest(request: [String: Any]) throws
    {
        guard let _ = request[GetLocationRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request[GetLocationRequest.carrier_name] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
    }
    
    /// API getLocation
    ///
    /// Takes a GetLocation request, and contacts the Distributed MatchingEngine host to get the network verified location of the device
    /// - Parameters:
    ///   - request: GetLocationRequest dictionary, from createGetLocationRequest.
    /// - Returns: API Dictionary/json
    public func getLocation(request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        os_log("getLocation", log: OSLog.default, type: .debug)
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
    public func getLocation(host: String, port: UInt, request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
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
        
        return self.postRequest(uri: urlStr, request: request)
    }
}

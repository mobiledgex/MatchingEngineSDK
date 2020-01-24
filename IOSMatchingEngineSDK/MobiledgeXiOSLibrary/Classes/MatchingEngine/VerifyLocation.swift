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
//  FindCloudlet.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // VerifyLocationRequest fields
    public class VerifyLocationRequest {
        public static let ver = "ver"
        public static let session_cookie = "session_cookie"
        public static let carrier_name = "carrier_name"
        public static let gps_location = "gps_location"
        public static let verify_loc_token = "verify_loc_token"
        public static let cell_id = "cell_id"
        public static let tags = "tags"
    }

    // VerifyLocationReply fields
    public class VerifyLocationReply {
        public static let ver = "ver"
        public static let tower_status = "tower_status"
        public static let gps_location_status = "gps_location_status"
        public static let gps_location_accuracy_km = "gps_location_accuracy_km"
        public static let tags = "tags"
        
        // Values for VerifyLocationReply tower_status field
        public enum TowerStatus {
            public static let TOWER_UNKNOWN = "TOWER_UNKNOWN"
            public static let CONNECTED_TO_SPECIFIED_TOWER = "CONNECTED_TO_SPECIFIED_TOWER"
            public static let NOT_CONNECTED_TO_SPECIFIED_TOWER = "NOT_CONNECTED_TO_SPECIFIED_TOWER"
        }
        
        // Values for VerifyLocationReply gps_location_status field
        public enum GPSLocationStatus {
            public static let LOC_UNKNOWN = "LOC_UNKNOWN"
            public static let LOC_VERIFIED = "LOC_VERIFIED"
            public static let LOC_MISMATCH_SAME_COUNTRY = "LOC_MISMATCH_SAME_COUNTRY"
            public static let LOC_MISMATCH_OTHER_COUNTRY = "LOC_MISMATCH_OTHER_COUNTRY"
            public static let LOC_ROAMING_COUNTRY_MATCH = "LOC_ROAMING_COUNTRY_MATCH"
            public static let LOC_ROAMING_COUNTRY_MISMATCH = "LOC_ROAMING_COUNTRY_MISMATCH"
            public static let LOC_ERROR_UNAUTHORIZED = "LOC_ERROR_UNAUTHORIZED"
            public static let LOC_ERROR_OTHER = "LOC_ERROR_OTHER"
        }
    }
    
    public func doVerifyLocation(gpsLocation: [String: AnyObject], cellID: UInt32?, tags: [[String: String]]?)
        throws -> Promise<[String: AnyObject]>?
    {
        Swift.print("Verify Location of this Mex client.")
        Swift.print("===================================\n\n")
        
        guard let tokenServerUri = state.getTokenServerUri() else {
            return nil
        }
        
        let count = tokenServerUri.count
        if count == 0
        {
            os_log("ERROR: TokenURI is empty!", log: OSLog.default, type: .debug)
            return nil
        }

        let verifyLocRequest = createVerifyLocationRequest(carrierName: getCarrierName(), gpsLocation: gpsLocation, cellID: cellID, tags: tags)
        return self.verifyLocation(request: verifyLocRequest)
    }
    
    /// <#Description#>
    ///
    /// - Parameters:
    ///   - carrierName: <#carrierName description#>
    ///   - gpslocation: <#gpslocation description#>
    ///   - verifyloctoken: <#verifyloctoken description#>
    ///
    /// - Returns: API json/Dictionary
    public func createVerifyLocationRequest(carrierName: String?,
                                            gpsLocation: [String: Any], cellID: UInt32?, tags: [[String: String]]?)
        -> [String: Any] // json/Dictionary
    {
        var verifyLocationRequest = [String: Any]() // Dictionary/json
        
        verifyLocationRequest[VerifyLocationRequest.ver] = 1
        verifyLocationRequest[VerifyLocationRequest.session_cookie] = self.state.getSessionCookie()
        verifyLocationRequest[VerifyLocationRequest.carrier_name] = carrierName ?? state.carrierName
        verifyLocationRequest[VerifyLocationRequest.gps_location] = gpsLocation
        verifyLocationRequest[VerifyLocationRequest.cell_id] = cellID
        verifyLocationRequest[VerifyLocationRequest.tags] = tags

        return verifyLocationRequest
    }
    
    func validateVerifyLocationRequest(request: [String: Any]) throws
    {
        guard let _ = request[VerifyLocationRequest.session_cookie] as? String else {
            throw MatchingEngineError.missingSessionCookie
        }
        guard let _ = request[VerifyLocationRequest.carrier_name] as? String else {
            throw MatchingEngineError.missingCarrierName
        }
        guard let gpsLocation = request[VerifyLocationRequest.gps_location] as? [String: Any] else {
            throw MatchingEngineError.missingGPSLocation
        }
        let _ = try validateGpsLocation(gpsLocation: gpsLocation)
        
        guard let _ = request[VerifyLocationRequest.verify_loc_token] as? String else {
            throw MatchingEngineError.missingTokenServerToken
        }
    }
    
    private func getTokenPost(uri: String) // Dictionary/json
        -> Promise<[String: AnyObject]>
    {
        os_log("uri: %@ request\n", log: OSLog.default, type: .debug, uri)
        
        return Promise<[String: AnyObject]>(on: self.state.executionQueue) { fulfill, reject in
            //Create URLRequest object
            let url = URL(string: uri)
            var urlRequest = URLRequest(url: url!)
            
            //Configure URLRequest
            urlRequest.httpMethod = "POST"
            urlRequest.allHTTPHeaderFields = self.headers
            urlRequest.allowsCellularAccess = true
            
            os_log("URL Request is %@", log: OSLog.default, type: .debug, urlRequest.debugDescription)
            
            //Create new URLSession in order to use delegates
            let session = URLSession.init(configuration: URLSessionConfiguration.default, delegate: SessionDelegate(), delegateQueue: OperationQueue.main)
            
            //Send request via URLSession API
            let dataTask = session.dataTask(with: urlRequest as URLRequest) { (data, response, error) in
                if (error != nil) {
                    reject(InvalidTokenServerTokenError.invalidTokenServerResponse)
                } else {
                    guard let httpResponse = response as? HTTPURLResponse else {
                        os_log("Cant cast response at HTTPURLResponse", log: OSLog.default, type: .debug)
                        return
                    }
                    if let location = httpResponse.allHeaderFields["Location"] as? String {
                        if location.contains("dt-id=") {
                            //Parse to get token
                            let dtId = location.components(separatedBy: "dt-id=")
                            let s1 = dtId[1].components(separatedBy: ",")
                            let token = s1[0]
                            os_log("token is %@", log: OSLog.default, type: .debug, token)
                            fulfill(["token": token as AnyObject])
                        } else {
                            //Missing Token
                            os_log("Missing token response %@", log: OSLog.default, type: .debug, location)
                            reject(InvalidTokenServerTokenError.invalidTokenServerResponse)
                        }
                    }
                }
            }
            dataTask.resume()
        }
    }

    private class SessionDelegate: NSObject, URLSessionDelegate, URLSessionTaskDelegate, URLSessionDataDelegate {
        
        //Prevents redirects for getToken
        public func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void)
        {
            completionHandler(nil)
        }
    }
    
    private func getToken(uri: String) -> Promise<String> // async
    {
        os_log("In Get Token, with uri: %@", log: OSLog.default, type: .debug, uri)
        
        return Promise<String>() { fulfill, reject in
            if uri.count == 0 {
                reject(InvalidTokenServerTokenError.invalidTokenServerUri)
                return
            }
            fulfill(uri)
        }.then { tokenUri in
                self.getTokenPost(uri: tokenUri)
        }.then { reply in
            guard let token = reply["token"] as? String else {
                return Promise{""}
            }
            return Promise{token}
        }
    }
    
    private func tokenizeRequest(carrierName: String, verifyLocationToken: String, gpsLocation: [String: AnyObject], cellID: UInt32?, tags: [[String: String]]?)
        throws -> [String: Any]
    {
            
        if (verifyLocationToken.count == 0) {
            throw InvalidTokenServerTokenError.invalidToken
        }
        
        let verifyLocationRequest = self.createVerifyLocationRequest(carrierName: carrierName, gpsLocation: gpsLocation, cellID: cellID, tags: tags)
        var tokenizedRequest = [String: Any]() // Dictionary/json
        tokenizedRequest += verifyLocationRequest
        tokenizedRequest[VerifyLocationRequest.verify_loc_token] = verifyLocationToken
            
        return tokenizedRequest
    }
    
    public func verifyLocation(request: [String: Any]) -> Promise<[String: AnyObject]> {
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
        
        guard let carrierName = state.carrierName else {
            os_log("MatchingEngine is unable to retrieve a carrierName to create a network request.", log: OSLog.default, type: .debug)
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        
        var host: String
        do {
            host = try generateDmeHost(carrierName: carrierName)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeRestPort
        return verifyLocation(host: host, port: port, request: request)
    }
    
    // TODO: This should be paramaterized:
    public func verifyLocation(host: String, port: UInt16, request: [String: Any]) -> Promise<[String: AnyObject]>
    {
        
        // Dummy promise to check inputs:
        let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()

        guard let _ = request[VerifyLocationRequest.carrier_name] ?? self.state.carrierName else {
            promiseInputs.reject(MatchingEngineError.missingCarrierName)
            return promiseInputs
        }
        guard let _ = request[VerifyLocationRequest.gps_location] ?? self.state.deviceGpsLocation else {
            promiseInputs.reject(MatchingEngineError.missingGPSLocation)
            return promiseInputs
        }
        
        // mini-check server uri to get token:
        guard let tokenServerUri = self.state.getTokenServerUri() else {
            promiseInputs.reject(InvalidTokenServerTokenError.invalidTokenServerUri)
            return promiseInputs
        }
        
         // This doesn't catch anything. It does throw errors to the caller.
        return self.getToken(uri: tokenServerUri).then(on: self.state.executionQueue) { verifyLocationToken in
            
            let baseuri = self.generateBaseUri(host: host, port: port)
            let verifylocationAPI: String = APIPaths.verifylocationAPI
            let uri = baseuri + verifylocationAPI
            
            if (verifyLocationToken.count == 0) {
                throw InvalidTokenServerTokenError.invalidToken
            }
            
            // Append Token
            var tokenizedRequest = request // Dictionary/json
            tokenizedRequest[VerifyLocationRequest.verify_loc_token] = verifyLocationToken
            try self.validateVerifyLocationRequest(request: tokenizedRequest)
            
            return self.postRequest(uri: uri,
                                    request: tokenizedRequest)
        } // End return.
    }
}

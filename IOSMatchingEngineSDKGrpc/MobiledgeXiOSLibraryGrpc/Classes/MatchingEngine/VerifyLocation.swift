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

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    /// createVerifyLocationRequest
    /// Creates the VerifyLocationRequest object that will be used in VerifyLocation
    ///
    /// - Parameters:
    ///   - gpsLocation: DistributedMatchEngine_Loc
    ///   - carrierName: carrierName
    ///   - cellID: Optional cellID
    ///   - tags: Optional dict
    /// - Returns: DistributedMatchEngine_VerifyLocationRequest
    public func createVerifyLocationRequest(gpsLocation: DistributedMatchEngine_Loc, carrierName: String? = nil,
                                            cellID: uint? = nil, tags: [String: String]? = nil) throws -> DistributedMatchEngine_VerifyLocationRequest {
            
        var req = DistributedMatchEngine_VerifyLocationRequest.init()
        req.ver = 1
        req.sessionCookie = self.state.getSessionCookie() ?? ""
        req.carrierName = carrierName ?? getCarrierName()
        req.gpsLocation = gpsLocation
        req.verifyLocToken = ""
        req.tags = tags ?? [String: String]()
        
        try validateVerifyLocationRequest(request: req)
        return req
    }
    
    func validateVerifyLocationRequest(request: DistributedMatchEngine_VerifyLocationRequest) throws {
        if request.sessionCookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
        let _ = try validateGpsLocation(gpsLocation: request.gpsLocation)
    }
    
    private func getTokenPost(uri: String) // Dictionary/json
        -> Promise<[String: AnyObject]> {
            
        os_log("getToken Post request. uri: %@ request\n", log: OSLog.default, type: .debug, uri)
        
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
    
    private func getToken(uri: String) -> Promise<String> { // async
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
    
    /// API: VerifyLocation
    /// Makes sure that the user's location is not spoofed based on cellID and gps location.
    /// Returns the Cell Tower status (CONNECTED_TO_SPECIFIED_TOWER if successful) and Gps Location status (LOC_VERIFIED if successful).
    /// Also provides the distance between where the user claims to be and where carrier believes user to be (via gps and cell id) in km.
    ///
    /// - Parameters:
    ///   - request: DistributedMatchEngine_VerifyLocationRequest from createVerifyLocation
    /// - Returns: Promise<DistributedMatchEngine_VerifyLocationReply>
    public func verifyLocation(request: DistributedMatchEngine_VerifyLocationRequest) -> Promise<DistributedMatchEngine_VerifyLocationReply> {
        let promiseInputs: Promise<DistributedMatchEngine_VerifyLocationReply> = Promise<DistributedMatchEngine_VerifyLocationReply>.pending()
        
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeGrpcPort
        return verifyLocation(host: host, port: port, request: request)
    }
    
    /// VerifyLocation overload with hardcoded DME host and port. Only use for testing.
    public func verifyLocation(host: String, port: UInt16, request: DistributedMatchEngine_VerifyLocationRequest) -> Promise<DistributedMatchEngine_VerifyLocationReply> {
        
        let promiseInputs: Promise<DistributedMatchEngine_VerifyLocationReply> = Promise<DistributedMatchEngine_VerifyLocationReply>.pending()
        
        // mini-check server uri to get token:
        guard let tokenServerUri = self.state.getTokenServerUri() else {
            promiseInputs.reject(InvalidTokenServerTokenError.invalidTokenServerUri)
            return promiseInputs
        }
        
         // This doesn't catch anything. It does throw errors to the caller.
        return self.getToken(uri: tokenServerUri).then(on: self.state.executionQueue) { verifyLocationToken in
            
            if (verifyLocationToken.count == 0) {
                throw InvalidTokenServerTokenError.invalidToken
            }
            
            // Append Token
            var tokenizedRequest = request
            tokenizedRequest.verifyLocToken = verifyLocationToken
            print("verifylocation token is \(verifyLocationToken)")
            
            return Promise<DistributedMatchEngine_VerifyLocationReply>(on: self.state.executionQueue) { fulfill, reject in
                let client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: host, port: port, tlsEnabled: self.tlsEnabled)
                var reply = DistributedMatchEngine_VerifyLocationReply.init()
                do {
                    reply = try client.apiclient.verifyLocation(tokenizedRequest).response.wait()
                    fulfill(reply)
                } catch {
                    reject(error)
                }
                MobiledgeXiOSLibraryGrpc.closeGrpcClient(client: client)
            }
        }
    }
}

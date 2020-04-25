
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
//  MatchingEngineSDK.swift
//  MatchingEngineSDK
//

import os.log
import Promises
import CoreTelephony

extension MobiledgeXiOSLibrary {
    
    /// MobiledgeX MatchingEngine APIs
    public class MatchingEngine {
        
        // API Paths:   See Readme.txt for curl usage examples
        public enum APIPaths {
            public static let registerAPI: String = "/v1/registerclient"
            public static let appinstlistAPI: String = "/v1/getappinstlist"
            public static let verifylocationAPI: String = "/v1/verifylocation"
            public static let findcloudletAPI: String = "/v1/findcloudlet"
            public static let qospositionkpiAPI: String = "/v1/getqospositionkpi"
            public static let getlocationAPI: String = "/v1/getlocation"
            public static let addusertogroupAPI: String = "/v1/addusertogroup"
        }
        
        public enum DMEConstants {
            public static let baseDmeHost: String = "dme.mobiledgex.net"
            public static let dmeRestPort: UInt16 = 38001
            public static let fallbackCarrierName: String = "wifi"
            public static let wifiAlias: String = "wifi"
        }
        
        let headers = [
            "Accept": "application/json",
            "Content-Type": "application/json", // This is the default
            "Charsets": "utf-8",
        ]
        
        var state: MatchingEngineState
        var urlConfiguration: URLSessionConfiguration?
        var urlSession: URLSession?

        public init() {
            state = MatchingEngineState()
            
            urlConfiguration = URLSessionConfiguration.default
            urlConfiguration?.allowsCellularAccess = true
            urlSession = URLSession(configuration: urlConfiguration!, delegate: URLSessionDelegate(), delegateQueue: OperationQueue.main)
        }
        
        // API Rest calls use this function to post "requests" (ie. RegisterClient() posts RegisterClientRequest)
        public func postRequest<Request: Encodable, Reply: Decodable>(uri: String, request: Request, type: Reply.Type) -> Promise<Reply> {
            
            return Promise<Reply>(on: self.state.executionQueue) {
                fulfill, reject in
                                
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
                    reject(error)
                }
                
                os_log("URL Request is %@", log: OSLog.default, type: .debug, urlRequest.debugDescription)
                let task = self.urlSession!.dataTask(with: urlRequest as URLRequest, completionHandler: { data, response, error in
                    
                    var responseBody: String? = nil
                    if let data = data {
                        responseBody = String(bytes: data, encoding: .utf8)
                    }
                    
                    if let error = error {
                        // Error is not nil
                        os_log("Error is: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        reject(UrlSessionError.transportError(errorMessage: "\(error.localizedDescription). Data returned is: \(responseBody ?? "no response body")"))
                        return
                    }
                    
                    guard let httpResponse = response as? HTTPURLResponse else
                    {
                        os_log("Response not HTTPURLResponse", log: OSLog.default, type: .debug)
                        reject(UrlSessionError.invalidHttpUrlResponse)
                        return
                    }
                    
                    // Checks if http request succeeded (200 == success)
                    let statusCode = httpResponse.statusCode
                    if (statusCode != 200) {
                        os_log("HTTP Status Code: %@", log: OSLog.default, type: .debug, String(describing: statusCode))
                        reject(UrlSessionError.badStatusCode(status: statusCode, errorMessage: (responseBody ?? "no response body")))
                        return
                    }

                    if let data = data {
                        do {
                            // Decode data into type specified in parameter list
                            let reply = try JSONDecoder().decode(type, from: data)
                            os_log("uri: %@ reply json\n %@ \n", log: OSLog.default, type: .debug, uri, String(describing: reply))
                            fulfill(reply)
                        } catch {
                            os_log("json = %@. Decoding error is %@", log: OSLog.default, type: .debug, String(data: data, encoding: .utf8)!, error.localizedDescription)
                                reject(error)
                        }
                    }
                    return
                })
                task.resume()
            }
        }
    }
    
    private class URLSessionDelegate : NSObject, URLSessionDataDelegate {
        
        func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            for metric in metrics.transactionMetrics {
                print("urlsession metrics: \(metric)")
            }
        }
    }
}

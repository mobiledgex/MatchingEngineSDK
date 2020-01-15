
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
//  MatchingEngineSDK.swift
//  MatchingEngineSDK
//

import os.log
import Promises
import CoreTelephony

extension MobiledgeXSDK {
    
    /// MobiledgeX MatchingEngine APIs
    public class MatchingEngine
    {
        
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
        
        var state: MatchingEngineState
        
        public let networkInfo = CTTelephonyNetworkInfo() // Used to look at subscriber and cellular data info (Developer should implement callbacks in case SIM card changes)
        
        // Used to correlate port to Path Prefix from findCloudletReply
        var portToPathPrefixDict = [String: String]()
            
        // Just standard GCD Queues to dispatch promises into, user initiated priority.
        var executionQueue = DispatchQueue.global(qos: .default)
        
        let headers = [
            "Accept": "application/json",
            "Content-Type": "application/json", // This is the default
            "Charsets": "utf-8",
        ]
        
        public let baseDmeHost: String = "dme.mobiledgex.net"
        public let dmePort: UInt = 38001
        public let carrierNameDefault_TDG: String = "TDG"
        public var baseDmeHostInUse: String = "TDG" // baseDmeHost
        public var carrierNameInUse: String = "sdkdemo" // carrierNameDefault_mexdemo
        public var ctCarriers: [String: CTCarrier]?
        public var lastCarrier: CTCarrier?
        public var closestCloudlet = ""
        public let wifiAlias = "wifi"
        
        public init()
        {
            executionQueue = DispatchQueue.global(qos: .default)
            state = MatchingEngineState()
        }
        
        // API Rest calls use this function to post "requests" (ie. RegisterClient() posts RegisterClientRequest)
        public func postRequest(uri: String,
                                request: [String: Any])
            -> Promise<[String: AnyObject]>
        {
            return Promise<[String: AnyObject]>(on: self.executionQueue) { fulfill, reject in
                
                do {
                    //create URLRequest object
                    let url = URL(string: uri)
                    var urlRequest = URLRequest(url: url!)
                    //fill in body/configure URLRequest
                    let jsonRequest = try JSONSerialization.data(withJSONObject: request)
                    urlRequest.httpBody = jsonRequest
                    urlRequest.httpMethod = "POST"
                    urlRequest.allHTTPHeaderFields = self.headers
                    urlRequest.allowsCellularAccess = true
                    
                    os_log("URL Request is %@", log: OSLog.default, type: .debug, urlRequest.debugDescription)
                    
                    //send request via URLSession API
                    let task = URLSession.shared.dataTask(with: urlRequest as URLRequest, completionHandler: { data, response, error in
                        guard let httpResponse = response as? HTTPURLResponse else
                        {
                            os_log("Response not HTTPURLResponse", log: OSLog.default, type: .debug)
                            return
                        }
                        
                        //checks if http request succeeded (200 == success)
                        let statusCode = httpResponse.statusCode
                        if (statusCode != 200) {
                            os_log("HTTP Status Code: %@", log: OSLog.default, type: .debug, String(describing: statusCode))
                            return
                        }
                        
                        guard let error = error as NSError? else
                        {
                            //No errors
                            if let data = data {
                                do {
                                    //let string1 = String(data: data, encoding: String.Encoding.utf8) ?? "Data could not be printed"
                                    // Convert the data to JSON
                                    let jsonSerialized = try JSONSerialization.jsonObject(with: data, options: []) as? [String : AnyObject]
                                    os_log("uri: %@ reply json\n %@ \n", log: OSLog.default, type: .debug, uri, String(describing: jsonSerialized))
                                    fulfill(jsonSerialized!)
                                } catch {
                                    os_log("json = %@ error", log: OSLog.default, type: .debug, String(data: data, encoding: .utf8)!)
                                    return
                                }
                            }
                            return
                        }
                        
                        //Error is not nil
                        os_log("Error is: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        reject(error)
                        
                    })
                    task.resume()
                } catch {
                    os_log("Request JSON serialization error", log: OSLog.default, type: .debug)
                    return
                }
            }
        }
    }
}


// Move to MobiledgeXSDK.swift??
public extension Dictionary
{
    static func += (lhs: inout [Key: Value], rhs: [Key: Value])
    {
        lhs.merge(rhs) { $1 }
    }
    
    static func + (lhs: [Key: Value], rhs: [Key: Value]) -> [Key: Value]
    {
        return lhs.merging(rhs) { $1 }
    }
}

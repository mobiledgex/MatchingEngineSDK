
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

import Foundation

import os.log
import Promises

import CoreTelephony
import CoreLocation

enum InvalidTokenServerTokenError: Error  {
    case invalidTokenServerUri
    case cannotContactServer
    case invalidToken
    case invalidTokenServerResponse
}

enum MatchingEngineError: Error {
    case networkFailure
    case missingAppName
    case missingAppVersion
    case missingDevName
    case missingCarrierName
    case missingSessionCookie
    
    case missingGPSLocation
    case invalidGPSLongitude
    case invalidGPSLatitude
    
    case missingTokenServerURI
    case missingTokenServerToken
    case missingGPSLocationStatus
    case registerFailed
    case findCloudletFailed
    case verifyLocationFailed
}

enum DmeDnsError: Error {
    case verifyDmeHostFailure(host: String, systemError: SystemError)
    case missingMCC
    case missingMNC
    case missingCellularProviderInfo
    case outdatedIOS
    
    public var errorDescription: String? {
        switch self {
        case .verifyDmeHostFailure(let host, let systemError): return "Could not verify host: \(host). Error: \(systemError.localizedDescription)"
        case .missingMCC: return "Unable to get Mobile Country Code"
        case .missingMNC: return "Unable to get Mobile Network Code"
        case .missingCellularProviderInfo: return "Unable to find Subscriber Cellular Provider Info"
        case .outdatedIOS: return "iOS is outdated. Requires 12.0+"
        }
    }
}

enum SystemError: Error {
    case getaddrinfo(Int32, Int32?)
    case socket(Int32, Int32?)
    case bind(Int32, Int32?)
    case connect(Int32, Int32?)
}

enum GetConnectionError: Error {
    case invalidNetworkInterface
    case missingServerFqdn
    case missingServerPort
    case unableToCreateSocket
    case unableToCreateStream
    case variableConversionError(message: String)
    case unableToSetSSLProperty
    case unableToConnectToServer
    case connectionTimeout
    case invalidTimeout
    case unableToCreateSocketSignature
    case outdatedIOS
    case unableToBind
    case incorrectURLSyntax
}

class MatchingEngineState {
    var DEBUG: Bool = true
    
    init()
    {
        print(Bundle.main.object)
    }
    
    let defaultCarrierName = "tdg"
    public let defaultRestDmePort: UInt = 38001
    var carrierName: String?
    var previousCarrierName: String?
    
    public var appName: String
    {
        get
        {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
        }
    }
    
    public var appVersion: String
    {
        get
        {
            return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        }
    }
    
    private var sessionCookie: String?
    private var tokenServerUri: String?
    private var tokenServerToken: String?
    
    var deviceGpsLocation: [String: AnyObject]?
    
    // Various known states (should create non-dictionary classes)
    var verifyLocationResult: [String: AnyObject]?
    var location = [String: Any]()
    
    func setSessionCookie(sessionCookie: String?)
    {
        self.sessionCookie = sessionCookie
    }
    
    func getSessionCookie() -> String?
    {
        return self.sessionCookie
    }
    
    func setTokenServerUri(tokenServerUri: String?)
    {
        self.tokenServerUri = tokenServerUri
    }
    
    func getTokenServerUri() -> String?
    {
        return self.tokenServerUri
    }
    
    func setTokenServerToken(tokenServerToken: String?)
    {
        self.tokenServerToken = tokenServerToken
    }
    
    func getTokenServerToken() -> String?
    {
        return self.tokenServerToken
    }
}

/// MobiledgeX MatchingEngine SDK APIs
public class MatchingEngine
{
    var state: MatchingEngineState = MatchingEngineState()
    
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
    
    public init()
    {
        // adds update provider for cell service provider carrierName changes.
        addServiceSubscriberCellularProvidersDidUpdateNotifier()
        executionQueue = DispatchQueue.global(qos: .default)
        
        print(state.appName)
    }
    
    // set a didUpdates closure for carrierName via NetworkInfo in the MatchingEngine SDK.
    private func addServiceSubscriberCellularProvidersDidUpdateNotifier()
    {
        if #available(iOS 12.0, *)
        {
            self.networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = {
                (carrierNameKey: String) -> () in
                self.state.previousCarrierName = self.state.carrierName
                self.state.carrierName = carrierNameKey
            }
        }
        else
        {
            // Deprecated path:
            self.networkInfo.subscriberCellularProviderDidUpdateNotifier = {
                (ctCarrier: CTCarrier) -> () in
                self.state.previousCarrierName = self.state.carrierName
                self.state.carrierName = ctCarrier.carrierName
            }
        }
    }
    
    /// Get SIM card carrierName, or the first entry.
    /// - Returns: String optional, the first unordered name from available carrierNames.
    public func getCarrierName() -> String?
    {
        if let carrierNames = getCarrierNames()
        {
            var firstName: String? = nil
            for (_, ctcarrier) in carrierNames { // Dictionary.
                firstName = ctcarrier.carrierName
                break
            }
            return firstName;
        }
        else
        {
            return nil
        }
    }
    
    /// MARK: getCarrierNames
    /// Get the entire dictionary of carrier names to CTCarrier information objects.
    ///
    /// - Returns: full set of known carrierNames? associated with SIM(s).
    public func getCarrierNames() -> [String: CTCarrier]?
    {
        if #available(iOS 12.0, *)
        {
            let networkInfo = CTTelephonyNetworkInfo()
            let carrierNamesDict: [String: CTCarrier]? = networkInfo.serviceSubscriberCellularProviders
            
            return carrierNamesDict
        }
        else
        {   // subscriberCellularProvider is a deprecated code path.
            let networkInfo = CTTelephonyNetworkInfo()
            if let ctCarrier = networkInfo.subscriberCellularProvider
            {
                var dict = [String: CTCarrier]()
                if let carrierName = ctCarrier.carrierName {
                    dict[carrierName] = ctCarrier
                    return dict
                }
                else
                {
                    return nil
                }
            }
            else
            {
                return nil
            }
        }
    }
    
    public func getDefaultDmePort() -> UInt
    {
        return state.defaultRestDmePort
    }
    
    public func getAppName() -> String
    {
        return state.appName
    }
    
    public func getAppVersion() -> String
    {
        return state.appVersion
    }
    
    // TODO: Other types are valid.
    public func validateGpsLocation(gpsLocation: [String: Any]) throws -> Bool {
        if let longitude = gpsLocation["longitude"] as? CLLocationDegrees {
            if longitude < -180 as CLLocationDegrees || longitude > 180 as CLLocationDegrees
            {
                throw MatchingEngineError.invalidGPSLongitude
            }
        } else {
            throw MatchingEngineError.invalidGPSLongitude
        }
        
        if let latitude = gpsLocation["latitude"] as? CLLocationDegrees {
            if latitude < -90 as CLLocationDegrees || latitude > 90 as CLLocationDegrees
            {
                throw MatchingEngineError.invalidGPSLatitude
            }
        } else {
            throw MatchingEngineError.invalidGPSLatitude
        }
        
        return true
    }
    
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


// common
// FIXME: Util class contents belong in main MatchingEnigne class, and not shared.
public class MexUtil // common to Mex... below
{
    public static let shared = MexUtil() // singleton
    
    // url  //  dme.mobiledgex.net:38001
    let baseDmeHost: String = "dme.mobiledgex.net"
    public let dmePort: UInt = 38001
    
    public let carrierNameDefault_TDG: String = "TDG"
    //    let carrierNameDefault_mexdemo: String = "mexdemo"
    
    public var baseDmeHostInUse: String = "TDG" // baseDmeHost
    public var carrierNameInUse: String = "sdkdemo" // carrierNameDefault_mexdemo
    public var ctCarriers: [String: CTCarrier]?
    public var lastCarrier: CTCarrier?
    
    // API Paths:   See Readme.txt for curl usage examples
    public let registerAPI: String = "/v1/registerclient"
    public let appinstlistAPI: String = "/v1/getappinstlist"
    public let verifylocationAPI: String = "/v1/verifylocation"
    public let findcloudletAPI: String = "/v1/findcloudlet"
    public let qospositionkpiAPI: String = "/v1/getqospositionkpi";
    public let getlocationAPI: String = "/v1/getlocation";
    public let addusertogroupAPI: String = "/v1/addusertogroup"
    
    public var closestCloudlet = ""
    
    private let wifiAlias = "wifi"
    
    private init() //   singleton called as of first access to shared
    {
        baseDmeHostInUse = baseDmeHost // dme.mobiledgex.net
    }
    
    // Retrieve the carrier name of the cellular network interface (MCC and MNC)
    public func getCarrierName() -> String
    {
        var mccMnc = [String]()
        
        do {
            mccMnc = try getMCCMNC()
        } catch {
            if NetworkInterface.hasWifiInterface() { // && !NetworkInterface.hasCellularInterface()
                return wifiAlias
            } else {
                return carrierNameInUse
            }
        }
        
        let mcc = mccMnc[0]
        let mnc = mccMnc[1]
        return "\(mcc)\(mnc)"
    }
    
    public func generateDmeHost(carrierName: String?) throws -> String
    {
        var mccMnc = [String]()
           
        do {
            mccMnc = try getMCCMNC()
        } catch {
            if NetworkInterface.hasWifiInterface() {
                return generateFallbackDmeHost(carrierName: wifiAlias)
            } else {
                throw error
            }
        }
           
        let mcc = mccMnc[0]
        let mnc = mccMnc[1]
        let url = "\(mcc)-\(mnc).\(baseDmeHostInUse)"
        try verifyDmeHost(host: url)
        return url
    }
    
    public func generateFallbackDmeHost(carrierName: String?) -> String
    {
        guard let carrier = carrierName else
        {
            return carrierNameInUse + "." + baseDmeHostInUse
        }
        return carrier + "." + baseDmeHostInUse
    }
    
    // DNS Lookup 
    public func verifyDmeHost(host: String) throws {
        var addrInfo = addrinfo.init()
        var result: UnsafeMutablePointer<addrinfo>!
        
        // getaddrinfo function makes ip + port conversion to sockaddr easy
        let error = getaddrinfo(host, nil, &addrInfo, &result)
        if error != 0 {
            let sysError = SystemError.getaddrinfo(error, errno)
            os_log("Cannot verifyDmeHost error: %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            throw DmeDnsError.verifyDmeHostFailure(host: host, systemError: sysError)
        }
    }
    
    // Returns Array with MCC in zeroth index and MNC in first index
    public func getMCCMNC() throws -> [String]
    {
        let networkInfo = CTTelephonyNetworkInfo()
        
        if #available(iOS 12.0, *) {
            ctCarriers = networkInfo.serviceSubscriberCellularProviders
        } else {
            throw DmeDnsError.outdatedIOS
            // Fallback on earlier versions
        }
        if #available(iOS 12.1, *) {
            networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = { (carrier) in
                self.ctCarriers = networkInfo.serviceSubscriberCellularProviders
                if self.ctCarriers !=  nil {
                    self.lastCarrier = self.ctCarriers![carrier]
                }
            };
        }
          
        lastCarrier = networkInfo.subscriberCellularProvider
        if lastCarrier == nil {
            os_log("Cannot find Subscriber Cellular Provider Info", log: OSLog.default, type: .debug)
            throw DmeDnsError.missingCellularProviderInfo
        }
        guard let mcc = lastCarrier!.mobileCountryCode else {
            os_log("Cannot get Mobile Country Code", log: OSLog.default, type: .debug)
            throw DmeDnsError.missingMCC
        }
        guard let mnc = lastCarrier!.mobileNetworkCode else {
            os_log("Cannot get Mobile Network Code", log: OSLog.default, type: .debug)
            throw DmeDnsError.missingMNC
        }
        
        return [mcc, mnc]
    }
    
    public func generateBaseUri(carrierName: String, port: UInt) throws -> String
    {
        let host = try generateDmeHost(carrierName: carrierName)
        return "https://\(host):\(port)"
    }
    
    public func generateBaseUri(host: String, port: UInt) -> String
    {
        return "https://\(host):\(port)"
    }
} // end MexUtil



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

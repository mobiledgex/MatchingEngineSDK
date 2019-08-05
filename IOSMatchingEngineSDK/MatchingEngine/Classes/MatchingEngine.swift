//
//  MatchingEngineSDK.swift
//  MatchingEngineSDK
//
//  Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.

import Foundation

import Alamofire
import NSLogger
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

/// MexSDK MobiledgeX SDK APIs

// MARK: -

/// MobiledgeX MatchingEngine SDK APIs
public class MatchingEngine
{
    var state: MatchingEngineState = MatchingEngineState()
    let networkInfo = CTTelephonyNetworkInfo()
    
    var sessionManager: SessionManager? // alamofire
    
    // Just standard GCD Queues to dispatch promises into, user initiated priority.
    var executionQueue = DispatchQueue.global(qos: .default)
    
    let headers: HTTPHeaders = [
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
                    self.state.previousCarrierName = self.state.carrierName;
                    self.state.carrierName = carrierNameKey;
            }
        }
        else
        {
            // Deprecated path:
            self.networkInfo.subscriberCellularProviderDidUpdateNotifier = {
                (ctCarrier: CTCarrier) -> () in
                    self.state.previousCarrierName = self.state.carrierName;
                    self.state.carrierName = ctCarrier.carrierName;
            }
        }
    }
    
    // MARK: getCarrierName
    /// Get SIM card carrierName, or the first entry.
    /// - Returns: String optional, the first unordered name from available carrierNames.
    public func getCarrierName() -> String?
    {
        if let carrierNames = getCarrierNames()
        {
            var firstName: String? = nil
            for (name, _) in carrierNames { // Dictionary.
                firstName = name;
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
    
    /// Async https request, Google Promises
    ///
    /// - Parameters:
    ///   - uri:  url
    ///   - request: json/Dictionary
    ///   - postName:  "commandName" posted for observers // Refactor overloaded param target.
    ///
    /// - Returns: Future for later success/failure
    public func postRequest(uri: String,
                            request: [String: Any]) // Dictionary/json
        -> Promise<[String: AnyObject]>
    {
        Logger.shared.log(.network, .debug, "uri: \(uri) request\n \(request) \n")
        
        return Promise<[String: AnyObject]>(on: self.executionQueue) { fulfill, reject in

            // The value is returned via reslove/reject.
            let _ = self.sessionManager!.request(
                uri,
                method: .post,
                parameters: request,
                encoding: JSONEncoding.default,
                headers: self.headers
                ).responseJSON { response in
                    Logger.shared.log(.network, .debug, "\(response.request!)\n")

                    let statusCode = response.response?.statusCode
                    Logger.shared.log(.network, .debug, "HTTP Status Code: \(String(describing: statusCode))")

                    switch response.result
                    {
                    case let .failure(error):
                        Logger.shared.log(.network, .debug, "\(error)")
                        reject(error)
                        return
                        
                    case let .success(data):
                        // First make sure you got back a dictionary if that's what you expect
                        guard let json = data as? [String: AnyObject] else
                        {
                            Logger.shared.log(.network, .debug, "json = \(data)  error")
                            return
                        }
                        Logger.shared.log(.network, .debug, "uri: \(uri) reply json\n \(json) \n")
                        fulfill(json)
                    }

                    Logger.shared.log(.network, .debug, "\(response)")
                    Logger.shared.log(.network, .debug, "result \(response.result)")
                    Logger.shared.log(.network, .debug, "data \(response.data!)")
            }
        }
    }
} // end MatchingEngineSDK


// MARK:- MexUtil

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
    public var carrierNameInUse: String = "mexdemo" // carrierNameDefault_mexdemo
    
    // API Paths:   See Readme.txt for curl usage examples
    public let registerAPI: String = "/v1/registerclient"
    public let appinstlistAPI: String = "/v1/getappinstlist"
    public let verifylocationAPI: String = "/v1/verifylocation"
    public let findcloudletAPI: String = "/v1/findcloudlet"
    public let qospositionkpiAPI: String = "/v1/getqospositionkpi";
    
    public var closestCloudlet = ""
    
    private init() //   singleton called as of first access to shared
    {
        baseDmeHostInUse = baseDmeHost // dme.mobiledgex.net
    }
    
    // Retrieve the carrier name of the cellular network interface.
    public func getCarrierName() -> String
    {
        return carrierNameInUse
    }
    
    public func generateDmeHost(carrierName: String) -> String
    {
        if carrierName == ""
        {
            return carrierNameInUse + "." + baseDmeHostInUse
        }
        return carrierName + "." + baseDmeHostInUse
    }
    
    public func generateBaseUri(carrierName: String, port: UInt) -> String
    {
        return "https://\(generateDmeHost(carrierName: carrierName)):\(port)"
    }
    
    public func generateBaseUri(host: String, port: UInt) -> String
    {
        return "https://\(host):\(port)"
    }
} // end MexUtil


// MARK: -

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

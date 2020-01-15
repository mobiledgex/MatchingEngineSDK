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
//  FindCloudlet.swift
//

import os.log
import CoreLocation

extension MobiledgeXSDK.MatchingEngine {
    
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
    
    // Retrieve the carrier name of the cellular network interface (MCC and MNC)
    public func getCarrierName() -> String?
    {
        var mccMnc = [String]()
        
        do {
            mccMnc = try state.getMCCMNC()
        } catch {
            if MobiledgeXSDK.NetworkInterface.hasWifiInterface() { // && !NetworkInterface.hasCellularInterface()
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
            mccMnc = try state.getMCCMNC()
        } catch {
            if MobiledgeXSDK.NetworkInterface.hasWifiInterface() {
                return generateFallbackDmeHost(carrierName: wifiAlias)
            } else {
                throw error
            }
        }
           
        let mcc = mccMnc[0]
        let mnc = mccMnc[1]
        let url = "\(mcc)-\(mnc).\(baseDmeHost)"
        try verifyDmeHost(host: url)
        return url
    }
    
    public func generateFallbackDmeHost(carrierName: String?) -> String
    {
        guard let carrier = carrierName else
        {
            return carrierNameInUse + "." + baseDmeHost
        }
        return carrier + "." + baseDmeHost
    }
    
    // DNS Lookup
    public func verifyDmeHost(host: String) throws {
        var addrInfo = addrinfo.init()
        var result: UnsafeMutablePointer<addrinfo>!
        
        // getaddrinfo function makes ip + port conversion to sockaddr easy
        let error = getaddrinfo(host, nil, &addrInfo, &result)
        if error != 0 {
            let sysError = MobiledgeXSDK.SystemError.getaddrinfo(error, errno)
            os_log("Cannot verifyDmeHost error: %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            throw MobiledgeXSDK.DmeDnsError.verifyDmeHostFailure(host: host, systemError: sysError)
        }
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
}

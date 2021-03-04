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
import CoreLocation
import CryptoKit

extension MobiledgeXiOSLibrary.MatchingEngine {

    func getAppName() -> String {
        return state.appName
    }
    
    func getAppVersion() -> String {
        return state.appVersion
    }
    
    // TODO: Other types are valid.
    public func validateGpsLocation(gpsLocation: Loc) throws -> Bool {
        if let longitude = gpsLocation.longitude {
            if longitude < -180 as CLLocationDegrees || longitude > 180 as CLLocationDegrees
            {
                throw MatchingEngineError.invalidGPSLongitude
            }
        } else {
            throw MatchingEngineError.invalidGPSLongitude
        }
        
        if let latitude = gpsLocation.latitude {
            if latitude < -90 as CLLocationDegrees || latitude > 90 as CLLocationDegrees
            {
                throw MatchingEngineError.invalidGPSLatitude
            }
        } else {
            throw MatchingEngineError.invalidGPSLatitude
        }
        
        return true
    }
    
    /// Retrieve the carrier name of the cellular network interface (MCC and MNC)
    /// Returns the carrier's mcc+mnc which is mapped to a carrier in the backend (ie. 26201 -> GDDT).
    /// MCC stands for Mobile Country Code and MNC stands for Mobile Network Code.
    /// If useWifiOnly or cellular is off + wifi is up, this will return "".
    /// Empty string carrierName is the alias for any, which will search all carriers for application instances.
    public func getCarrierName() -> String
    {
        var mccMnc = [String]()
        
        if state.isUseWifiOnly() {
            return DMEConstants.fallbackCarrierName
        }
        
        do {
            let roaming = try MobiledgeXiOSLibrary.NetworkInterface.isRoaming()
            if roaming {
                return DMEConstants.fallbackCarrierName
            }
        } catch {
            os_log("Unable to determine if device is roaming. Will continue finding current carrier's information.", log: OSLog.default, type: .debug)
        }
        
        do {
            mccMnc = try MobiledgeXiOSLibrary.CarrierInfo.getMCCMNC()
        } catch {
            return DMEConstants.fallbackCarrierName
        }
        
        let mcc = mccMnc[0]
        let mnc = mccMnc[1]
        let concat = mcc + mnc
        return concat
    }
    
    /// This will generate the dme host name based on GetMccMnc() -> "mcc-mnc.dme.mobiledgex.net".
    /// If getMccMnc fails or returns null, this will return a fallback dme host: "wifi.dme.mobiledgex.net"(this is the EU + GDDT DME).
    /// This function is used by any DME APIs calls where no host and port overloads are provided.
    public func generateDmeHostAddress() throws -> String
    {
        var mccMnc = [String]()
        
        if state.isUseWifiOnly() {
            if MobiledgeXiOSLibrary.NetworkInterface.hasWifi() {
                return generateFallbackDmeHost(carrierName: DMEConstants.wifiAlias)
            } else {
                throw MatchingEngineError.wifiIsNotConnected
            }
        }
        
        do {
            let roaming = try MobiledgeXiOSLibrary.NetworkInterface.isRoaming()
            if roaming {
                return generateFallbackDmeHost(carrierName: DMEConstants.wifiAlias)
            }
        } catch {
            os_log("Unable to determine if device is roaming. Will continue to find DME host based on current carrier's information.", log: OSLog.default, type: .debug)
        }
        
        do {
            mccMnc = try MobiledgeXiOSLibrary.CarrierInfo.getMCCMNC()
        } catch {
            switch error {
            case MobiledgeXiOSLibrary.MobiledgeXError.outdatedIOS:
                throw error
            default:
                // Mnc and Mcc are invalid (cellular is probably not up)
                throw MobiledgeXiOSLibrary.DmeDnsError.unabledToFindMCCOrMNC(internalErr: error)
            }
        }
           
        let mcc = mccMnc[0]
        let mnc = mccMnc[1]
        let url = "\(mcc)-\(mnc).\(DMEConstants.baseDmeHost)"
        try verifyDmeHost(host: url)
        return url
    }
    
    public func generateFallbackDmeHost(carrierName: String?) -> String
    {
        guard let carrier = carrierName else
        {
            return DMEConstants.fallbackCarrierName + "." + DMEConstants.baseDmeHost
        }
        return carrier + "." + DMEConstants.baseDmeHost
    }
    
    /// Makes sure host generated in generateDmeHostAddress is valid
    /// DNS Lookup
    public func verifyDmeHost(host: String) throws {
        var addrInfo = addrinfo.init()
        var result: UnsafeMutablePointer<addrinfo>!
        
        // getaddrinfo function makes ip + port conversion to sockaddr easy
        let error = getaddrinfo(host, nil, &addrInfo, &result)
        if error != 0 {
            let sysError = MobiledgeXiOSLibrary.SystemError.getaddrinfo(error, errno)
            os_log("Cannot verifyDmeHost error: %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            throw MobiledgeXiOSLibrary.DmeDnsError.verifyDmeHostFailure(host: host, systemError: sysError)
        }
    }
    
    public func generateBaseUri(carrierName: String, port: UInt16) throws -> String
    {
        let host = try generateDmeHostAddress()
        return "https://\(host):\(port)"
    }
    
    public func generateBaseUri(host: String, port: UInt16) -> String
    {
        return "https://\(host):\(port)"
    }
    
    /// Device info will be sent as tags parameter in RegisterClient
    public func getDeviceInfo() -> [String: String] {
        var deviceInfo = [String: String]()
        
        deviceInfo["ManufacturerCode"] = state.deviceManufacturer // Apple
        
        // Get Device System information
        let vers = state.device.systemVersion
        deviceInfo["DeviceSoftwareVersion"] = vers
        let model = state.device.model
        deviceInfo["DeviceModel"] = model
        let systemName = state.device.systemName
        deviceInfo["OperatingSystem"] = systemName

        // Get CarrierName
        do {
            let carrierName = try MobiledgeXiOSLibrary.CarrierInfo.getCarrierName()
            deviceInfo["SimOperatorName"] = carrierName
        } catch {
            os_log("Unable to get carriername for SIM. Will not send SimOperator", log: OSLog.default, type: .debug)
        }
        
        // Make sure LocationServices is running before Checking ISO codes
        if !MobiledgeXiOSLibrary.MobiledgeXLocation.locationServicesRunning {
            os_log("Start location services before looking up ISO country codes", log: OSLog.default, type: .debug)
            return deviceInfo
        }
        
        // Get ISO Country Code of current location
        let isoCC = MobiledgeXiOSLibrary.MobiledgeXLocation.getLastISOCountryCode()?.uppercased()
        if let locationCountryCode = isoCC {
            deviceInfo["NetworkCountryIso"] = locationCountryCode
        } else {
            os_log("No ISO Country code for location. Will not send NetworkCountryIso", log: OSLog.default, type: .debug)
        }
        
        // Get ISO Country Code of carrier network
        do {
            let carrierCountryCode = try MobiledgeXiOSLibrary.CarrierInfo.getISOCountryCode().uppercased()
            deviceInfo["SimCountryCodeIso"] = carrierCountryCode
        } catch {
            os_log("Unable to get ISO Country code for SIM. Will not send SimCountryCodeIso", log: OSLog.default, type: .debug)
        }
        return deviceInfo
    }
    
    /// NetworkDataType is sent along with latency information when sending samples to DME
    public func getNetworkDataType() -> String? {
        guard let radioTech = MobiledgeXiOSLibrary.CarrierInfo.networkInfo.serviceCurrentRadioAccessTechnology else {
            os_log("Unable to get radio access technology", log: OSLog.default, type: .debug)
            return nil
        }
        
        if #available(iOS 13.0, *) {
            guard let service = MobiledgeXiOSLibrary.CarrierInfo.networkInfo.dataServiceIdentifier else {
                os_log("Unable to find data service identifier", log: OSLog.default, type: .debug)
                return nil
            }
            return radioTech[service]
        } else {
            os_log("Data service identifier requires iOS 13.0+", log: OSLog.default, type: .debug)
            return nil
        }
    }
    
    func getUniqueID() -> String? {
        let uuid = state.uuid
        return hashSHA512(string: uuid)
    }
    
    func getUniqueIDType() -> String {
        return state.uniqueIDType
    }

    func hashSHA512(string: String) ->  String? {
        if #available(iOS 13.0, *) {
            guard let data = string.data(using: .utf8) else {
                os_log("Unable to convert string: %@ to data. Returning nil", log: OSLog.default, type: .debug, string)
                return nil
            }
            let digest = SHA512.hash(data: data)
            return digest.description
        } else {
            os_log("SHA512 has required ios 13+. Returning nil", log: OSLog.default, type: .debug)
            return nil
        }
    }
}

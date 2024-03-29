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
//  NetworkInterface.swift
//

import Foundation
import Promises
import os.log
import Network

extension MobiledgeXiOSLibraryGrpc {

    /// Contains functions related to network interfaces (cellular, wifi)
    public class NetworkInterface {
        
        public static let CELLULAR = "pdp_ip0"
        public static let WIFI = "en0"
        
        /// Returns true if device has wifi interface (ie. on wifi network)
        public static func hasWifiInterface() -> Bool {
            // Get list of all interfaces on the local machine:
            var ifaddr : UnsafeMutablePointer<ifaddrs>?
            guard getifaddrs(&ifaddr) == 0 else { return false }
            guard let firstAddr = ifaddr else { return false }
            
            // For each interface ...
            for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
                let interface = ifptr.pointee
                
                let addrFamily = interface.ifa_addr.pointee.sa_family
                if addrFamily == UInt8(AF_INET) {  // Returns a MAC address if wifi is not on
                    // Check interface name:
                    let name = String(cString: interface.ifa_name)
                    if name == WIFI {
                        return true
                    }
                }
            }
            return false
        }
        
        /// Returns true if device has cellular interface
        public static func hasCellularInterface() -> Bool {
            // Get list of all interfaces on the local machine:
            var ifaddr : UnsafeMutablePointer<ifaddrs>?
            guard getifaddrs(&ifaddr) == 0 else { return false }
            guard let firstAddr = ifaddr else { return false }
            
            // For each interface ...
            for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
                let interface = ifptr.pointee
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if name == CELLULAR {
                    return true
                }
            }
            return false
        }
        
        /// Returns true if an ip address is assigned to the wifi interface
        public static func hasWifi() -> Bool {
            let ipaddr = getIPAddress(netInterfaceType: WIFI)
            return ipaddr != nil && ipaddr!.count > 0
        }
        
        /// Returns true if an ip address is assigned to the cellular interface
        public static func hasCellular() -> Bool {
            let ipaddr = getIPAddress(netInterfaceType: CELLULAR)
            return ipaddr != nil && ipaddr!.count > 0
        }
        
        /// Compares the ISO Country code of the user's location with the
        /// ISO Country of the user's carrier. Roaming if not equal
        public static func isRoaming() throws -> Bool {
            // Make sure LocationServices is running before Roaming check
            if !MobiledgeXLocation.locationServicesRunning {
                os_log("Start location services before checking if device is roaming", log: OSLog.default, type: .debug)
                throw MobiledgeXLocation.MobiledgeXLocationError.locationServicesNotRunning
            }
            // Get ISO Country Code of current location
            let isoCC = MobiledgeXLocation.getLastISOCountryCode()?.uppercased()
            guard let locationCountryCode = isoCC else {
                os_log("No ISO Country code for location. Try starting location services again", log: OSLog.default, type: .debug)
                throw MobiledgeXLocation.MobiledgeXLocationError.noISOCountryCodeAvailable
            }
            // Get ISO Country Code of carrier network
            let carrierCountryCode = try CarrierInfo.getISOCountryCode().uppercased()
            return locationCountryCode != carrierCountryCode
        }
        
        /// Gets the client IP Address on the interface specified
        // TODO: check for multiple cellular ip addresses (multiple SIM subscriptions possible)
        public static func getIPAddress(netInterfaceType: String?) -> String?
        {
            var netInterfaceType = netInterfaceType
            if netInterfaceType == nil {
                netInterfaceType = MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR // default to cellular
            }
            var address : String?
            // Get list of all interfaces on the local machine:
            var ifaddr : UnsafeMutablePointer<ifaddrs>?
            guard getifaddrs(&ifaddr) == 0 else { return nil }
            guard let firstAddr = ifaddr else { return nil }
            
            // For each interface ...
            for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
                let interface = ifptr.pointee
                
                // Check interface name:
                let name = String(cString: interface.ifa_name)
                if  name == netInterfaceType {
                        
                    // return interface.ifa_addr.pointee
                    let data = NSData(bytes: &interface.ifa_addr.pointee, length: MemoryLayout<sockaddr_in>.size) as CFData // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                    print("interface: \(name), address \(address)")
                    if let _ = IPv4Address(address!) {
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
            return address
        }
        
        // Helper function that gets the local ip address if networkinterface or clientip is specified
        static func getClientIP(netInterfaceType: String? = nil, localEndpoint: String? = nil) throws -> String? {
            if localEndpoint != nil {
                // return localEndpoint if non-nil
                return localEndpoint!
            } else if netInterfaceType != nil {
                // return found local endpoint for specified netInterfaceType if non-nil (Cellular or Wifi)
                guard let boundIP = getIPAddress(netInterfaceType: netInterfaceType) else {
                    os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                    throw(MobiledgeXiOSLibraryGrpc.MatchingEngine.GetConnectionError.invalidNetworkInterface)
                }
                return boundIP
            }
            return nil
        }
    }
}

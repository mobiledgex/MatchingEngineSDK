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

extension MobiledgeXiOSLibrary {

    public enum NetworkInterface {
        
        public static let CELLULAR = "pdp_ip0"
        public static let WIFI = "en0"
        
        // Returns true if device has wifi interface (ie. on wifi network)
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
        
        // Returns true if device has cellular interface
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
        
        // Returns true if an ip address is assigned to the wifi interface
        public static func hasWifi() -> Bool {
            let ipaddr = getIPAddress(netInterfaceType: WIFI)
            return ipaddr != nil && ipaddr!.count > 0
        }
        
        // Returns true if an ip address is assigned to the cellular interface
        public static func hasCellular() -> Bool {
            let ipaddr = getIPAddress(netInterfaceType: CELLULAR)
            return ipaddr != nil && ipaddr!.count > 0
        }
        
        // Gets the client IP Address on the interface specified
        // TODO: check for multiple cellular ip addresses (multiple SIM subscriptions possible)
        public static func getIPAddress(netInterfaceType: String?) -> String?
        {
            var specifiedNetInterface: Bool
            if netInterfaceType == nil {
                specifiedNetInterface = false // default is cellular interface
            } else {
                specifiedNetInterface = true
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
                if  name == netInterfaceType || !specifiedNetInterface {     // Cellular interface
                        
                    // return interface.ifa_addr.pointee
                    let data = NSData(bytes: &interface.ifa_addr.pointee, length: MemoryLayout<sockaddr_in>.size) as CFData                 // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST)
                    address = String(cString: hostname)
                }
            }
            freeifaddrs(ifaddr)
            return address
        }
    }
}

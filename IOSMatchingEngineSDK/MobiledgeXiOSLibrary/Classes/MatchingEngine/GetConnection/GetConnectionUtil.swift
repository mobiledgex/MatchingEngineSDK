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
//  GetConnectionUtil.swift
//

import os.log

extension MobiledgeXiOSLibrary.MatchingEngine {

    public enum GetConnectionProtocol {
      case tcp
      case udp
      case http
      case websocket
    }
    
    public func isEdgeEnabled(proto: GetConnectionProtocol) -> EdgeError? {
        
        if (state.isUseWifiOnly()) {
            return EdgeError.wifiOnly(message: "useWifiOnly must be false to enable edge connection")
        }
        
        if (!MobiledgeXiOSLibrary.NetworkInterface.hasCellularInterface()) {
            return EdgeError.missingCellularInterface(message: "\(proto) connection requires a cellular interface to run connection over edge")
        }
        
        guard let _  = MobiledgeXiOSLibrary.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibrary.NetworkInterface.CELLULAR) else {
            return EdgeError.missingCellularIP(message: "Unable to find ip address for local cellular interface")
        }
        
        if (proto == GetConnectionProtocol.http || proto == GetConnectionProtocol.websocket) {
            if (MobiledgeXiOSLibrary.NetworkInterface.hasWifiInterface()) {
                return EdgeError.defaultWifiInterface(message: "\(proto) connection requires wifi to be off in order to run connection over edge")
            }
        }
        
        return nil
    }
    
    public func getHost(findCloudletReply: FindCloudletReply, appPort: AppPort) throws -> String {
        // Convert fqdn_prefix and fqdn to string
        var fqdnPrefix = appPort.fqdn_prefix
        if fqdnPrefix == nil {
            fqdnPrefix = ""
        }
        
        let fqdn = findCloudletReply.fqdn
        
        let host = fqdnPrefix! + fqdn
        return host
    }
    
    public func getPort(appPort: AppPort, desiredPort: Int) throws -> UInt16 {
        var port: UInt16
        
        let publicPort = appPort.public_port
        // If desired port is -1, then default to public port
        if desiredPort == -1 {
            port = UInt16(truncatingIfNeeded: publicPort)
        } else {
            port = UInt16(desiredPort)
        }
        
        // Check if port is in AppPort range
        do {
            let _ = try self.isInPortRange(appPort: appPort, port: port)
        } catch {
            os_log("Port range check error", log: OSLog.default, type: .debug)
            throw error
        }
        return port
    }
    
    public func createUrl(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, proto: String, path: String = "") throws -> String {
        // Convert fqdn_prefix and fqdn to string
        var fqdnPrefix = appPort.fqdn_prefix
        if fqdnPrefix == nil {
            fqdnPrefix = ""
        }
        
        let fqdn = findCloudletReply.fqdn
        
        var pathPrefix = appPort.path_prefix
        if pathPrefix == nil {
            pathPrefix = ""
        }
        
        let host = fqdnPrefix! + fqdn
        let port = try getPort(appPort: appPort, desiredPort: desiredPort)
        let url = proto + "://" + host + ":" + String(describing: port) + pathPrefix! + path
        return url
    }
    
    
    private func isInPortRange(appPort: AppPort, port: UInt16) throws -> Bool
    {
        let publicPort = UInt16(truncatingIfNeeded: appPort.public_port)
        
        var u16EndPort = appPort.end_port
        if u16EndPort == nil {
            u16EndPort = 0
        }
        let endPort = UInt16(truncatingIfNeeded: u16EndPort!)
        // Checks if a range exists -> if not, check if specified port equals public_port
        if (endPort == 0 || endPort < publicPort) {
            return port == publicPort
        }
        return (port >= publicPort && port <= endPort)
    }
}

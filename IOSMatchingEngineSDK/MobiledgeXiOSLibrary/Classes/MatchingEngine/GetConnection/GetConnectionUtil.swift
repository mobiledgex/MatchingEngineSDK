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
    
    public func getPort(appPort: AppPort, desiredPort: Int = 0) throws -> UInt16 {
        
        let port = try self.validateDesiredPort(appPort: appPort, desiredPort: UInt16(truncatingIfNeeded: desiredPort))
        if (port <= 0) {
            throw GetConnectionError.unableToValidatePort
        }

        return port
    }
    
    public func createUrl(findCloudletReply: FindCloudletReply, appPort: AppPort, proto: String, desiredPort: Int = 0, path: String = "") throws -> String {
        
        if (!validateAppPort(findCloudletReply: findCloudletReply, appPort: appPort)) {
            throw GetConnectionError.unableToValidateAppPort(message: "AppPort provided does not match any AppPorts in FindCloudletReply")
        }
        // Convert fqdn_prefix and fqdn to string
        var fqdnPrefix = appPort.fqdn_prefix
        if fqdnPrefix == nil {
            fqdnPrefix = ""
        }
        
        let fqdn = findCloudletReply.fqdn
        
        let host = fqdnPrefix! + fqdn
        let port = try getPort(appPort: appPort, desiredPort: desiredPort)
        let url = proto + "://" + host + ":" + String(describing: port) + path
        return url
    }
    
    private func validateAppPort(findCloudletReply: FindCloudletReply, appPort: AppPort) -> Bool {
        var found = false
        for ap in findCloudletReply.ports {
            if (ap.proto != appPort.proto) {
                continue
            }
            if (ap == appPort) {
                found = true
            }
        }
        return found
    }
    
    private func validateDesiredPort(appPort: AppPort, desiredPort: UInt16) throws -> UInt16 {
        
        if (!isValidPort(port: desiredPort)) {
            throw GetConnectionError.notValidPort(port: desiredPort)
        }
        
        if (desiredPort == appPort.internal_port || desiredPort == 0) {
          return UInt16(truncatingIfNeeded: appPort.public_port)
        }
        
        if (!isInPortRange(appPort: appPort, port: desiredPort)) {
            throw GetConnectionError.portNotInAppPortRange(port: desiredPort)
        }
        
        return desiredPort
    }
    
    private func isValidPort(port: UInt16) -> Bool {
        return (port <= 65535) && (port >= 0)
    }
    
    private func isInPortRange(appPort: AppPort, port: UInt16) -> Bool
    {
        var endPort: Int32
        if let _ = appPort.end_port {
            endPort = appPort.end_port!
        } else {
            endPort = 0
        }
        
        let mappedEndPort = appPort.public_port + (endPort - appPort.internal_port)
        // Checks if range exists -> if not, check if specified port equals public port
        if (endPort == 0 || mappedEndPort < appPort.public_port)
        {
          return port == appPort.public_port;
        }
        return (port >= appPort.public_port && port <= mappedEndPort);
    }
}

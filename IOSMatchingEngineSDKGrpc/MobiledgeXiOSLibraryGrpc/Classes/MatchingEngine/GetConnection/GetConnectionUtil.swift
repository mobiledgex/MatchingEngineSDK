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

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {

    /// L4 and L7 protocols supported by MobiledgeX iOS GetConnection
    public enum GetConnectionProtocol {
      case tcp
      case udp
      case http
      case websocket
    }
    
    /// Checks whether device will use cellular data path
    /// If using L4 getConnection protocol, GetConnection functions will bind local socket to cellular network interface. So as long as the device has a cellular interface up, it is edgeEnabled
    /// If using L7 getConnection protocol (where we cannot control the network interface), we must check to make sure the device will not default to wifi
    public func isEdgeEnabled(proto: GetConnectionProtocol) -> EdgeError? {
        
        if (state.isUseWifiOnly()) {
            return EdgeError.wifiOnly(message: "useWifiOnly must be false to enable edge connection")
        }
        
        if (!MobiledgeXiOSLibraryGrpc.NetworkInterface.hasCellularInterface()) {
            return EdgeError.missingCellularInterface(message: "\(proto) connection requires a cellular interface to run connection over edge")
        }
        
        guard let _  = MobiledgeXiOSLibraryGrpc.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR) else {
            return EdgeError.missingCellularIP(message: "Unable to find ip address for local cellular interface")
        }
        
        if (proto == GetConnectionProtocol.http || proto == GetConnectionProtocol.websocket) {
            if (MobiledgeXiOSLibraryGrpc.NetworkInterface.hasWifiInterface()) {
                return EdgeError.defaultWifiInterface(message: "\(proto) connection requires wifi to be off in order to run connection over edge")
            }
        }
        
        return nil
    }
    
    /// Returns the host of the developers app backend based on the findCloudletReply and appPort provided.
    /// This function is called by L4 GetConnection functions, but can be called by developers if they are using their own communication client (use GetPort as well)
    public func getHost(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort) throws -> String {
        // Convert fqdn_prefix and fqdn to string
        var fqdnPrefix = appPort.fqdnPrefix
        if fqdnPrefix == nil {
            fqdnPrefix = ""
        }
        
        let fqdn = findCloudletReply.fqdn
        
        let host = fqdnPrefix + fqdn
        return host
    }
    
    /// Returns the port of the developers app backend service based on the appPort provided.
    /// An optional desiredPort parameter is provided if the developer wants a specific port within their appPort port range (if none provided, the function will default to the public_port field in the AppPort).
    /// This function is called by L4 GetConnection functions, but can be called by developers if they are using their own communication client (use GetHost as well).
    public func getPort(appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0) throws -> UInt16 {
        
        let port = try self.validateDesiredPort(appPort: appPort, desiredPort: UInt16(truncatingIfNeeded: desiredPort))
        if (port <= 0) {
            throw GetConnectionError.unableToValidatePort
        }

        return port
    }
    
    ///  Returns the L7 path of the developers app backend based on the the findCloudletReply and appPort provided.
    /// The desired port number must be specified by the developer (use -1 if you want the SDK to choose a port number).
    /// An L7 protocol must also be provided (eg. http, https, ws, wss). The path variable is optional and will be appended to the end of the url.
    /// This function is called by L7 GetConnection functions, but can be called by developers if they are using their own communication client.
    /// Example return value: https://example.com:8888
    public func createUrl(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, proto: String, desiredPort: Int = 0, path: String = "") throws -> String {
        
        if (!validateAppPort(findCloudletReply: findCloudletReply, appPort: appPort)) {
            throw GetConnectionError.unableToValidateAppPort(message: "AppPort provided does not match any AppPorts in FindCloudletReply")
        }
        // Convert fqdn_prefix and fqdn to string
        var fqdnPrefix = appPort.fqdnPrefix
        if fqdnPrefix == nil {
            fqdnPrefix = ""
        }
        
        let fqdn = findCloudletReply.fqdn
        
        let host = fqdnPrefix + fqdn
        let port = try getPort(appPort: appPort, desiredPort: desiredPort)
        let url = proto + "://" + host + ":" + String(describing: port) + path
        return url
    }
    
    public func allowSelfSignedCerts() {
        allowSelfSignedCertsGetConnection = true
    }
    
    public func disableSelfSignedCerts() {
        allowSelfSignedCertsGetConnection = false
    }
    
    private func validateAppPort(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort) -> Bool {
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
    
    private func validateDesiredPort(appPort: DistributedMatchEngine_AppPort, desiredPort: UInt16) throws -> UInt16 {
        
        if (!isValidPort(port: desiredPort)) {
            throw GetConnectionError.notValidPort(port: desiredPort)
        }
        
        if (desiredPort == appPort.internalPort || desiredPort == 0) {
          return UInt16(truncatingIfNeeded: appPort.publicPort)
        }
        
        if (!isInPortRange(appPort: appPort, port: desiredPort)) {
            throw GetConnectionError.portNotInAppPortRange(port: desiredPort)
        }
        
        return desiredPort
    }
    
    private func isValidPort(port: UInt16) -> Bool {
        return (port <= 65535) && (port >= 0)
    }
    
    private func isInPortRange(appPort: DistributedMatchEngine_AppPort, port: UInt16) -> Bool
    {
        let endPort = appPort.endPort
        
        let mappedEndPort = appPort.publicPort + (endPort - appPort.internalPort)
        // Checks if range exists -> if not, check if specified port equals public port
        if (endPort == 0 || mappedEndPort < appPort.publicPort)
        {
          return port == appPort.publicPort;
        }
        return (port >= appPort.publicPort && port <= mappedEndPort);
    }
}

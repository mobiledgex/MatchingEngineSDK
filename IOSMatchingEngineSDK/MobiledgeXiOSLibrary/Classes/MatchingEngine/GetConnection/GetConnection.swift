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
//  GetConnection.swift
//

import os.log
import Promises
import SocketIO
import Network

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    public enum GetConnectionError: Error {
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
    
    // timeout: milliseconds
    public func getTCPConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<CFSocket> {
        
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            let host = try constructHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getTCPConnection(host: host, port: port).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    public func getBSDTCPConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<Socket> {
        
        let promiseInputs: Promise<Socket> = Promise<Socket>.pending()
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        do {
            let host = try constructHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getBSDTCPConnection(host: host, port: port).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
        
    @available(iOS 13.0, *)
    public func getTCPTLSConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<NWConnection> {
        
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()

        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            let host = try constructHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            
            // call helper function and timeout
            return self.getTCPTLSConnection(host: host, port: port, timeout: timeout / 1000.0)
        } catch { // catch getPort and contructHost errors
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    public func getUDPConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<CFSocket> {
        
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            let host = try constructHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getUDPConnection(host: host, port: port).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    public func getBSDUDPConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<Socket> {
        
        let promiseInputs: Promise<Socket> = Promise<Socket>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            let host = try constructHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getBSDUDPConnection(host: host, port: port).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    @available(iOS 13.0, *)
    public func getUDPDTLSConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<NWConnection> {
        
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            let host = try constructHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            
            // call helper function and timeout
            return self.getUDPDTLSConnection(host: host, port: port, timeout: timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    public func getHTTPConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<URLRequest> {
        
        let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            var uri = try constructHTTPUri(findCloudletReply: findCloudletReply, appPort: appPort, desiredPort: desiredPort)
            uri = "http://" + uri
            guard let url = URL(string: uri) else {
                os_log("Unable to create URL struct", log: OSLog.default, type: .debug)
                promiseInputs.reject(GetConnectionError.variableConversionError(message: "Unable to create URL struct"))
                return promiseInputs
            }
            // call helper function and timeout
            return getHTTPClient(url: url).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    public func getHTTPSConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<URLRequest> {
        
        let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            var uri = try constructHTTPUri(findCloudletReply: findCloudletReply, appPort: appPort, desiredPort: desiredPort)
            uri = "https://" + uri
            guard let url = URL(string: uri) else {
                os_log("Unable to create URL struct", log: OSLog.default, type: .debug)
                promiseInputs.reject(GetConnectionError.variableConversionError(message: "Unable to create URL struct"))
                return promiseInputs
            }
            // call helper function and timeout
            return getHTTPClient(url: url).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    public func getWebsocketConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<SocketManager> {
        
        let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            let host = try constructHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getWebsocketConnection(host: host, port: port).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    public func getSecureWebsocketConnection(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String, timeout: Double) -> Promise<SocketManager> {
        
        let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }

        do {
            let host = try constructHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getSecureWebsocketConnection(host: host, port: port).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    private func constructHost(findCloudletReply: [String: AnyObject], appPort: [String: Any]) throws -> String {
        // Convert fqdn_prefix and fqdn to string
        guard let fqdnPrefix = appPort[Ports.fqdn_prefix] as? String else {
            os_log("Unable to cast fqdn prefix as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast fqdn prefix as String")
        }
        guard let fqdn = findCloudletReply[FindCloudletReply.fqdn] as? String else {
            os_log("Unable to cast fqdn as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast fqdn as String")
        }
        
        let host = fqdnPrefix + fqdn
        return host
    }
    
    private func getPort(appPort: [String: Any], desiredPort: String) throws -> String {
        var port: String
        
        guard let publicPortAny = appPort[Ports.public_port] else {
            os_log("Unable to cast public port as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast public port as String")
        }
        let publicPort = String(describing: publicPortAny)
        // If desired port is -1, then default to public port
        if desiredPort == "-1" {
            port = publicPort
        } else {
            port = desiredPort
        }
        
        // Check if port is in AppPort range
        do {
            let _ = try self.isInPortRange(appPort: appPort, port: desiredPort)
        } catch {
            os_log("Port range check error", log: OSLog.default, type: .debug)
            throw error
        }
        return port
    }
    
    private func constructHTTPUri(findCloudletReply: [String: AnyObject], appPort: [String: Any], desiredPort: String) throws -> String {
        // Convert fqdn_prefix and fqdn to string
        guard let fqdnPrefix = appPort[Ports.fqdn_prefix] as? String else {
            os_log("Unable to cast fqdn prefix as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast fqdn prefix as String")
        }
        guard let fqdn = findCloudletReply[FindCloudletReply.fqdn] as? String else {
            os_log("Unable to cast fqdn as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast fqdn as String")
        }
        guard let pathPrefix = appPort[Ports.path_prefix] as? String else {
            os_log("Unable to cast path prefix as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to case path prefix as String")
        }
        
        let host = fqdnPrefix + fqdn
        let port = try getPort(appPort: appPort, desiredPort: desiredPort)
        let uri = host + ":" + port + pathPrefix
        return uri
    }
    
    
    private func isInPortRange(appPort: [String: Any], port: String) throws -> Bool
    {
        guard let publicPort = appPort[Ports.public_port] as? Int else {
            throw GetConnectionError.variableConversionError(message: "Unable to cast public_port to Int")
        }
        guard let endPort = appPort[Ports.end_port] as? Int else {
            throw GetConnectionError.variableConversionError(message: "Unable to cast end_port to Int")
        }
        guard let intPort = Int(port) else {
            throw GetConnectionError.variableConversionError(message: "Unable to cast port to Int")
        }
        // Checks if a range exists -> if not, check if specified port equals public_port
        if (endPort == 0 || endPort < publicPort) {
            return intPort == publicPort
        }
        return (intPort >= publicPort && intPort <= endPort)
    }
}

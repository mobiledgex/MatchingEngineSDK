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
//  GetConnection.swift
//

import os.log
import Promises
import SocketIO
import Network

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // timeout: milliseconds
    public func getTCPConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<CFSocket> {
        
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.tcp) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls != nil && appPort.tls! {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
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
    
    public func getBSDTCPConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<MobiledgeXiOSLibrary.Socket> {
        
        let promiseInputs: Promise<MobiledgeXiOSLibrary.Socket> = Promise<MobiledgeXiOSLibrary.Socket>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.tcp) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls != nil && appPort.tls! {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
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
    public func getTCPTLSConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<NWConnection> {
        
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.tcp) {
            promiseInputs.reject(err)
            return promiseInputs
        }

        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if is TLS configured
        if appPort.tls == nil || !appPort.tls! {
            promiseInputs.reject(GetConnectionError.notTLSConfigured)
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
    
    public func getUDPConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<CFSocket> {
        
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.udp) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls != nil && appPort.tls! {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
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
    
    public func getBSDUDPConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<MobiledgeXiOSLibrary.Socket> {
        
        let promiseInputs: Promise<MobiledgeXiOSLibrary.Socket> = Promise<MobiledgeXiOSLibrary.Socket>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.udp) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls != nil && appPort.tls! {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
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
    public func getUDPDTLSConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<NWConnection> {
        
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.udp) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if is TLS configured
        if appPort.tls == nil || !appPort.tls! {
            promiseInputs.reject(GetConnectionError.notTLSConfigured)
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
    
    public func getHTTPConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<URLRequest> {
        
        let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.http) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls != nil && appPort.tls! {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
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
    
    public func getHTTPSConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<URLRequest> {
        
        let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.http) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if is TLS configured
        if appPort.tls == nil || !appPort.tls! {
            promiseInputs.reject(GetConnectionError.notTLSConfigured)
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
    
    public func getWebsocketConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<SocketManager> {
        
        let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.websocket) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls != nil && appPort.tls! {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
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
    
    public func getSecureWebsocketConnection(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<SocketManager> {
        
        let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
        
        // Make sure device is edge enabled (ie. cellular interface exists and will not default to wifi)
        if let err = isEdgeEnabled(proto: GetConnectionProtocol.websocket) {
            promiseInputs.reject(err)
            return promiseInputs
        }
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if is TLS configured
        if appPort.tls == nil || !appPort.tls! {
            promiseInputs.reject(GetConnectionError.notTLSConfigured)
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
    
    private func constructHost(findCloudletReply: FindCloudletReply, appPort: AppPort) throws -> String {
        // Convert fqdn_prefix and fqdn to string
        guard let fqdnPrefix = appPort.fqdn_prefix as? String else {
            os_log("Unable to cast fqdn prefix as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast fqdn prefix as String")
        }
        guard let fqdn = findCloudletReply.fqdn as? String else {
            os_log("Unable to cast fqdn as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast fqdn as String")
        }
        
        let host = fqdnPrefix + fqdn
        return host
    }
    
    private func getPort(appPort: AppPort, desiredPort: Int) throws -> UInt16 {
        var port: UInt16
        
        guard let publicPort = appPort.public_port as? UInt16 else {
            os_log("Unable to cast public port as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast public port as String")
        }
        // If desired port is -1, then default to public port
        if desiredPort == -1 {
            port = publicPort
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
    
    private func constructHTTPUri(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int) throws -> String {
        // Convert fqdn_prefix and fqdn to string
        guard let fqdnPrefix = appPort.fqdn_prefix as? String else {
            os_log("Unable to cast fqdn prefix as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast fqdn prefix as String")
        }
        guard let fqdn = findCloudletReply.fqdn as? String else {
            os_log("Unable to cast fqdn as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to cast fqdn as String")
        }
        guard let pathPrefix = appPort.path_prefix as? String else {
            os_log("Unable to cast path prefix as String", log: OSLog.default, type: .debug)
            throw GetConnectionError.variableConversionError(message: "Unable to case path prefix as String")
        }
        
        let host = fqdnPrefix + fqdn
        let port = try getPort(appPort: appPort, desiredPort: desiredPort)
        let uri = host + ":" + String(describing: port) + pathPrefix
        return uri
    }
    
    
    private func isInPortRange(appPort: AppPort, port: UInt16) throws -> Bool
    {
        guard let publicPort = appPort.public_port as? UInt16 else {
            throw GetConnectionError.variableConversionError(message: "Unable to cast public_port to Int")
        }
        guard let endPort = appPort.end_port as? UInt16 else {
            throw GetConnectionError.variableConversionError(message: "Unable to cast end_port to Int")
        }
        // Checks if a range exists -> if not, check if specified port equals public_port
        if (endPort == 0 || endPort < publicPort) {
            return port == publicPort
        }
        return (port >= publicPort && port <= endPort)
    }
}

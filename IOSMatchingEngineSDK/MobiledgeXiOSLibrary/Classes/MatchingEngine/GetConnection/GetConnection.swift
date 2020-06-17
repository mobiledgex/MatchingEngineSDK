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
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
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
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
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
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
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
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
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
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
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
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            
            // call helper function and timeout
            return self.getUDPDTLSConnection(host: host, port: port, timeout: timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    public func getHTTPClient(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<URLRequest> {
        
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
            var uri = try createUrl(findCloudletReply: findCloudletReply, appPort: appPort, desiredPort: desiredPort, proto: "http")
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
    
    public func getHTTPSClient(findCloudletReply: FindCloudletReply, appPort: AppPort, desiredPort: Int, timeout: Double) -> Promise<URLRequest> {
        
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
            let uri = try createUrl(findCloudletReply: findCloudletReply, appPort: appPort, desiredPort: desiredPort, proto: "https")
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
            let uri = try createUrl(findCloudletReply: findCloudletReply, appPort: appPort, desiredPort: desiredPort, proto: "ws")
            guard let url = URL(string: uri) else {
                os_log("Unable to create URL struct", log: OSLog.default, type: .debug)
                promiseInputs.reject(GetConnectionError.variableConversionError(message: "Unable to create URL struct"))
                return promiseInputs
            }
            // call helper function and timeout
            return getWebsocketConnection(url: url).timeout(timeout / 1000.0)
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
            let uri = try createUrl(findCloudletReply: findCloudletReply, appPort: appPort, desiredPort: desiredPort, proto: "wss")
            guard let url = URL(string: uri) else {
                os_log("Unable to create URL struct", log: OSLog.default, type: .debug)
                promiseInputs.reject(GetConnectionError.variableConversionError(message: "Unable to create URL struct"))
                return promiseInputs
            }
            // call helper function and timeout
            return getWebsocketConnection(url: url).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
}

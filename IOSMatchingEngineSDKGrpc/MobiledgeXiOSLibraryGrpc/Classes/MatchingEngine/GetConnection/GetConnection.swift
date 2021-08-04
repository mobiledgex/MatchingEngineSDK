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

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    /// getTCPConnection
    /// Get a TCP socket bound to the local cellular interface and connected to the application's backend server.
    /// If no exceptions thrown and object is not null, the socket is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<CFSocket>
    public func getTCPConnection(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, callback: @escaping CFSocketCallBack, desiredPort: Int = 0, netInterfaceType: String? = nil, localEndpoint: String? = nil, timeout: Double = 10000) -> Promise<CFSocket> {
        
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
            return promiseInputs
        }

        do {
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getTCPConnection(host: host, port: port, callback: callback, netInterfaceType: netInterfaceType, localEndpoint: localEndpoint).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    /// getBSDTCPConnection
    /// Gets a BSD TCP socket bound to the local cellular interface and connected to the application's backend server.
    /// If no exceptions thrown and object is not null, the socket is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<MobiledgeXiOSLibrary.Socket>
    public func getBSDTCPConnection(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0, netInterfaceType: String? = nil, localEndpoint: String? = nil, timeout: Double = 10000) -> Promise<MobiledgeXiOSLibraryGrpc.Socket> {
        
        let promiseInputs: Promise<MobiledgeXiOSLibraryGrpc.Socket> = Promise<MobiledgeXiOSLibraryGrpc.Socket>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
            return promiseInputs
        }
        
        do {
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getBSDTCPConnection(host: host, port: port, netInterfaceType: netInterfaceType, localEndpoint: localEndpoint).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    /// getTCPTLSConnection
    /// Gets a TCP socket that is tls configured bound to the local cellular interface and connected to the application's backend server.
    /// If no exceptions thrown and object is not null, the socket is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<NWConnection>
    @available(iOS 13.0, *)
    public func getTCPTLSConnection(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0, netInterfaceType: String? = nil, localEndpoint: String? = nil, timeout: Double = 10000) -> Promise<NWConnection> {
        
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()

        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if is TLS configured
        if !appPort.tls {
            promiseInputs.reject(GetConnectionError.notTLSConfigured)
            return promiseInputs
        }
        
        do {
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            
            // call helper function and timeout
            return self.getTCPTLSConnection(host: host, port: port, netInterfaceType: netInterfaceType, localEndpoint: localEndpoint, timeout: timeout / 1000.0)
        } catch { // catch getPort and contructHost errors
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    /// getUDPConnection
    /// Get a UDP socket bound to the local cellular interface and connected to the application's backend server.
    /// If no exceptions thrown and object is not null, the socket is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<CFSocket>
    public func getUDPConnection(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, callback: @escaping CFSocketCallBack, desiredPort: Int = 0, netInterfaceType: String? = nil, localEndpoint: String? = nil, timeout: Double = 10000) -> Promise<CFSocket> {
        
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
            return promiseInputs
        }

        do {
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getUDPConnection(host: host, port: port, callback: callback, netInterfaceType: netInterfaceType, localEndpoint: localEndpoint).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    /// getBSDUDPConnection
    /// Get a BSD UDP socket bound to the local cellular interface and connected to the application's backend server.
    /// If no exceptions thrown and object is not null, the socket is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<MobiledgeXiOSLibrary.Socket>
    public func getBSDUDPConnection(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0, netInterfaceType: String? = nil, localEndpoint: String? = nil, timeout: Double = 10000) -> Promise<MobiledgeXiOSLibraryGrpc.Socket> {
        
        let promiseInputs: Promise<MobiledgeXiOSLibraryGrpc.Socket> = Promise<MobiledgeXiOSLibraryGrpc.Socket>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
            return promiseInputs
        }

        do {
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            // call helper function and timeout
            return getBSDUDPConnection(host: host, port: port, netInterfaceType: netInterfaceType, localEndpoint: localEndpoint).timeout(timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    /// getUDPDTLSConnection
    /// Get a UDP socket with DTLS configured bound to the local cellular interface and connected to the application's backend server.
    /// If no exceptions thrown and object is not null, the socket is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<CFSocket>
    @available(iOS 13.0, *)
    public func getUDPDTLSConnection(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0, netInterfaceType: String? = nil, localEndpoint: String? = nil, timeout: Double = 10000) -> Promise<NWConnection> {
        
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if is TLS configured
        if !appPort.tls {
            promiseInputs.reject(GetConnectionError.notTLSConfigured)
            return promiseInputs
        }

        do {
            let host = try getHost(findCloudletReply: findCloudletReply, appPort: appPort)
            let port = try getPort(appPort: appPort, desiredPort: desiredPort)
            
            // call helper function and timeout
            return self.getUDPDTLSConnection(host: host, port: port, netInterfaceType: netInterfaceType, localEndpoint: localEndpoint, timeout: timeout / 1000.0)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
    }
    
    /// getHTTPClient
    /// Gets an HTTPClient (URLRequest) object that is edgeEnabled.
    /// If the device is not telco edge enabled (ie. not using cellular data path), error will be returned.
    /// If no exceptions thrown and object is not null, the Client is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<URLRequest>
    public func getHTTPClient(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0, timeout: Double = 10000) -> Promise<URLRequest> {
        
        let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
            return promiseInputs
        }

        do {
            let uri = try createUrl(findCloudletReply: findCloudletReply, appPort: appPort, proto: "http", desiredPort: desiredPort)
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
    
    /// getHTTPSClient
    /// Gets an HTTPSClient (URLRequest) object that is tls configured that is edgeEnabled.
    /// If the device is not telco edge enabled (ie. not using cellular data path), error will be returned.
    /// If no exceptions thrown and object is not null, the Client is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<URLRequest>
    public func getHTTPSClient(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0, timeout: Double = 10000) -> Promise<URLRequest> {
        
        let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if is TLS configured
        if !appPort.tls {
            promiseInputs.reject(GetConnectionError.notTLSConfigured)
            return promiseInputs
        }

        do {
            let uri = try createUrl(findCloudletReply: findCloudletReply, appPort: appPort, proto: "https", desiredPort: desiredPort)
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
    
    /// getWebsocketConnection
    /// Gets a websocket client that is edgeEnabled.
    /// If the device is not telco edge enabled (ie. not using cellular data path), error will be returned.
    /// If no exceptions thrown and object is not null, the Client is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<SocketManager>
    public func getWebsocketConnection(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0, timeout: Double = 10000) -> Promise<SocketManager> {
        
        let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if not TLS configured
        if appPort.tls {
            promiseInputs.reject(GetConnectionError.isTLSConfigured)
            return promiseInputs
        }

        do {
            let uri = try createUrl(findCloudletReply: findCloudletReply, appPort: appPort, proto: "ws", desiredPort: desiredPort)
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
    
    /// getSecureWebsocketConnection
    /// Gets a websocket client that is tls configured that is edgeEnabled.
    /// If the device is not telco edge enabled (ie. not using cellular data path), error will be returned.
    /// If no exceptions thrown and object is not null, the Client is ready to send application data to backend.
    ///
    /// - Parameters
    ///   - findCloudletReply: FindCloudletReply from findCloudlet
    ///   - appPort: Specific AppPort wanted from FindCloudletReply
    ///   - desiredPort: Optional desired port. If none specified, will use public port in given appPort
    ///   - netInterfaceType: Optional network interface type (Cellular or Wifi) to bind to. For a true edgeconnection, set to MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR
    ///   - localEndpoint: Optional local endpoint to bind to
    ///   - timeout: Optional timeout. Default is 10 seconds
    /// - Returns: Promse<SocketManager>

    public func getSecureWebsocketConnection(findCloudletReply: DistributedMatchEngine_FindCloudletReply, appPort: DistributedMatchEngine_AppPort, desiredPort: Int = 0, timeout: Double = 10000) -> Promise<SocketManager> {
        
        let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
        
        // Check if valid timeout
        if timeout <= 0 {
            os_log("Invalid timeout: %@", log: OSLog.default, type: .debug, timeout)
            promiseInputs.reject(GetConnectionError.invalidTimeout)
            return promiseInputs
        }
        
        // Check if is TLS configured
        if !appPort.tls {
            promiseInputs.reject(GetConnectionError.notTLSConfigured)
            return promiseInputs
        }

        do {
            let uri = try createUrl(findCloudletReply: findCloudletReply, appPort: appPort, proto: "wss", desiredPort: desiredPort)
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

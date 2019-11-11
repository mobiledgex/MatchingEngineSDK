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

import Foundation
import NSLogger
import Promises
import SocketIO
import Network

class Ports {
    public static let proto = "proto"
    public static let internal_port = "internal_port"
    public static let public_port = "public_port"
    public static let path_prefix = "path_prefix"
    public static let fqdn_prefix = "fqdn_prefix"
    public static let end_port = "end_port"
}

extension MatchingEngine {
    
    // Returns TCP CFSocket promise
    public func getTCPConnection(host: String, port: String) -> Promise<CFSocket>
    {
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        // local ip bind to cellular network interface
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        
        // initialize CFSocket (no callbacks provided -> developer will implement)
        guard let socket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_STREAM, IPPROTO_TCP, 0, nil, nil) else {
            promiseInputs.reject(GetConnectionError.unableToCreateSocket)
            return promiseInputs
        }
        // initialize addrinfo fields, depending on protocol
        var addrInfo = addrinfo.init()
        addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
        addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets (default)
        
        return connectAndBindCFSocket(serverHost: host, clientHost: clientIP, port: port, addrInfo: &addrInfo, socket: socket)
    }
    
    // returns a TCP NWConnection promise
    @available(iOS 12.0, *)
    public func getTCPTLSConnection(host: String, port: String) -> Promise<NWConnection>
    {
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
        // local ip bind to cellular network interface
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        
        let localEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(clientIP), port: NWEndpoint.Port(port)!)
        let serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(port)!)
        // default tls and tcp options, developer can adjust
        let parameters = NWParameters(tls: .init(), tcp: .init())
        // bind to specific local cellular ip
        parameters.requiredInterfaceType = .cellular // works without specifying endpoint?? (does apple prevent non-wifi?)
        parameters.requiredLocalEndpoint = localEndpoint
        // create NWConnection object with connection to server host and port
        let nwConnection = NWConnection(to: serverEndpoint, using: parameters)
        //ensureStateAndPathReady(connection: nwConnection)
        promiseInputs.fulfill(nwConnection)
        return promiseInputs
    }
    
    // Returns UDP CFSocket promise
    public func getUDPConnection(host: String, port: String) -> Promise<CFSocket>
    {
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        // local ip bind to cellular network interface
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        
        // initialize socket (no callbacks provided -> developer will implement)
        guard let socket = CFSocketCreate(kCFAllocatorDefault, AF_UNSPEC, SOCK_DGRAM, IPPROTO_UDP, 0, nil, nil) else {
            promiseInputs.reject(GetConnectionError.unableToCreateSocket)
            return promiseInputs
        }
        // initialize addrinfo fields, depending on protocol
        var addrInfo = addrinfo.init()
        addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
        addrInfo.ai_socktype = SOCK_DGRAM // UDP datagrams
                        
        return connectAndBindCFSocket(serverHost: host, clientHost: clientIP, port: port, addrInfo: &addrInfo, socket: socket)
    }
    
    // returns a UDP NWConnection promise
    @available(iOS 12.0, *)
    public func getUDPDTLSConnection(host: String, port: String) -> Promise<NWConnection>
    {
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
        // local ip bind to cellular network interface
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        
        // default tls and tcp options
        let parameters = NWParameters(dtls: .init(), udp: .init())
        // bind to specific cellular ip
        parameters.requiredInterfaceType = .cellular // works without specifying endpoint?? (does apple prevent non-wifi?)
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(clientIP), port: NWEndpoint.Port(port)!)
        let nwConnection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(port)!, using: parameters)
        
        promiseInputs.fulfill(nwConnection)
        return promiseInputs
    }
    
    // Returns URLRequest promise
    public func getHTTPConnection(host: String, port: String) -> Promise<URLRequest>
    {
        let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
        
        let uri = "http://\(host):\(port)"
        let url = URL(string: uri)
        if url == nil {
            print("url is nil")
        }
        var urlRequest = URLRequest(url: url!)
        if urlRequest == nil {
            print("urlRequest is nil")
        }
        urlRequest.allowsCellularAccess = true
        promiseInputs.fulfill(urlRequest)
        return promiseInputs
    }
    
    // Returns SocketIOClient promise
    public func getWebsocketConnection(host: String, port: String) -> Promise<SocketManager>
    {
        let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
        
        let url = "wss://\(host):\(port)/"
        let manager = SocketManager(socketURL: URL(string: url)!)
        promiseInputs.fulfill(manager)
        return promiseInputs
    }
    
    // Connect CFSocket to given host and port and bind to cellular interface
    private func connectAndBindCFSocket(serverHost: String, clientHost: String, port: String, addrInfo: UnsafeMutablePointer<addrinfo>, socket: CFSocket) -> Promise<CFSocket>
    {
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        return all (
            getSockAddr(host: serverHost, port: port, addrInfo: addrInfo),
            getSockAddr(host: clientHost, port: port, addrInfo: addrInfo)
        ).then { serverSockAddr, clientSockAddr -> Promise<CFSocket> in // getSockAddr promises returns a pointer to sockaddr struct
            // connect to server
            let serverData = NSData(bytes: serverSockAddr, length: MemoryLayout<sockaddr>.size) as CFData
            let serverError = CFSocketConnectToAddress(socket, serverData, 5) // 5 second timeout
            // bind to client cellular interface
            let clientData = NSData(bytes: clientSockAddr, length: MemoryLayout<sockaddr>.size) as CFData
            let clientError = CFSocketSetAddress(socket, clientData)
            if clientError != CFSocketError.success {
                promiseInputs.reject(GetConnectionError.unableToBind)
                return promiseInputs
            }
            
            switch serverError {
            case .success:
                promiseInputs.fulfill(socket)
            case .error:
                promiseInputs.reject(GetConnectionError.unableToConnectToServer)
            case .timeout:
                promiseInputs.reject(GetConnectionError.connectionTimeout)
            }
            return promiseInputs
        }.catch { error in
            promiseInputs.reject(error)
        }
    }
    
    // creates an addrinfo object, which stores sockaddr struct, return sockaddr struct
    private func getSockAddr(host: String, port: String, addrInfo: UnsafeMutablePointer<addrinfo>) -> Promise<UnsafeMutablePointer<sockaddr>>
    {
        return Promise<UnsafeMutablePointer<sockaddr>>(on: self.executionQueue) { fulfill, reject in
            // Stores addrinfo fields like sockaddr struct, socket type, protocol, and address length
            var res: UnsafeMutablePointer<addrinfo>!
            
            let error = getaddrinfo(host, port, addrInfo, &res)
            if error != 0 {
                let sysError = SystemError.getaddrinfo(error, errno)
                Logger.shared.log(.network, .debug, "Get addrinfo error is \(sysError)")
                reject(sysError)
            }
            fulfill(res.pointee.ai_addr)
        }
    }
}

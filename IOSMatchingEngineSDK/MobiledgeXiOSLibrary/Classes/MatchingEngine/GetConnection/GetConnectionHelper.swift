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
//  GetConnectionHelper.swift
//

import os.log
import Promises
import SocketIO

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // Returns TCP CFSocket promise
    func getTCPConnection(host: String, port: String) -> Promise<CFSocket>
    {
        let promise = Promise<CFSocket>(on: .global(qos: .background)) { fulfill, reject in
            
            // local ip bind to cellular network interface
            guard let clientIP = MobiledgeXiOSLibrary.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibrary.NetworkInterface.CELLULAR) else {
                os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                reject(GetConnectionError.invalidNetworkInterface)
                return
            }
        
            // initialize CFSocket (no callbacks provided -> developer will implement)
            guard let socket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_STREAM, IPPROTO_TCP, 0, nil, nil) else {
                reject(GetConnectionError.unableToCreateSocket)
                return
            }
            // initialize addrinfo fields, depending on protocol
            var addrInfo = addrinfo.init()
            addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
            addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets (default)
        
            self.connectAndBindCFSocket(serverHost: host, clientHost: clientIP, port: port, addrInfo: &addrInfo, socket: socket)
            .then { socket in
                    fulfill(socket)
            }.catch { error in
                reject(error)
            }
        }
        return promise
    }
    
    // Returns UDP CFSocket promise
    func getUDPConnection(host: String, port: String) -> Promise<CFSocket>
    {
        let promise = Promise<CFSocket>(on: .global(qos: .background)) { fulfill, reject in
            
            // local ip bind to cellular network interface
            guard let clientIP = MobiledgeXiOSLibrary.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibrary.NetworkInterface.CELLULAR) else {
                os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                reject(GetConnectionError.invalidNetworkInterface)
                return
            }
        
            // initialize socket (no callbacks provided -> developer will implement)
            guard let socket = CFSocketCreate(kCFAllocatorDefault, AF_UNSPEC, SOCK_DGRAM, IPPROTO_UDP, 0, nil, nil) else {
                reject(GetConnectionError.unableToCreateSocket)
                return
            }
            // initialize addrinfo fields, depending on protocol
            var addrInfo = addrinfo.init()
            addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
            addrInfo.ai_socktype = SOCK_DGRAM // UDP datagrams
                        
            self.connectAndBindCFSocket(serverHost: host, clientHost: clientIP, port: port, addrInfo: &addrInfo, socket: socket)
            .then { socket in
                    fulfill(socket)
            }.catch { error in
                reject(error)
            }
        }
        return promise
    }
    
    func getHTTPClient(url: URL) -> Promise<URLRequest>
    {
        let promise = Promise<URLRequest>(on: .global(qos: .background)) { fulfill, reject in
            guard let host = url.host else {
                reject(GetConnectionError.incorrectURLSyntax)
                return
            }
            // DNS lookup
            do {
                try self.verifyDmeHost(host: host)
            } catch {
                reject(error)
            }
            var urlRequest = URLRequest(url: url)
            urlRequest.allowsCellularAccess = true
            fulfill(urlRequest)
        }
        return promise
    }
    
    // Returns SocketIOClient promise
    func getWebsocketConnection(host: String, port: String) -> Promise<SocketManager>
    {
        let promise = Promise<SocketManager>(on: .global(qos: .background)) { fulfill, reject in
            // DNS Lookup
            do {
                try self.verifyDmeHost(host: host)
            } catch {
                reject(error)
            }
            let url = "ws://\(host):\(port)/"
            let manager = SocketManager(socketURL: URL(string: url)!)
            fulfill(manager)
        }
        return promise
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
        return Promise<UnsafeMutablePointer<sockaddr>>(on: self.state.executionQueue) { fulfill, reject in
            // Stores addrinfo fields like sockaddr struct, socket type, protocol, and address length
            var res: UnsafeMutablePointer<addrinfo>!
            
            let error = getaddrinfo(host, port, addrInfo, &res)
            if error != 0 {
                let sysError = MobiledgeXiOSLibrary.SystemError.getaddrinfo(error, errno)
                os_log("Get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                reject(sysError)
            }
            fulfill(res.pointee.ai_addr)
        }
    }
}

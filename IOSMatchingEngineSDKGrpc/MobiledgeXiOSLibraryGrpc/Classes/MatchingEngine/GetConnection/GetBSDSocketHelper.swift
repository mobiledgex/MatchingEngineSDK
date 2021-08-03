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
//  GetBSDConnection.swift
//

import os.log
import Promises

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {

    func getBSDTCPConnection(host: String, port: UInt16, netInterfaceType: String? = nil, localEndpoint: String? = nil) -> Promise<MobiledgeXiOSLibraryGrpc.Socket>
    {
        let promise = Promise<MobiledgeXiOSLibraryGrpc.Socket>(on: .global(qos: .background)) { fulfill, reject in

            // initialize addrinfo fields
            var addrInfo = addrinfo.init()
            addrInfo.ai_family = AF_INET // IPv4
            addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets (default)
            
            // find clientIP if needed
            var clientIP: String?
            do {
                try clientIP = MobiledgeXiOSLibraryGrpc.NetworkInterface.getClientIP(netInterfaceType: netInterfaceType, localEndpoint: localEndpoint)
            } catch {
                reject(error)
                return
            }

            self.bindBSDClientSocketAndConnectServerSocket(addrInfo: &addrInfo, clientIP: clientIP, serverFqdn: host, port: String(describing: port))
            .then { socket in
                fulfill(socket)
            }.catch { error in
                reject(error)
            }
        }
        return promise
    }

    func getBSDUDPConnection(host: String, port: UInt16, netInterfaceType: String? = nil, localEndpoint: String? = nil) -> Promise<MobiledgeXiOSLibraryGrpc.Socket>
    {
        let promise = Promise<MobiledgeXiOSLibraryGrpc.Socket>(on: .global(qos: .background)) { fulfill, reject in

            // initialize addrinfo fields
            var addrInfo = addrinfo.init()
            addrInfo.ai_family = AF_INET // IPv4
            addrInfo.ai_socktype = SOCK_DGRAM // UDP
            
            // find clientIP if needed
            var clientIP: String?
            do {
                try clientIP = MobiledgeXiOSLibraryGrpc.NetworkInterface.getClientIP(netInterfaceType: netInterfaceType, localEndpoint: localEndpoint)
            } catch {
                reject(error)
                return
            }

            self.bindBSDClientSocketAndConnectServerSocket(addrInfo: &addrInfo, clientIP: clientIP, serverFqdn: host, port: String(describing: port))
            .then { socket in
                fulfill(socket)
            }.catch { error in
                reject(error)
            }
        }
        return promise
    }

    private func bindBSDClientSocketAndConnectServerSocket(addrInfo: UnsafeMutablePointer<addrinfo>, clientIP: String?, serverFqdn: String, port: String)  -> Promise<MobiledgeXiOSLibraryGrpc.Socket>
    {
        let promiseInputs: Promise<MobiledgeXiOSLibraryGrpc.Socket> = Promise<MobiledgeXiOSLibraryGrpc.Socket>.pending()

        // socket returns a socket descriptor
        let s = socket(addrInfo.pointee.ai_family, addrInfo.pointee.ai_socktype, 0)  // protocol set to 0 to choose proper protocol for given socktype
        if s == -1 {
            let sysError = MobiledgeXiOSLibraryGrpc.SystemError.socket(s, errno)
            os_log("Client socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
        
        var clientRes: UnsafeMutablePointer<addrinfo>?
        if clientIP != nil {
            // Bind to client cellular interface
            // used to store addrinfo fields like sockaddr struct, socket type, protocol, and address length
            // getaddrinfo function makes ip + port conversion to sockaddr easy
            let error = getaddrinfo(clientIP, nil, addrInfo, &clientRes)
            if error != 0 {
                let sysError = MobiledgeXiOSLibraryGrpc.SystemError.getaddrinfo(error, errno)
                os_log("Client get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                promiseInputs.reject(sysError)
                return promiseInputs
            }
            
            // bind to socket
            let b = bind(s, clientRes!.pointee.ai_addr, clientRes!.pointee.ai_addrlen)
            if b == -1 {
                let sysError = MobiledgeXiOSLibraryGrpc.SystemError.bind(b, errno)
                os_log("Client bind error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                promiseInputs.reject(sysError)
                return promiseInputs
            }
        }

        // Connect to server
        var serverRes: UnsafeMutablePointer<addrinfo>!
        let serverError = getaddrinfo(serverFqdn, port, addrInfo, &serverRes)
        if serverError != 0 {
            let sysError = MobiledgeXiOSLibraryGrpc.SystemError.getaddrinfo(serverError, errno)
            os_log("Server get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
        let serverSocket = socket(serverRes.pointee.ai_family, serverRes.pointee.ai_socktype, 0)
        if serverSocket == -1 {
            let sysError = MobiledgeXiOSLibraryGrpc.SystemError.connect(serverSocket, errno)
            os_log("Server socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
        // connect our socket to the provisioned socket
        let c = connect(s, serverRes.pointee.ai_addr, serverRes.pointee.ai_addrlen)
        if c == -1 {
            let sysError = MobiledgeXiOSLibraryGrpc.SystemError.connect(c, errno)
            os_log("Connection error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
            
        let socket = MobiledgeXiOSLibraryGrpc.Socket(localAddrInfo: clientRes, remoteAddrInfo: serverRes, sockfd: s)
        promiseInputs.fulfill(socket)
        return promiseInputs
    }
}

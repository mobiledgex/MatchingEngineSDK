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
//  GetBSDConnection.swift
//

import Foundation
import os.log
import Promises

public struct Socket {
    var addrInfo: UnsafeMutablePointer<addrinfo>
    var sockfd: Int32
}

extension MatchingEngine {

    func getBSDTCPConnection(host: String, port: String) -> Promise<Socket>
    {
        let promise = Promise<Socket>(on: .global(qos: .background)) { fulfill, reject in
            
            guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.CELLULAR) else {
                os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                reject(GetConnectionError.invalidNetworkInterface)
                return
            }

            // initialize addrinfo fields
            var addrInfo = addrinfo.init()
            addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
            addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets (default)

            self.bindBSDClientSocketAndConnectServerSocket(addrInfo: &addrInfo, clientIP: clientIP, serverFqdn: host, port: port)
            .then { socket in
                    fulfill(socket)
            }.catch { error in
                reject(error)
            }
        }
        return promise
    }

    func getBSDUDPConnection(host: String, port: String) -> Promise<Socket>
    {
        let promise = Promise<Socket>(on: .global(qos: .background)) { fulfill, reject in
            
            guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.CELLULAR) else {
                os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                reject(GetConnectionError.invalidNetworkInterface)
                return
            }

            // initialize addrinfo fields
            var addrInfo = addrinfo.init()
            addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
            addrInfo.ai_socktype = SOCK_DGRAM // UDP

            self.bindBSDClientSocketAndConnectServerSocket(addrInfo: &addrInfo, clientIP: clientIP, serverFqdn: host, port: port)
            .then { socket in
                    fulfill(socket)
            }.catch { error in
                reject(error)
            }
        }
        return promise
    }

    private func bindBSDClientSocketAndConnectServerSocket(addrInfo: UnsafeMutablePointer<addrinfo>, clientIP: String, serverFqdn: String, port: String)  -> Promise<Socket>
    {
        let promiseInputs: Promise<Socket> = Promise<Socket>.pending()

        // Bind to client cellular interface
        // used to store addrinfo fields like sockaddr struct, socket type, protocol, and address length
        var res: UnsafeMutablePointer<addrinfo>!
        // getaddrinfo function makes ip + port conversion to sockaddr easy
        let error = getaddrinfo(clientIP, port, addrInfo, &res)
        if error != 0 {
            let sysError = SystemError.getaddrinfo(error, errno)
            os_log("Client get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
        // socket returns a socket descriptor
        let s = socket(res.pointee.ai_family, res.pointee.ai_socktype, 0)  // protocol set to 0 to choose proper protocol for given socktype
        if s == -1 {
            let sysError = SystemError.socket(s, errno)
            os_log("Client socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
        // bind to socket to client cellular network interface
        let b = bind(s, res.pointee.ai_addr, res.pointee.ai_addrlen)
        if b == -1 {
            let sysError = SystemError.bind(b, errno)
            os_log("Client bind error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }

        // Connect to server
        var serverRes: UnsafeMutablePointer<addrinfo>!
        let serverError = getaddrinfo(serverFqdn, port, addrInfo, &serverRes)
        if serverError != 0 {
            let sysError = SystemError.getaddrinfo(serverError, errno)
            os_log("Server get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
        let serverSocket = socket(serverRes.pointee.ai_family, serverRes.pointee.ai_socktype, 0)
        if serverSocket == -1 {
            let sysError = SystemError.connect(serverSocket, errno)
            os_log("Server socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
        // connect our socket to the provisioned socket
        let c = connect(s, serverRes.pointee.ai_addr, serverRes.pointee.ai_addrlen)
        if c == -1 {
            let sysError = SystemError.connect(c, errno)
            os_log("Connection error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
            promiseInputs.reject(sysError)
            return promiseInputs
        }
            
        let socket = Socket(addrInfo: res, sockfd: s)
        promiseInputs.fulfill(socket)
        return promiseInputs
    }
}

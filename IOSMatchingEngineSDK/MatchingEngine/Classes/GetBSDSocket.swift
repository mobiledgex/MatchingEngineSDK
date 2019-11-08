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
import NSLogger
import Promises

extension MatchingEngine {

    public func getRawTCPConnection(findCloudletReply: [String: AnyObject]) -> Promise<UnsafeMutablePointer<addrinfo>>
    {
        let promiseInputs: Promise<UnsafeMutablePointer<addrinfo>> = Promise<UnsafeMutablePointer<addrinfo>>.pending()
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        // list of available TCP ports
        guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
            Logger.shared.log(.network, .debug, "Cannot get public port")
            promiseInputs.reject(GetConnectionError.missingServerPort)
            return promiseInputs
        }
        let port = ports[0]
        // server host
        guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
            Logger.shared.log(.network, .debug, "Cannot get server fqdn")
            promiseInputs.reject(GetConnectionError.missingServerFqdn)
            return promiseInputs
        }
        // initialize addrinfo fields
        var addrInfo = addrinfo.init()
        addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
        addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets (default)

        return self.bindClientSocketAndConnectServerSocket(addrInfo: &addrInfo, clientIP: clientIP, serverFqdn: serverFqdn, port: port)
        }

    public func getRawUDPConnection(findCloudletReply: [String: AnyObject]) -> Promise<UnsafeMutablePointer<addrinfo>>
    {
        let promiseInputs: Promise<UnsafeMutablePointer<addrinfo>> = Promise<UnsafeMutablePointer<addrinfo>>.pending()
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        // list of available UDP ports
        guard let ports = self.getUDPPorts(findCloudletReply: findCloudletReply) else {
            Logger.shared.log(.network, .debug, "Cannot get public port")
            promiseInputs.reject(GetConnectionError.missingServerPort)
            return promiseInputs
        }
        let port = ports[0]
        // server host
        guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
            Logger.shared.log(.network, .debug, "Cannot get server fqdn")
            promiseInputs.reject(GetConnectionError.missingServerFqdn)
            return promiseInputs
        }
        let port = ports[0]
        // server host
        guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
            Logger.shared.log(.network, .debug, "Cannot get server fqdn")
            promiseInputs.reject(GetConnectionError.missingServerFqdn)
            return promiseInputs
        }
        // initialize addrinfo fields
        var addrInfo = addrinfo.init()
        addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
        addrInfo.ai_socktype = SOCK_DGRAM // UDP

        return self.bindClientSocketAndConnectServerSocket(addrInfo: &addrInfo, clientIP: clientIP, serverFqdn: serverFqdn, port: port)
    }

    private func bindClientSocketAndConnectServerSocket(addrInfo: UnsafeMutablePointer<addrinfo>, clientIP: String, serverFqdn: String, port: String)  -> Promise<UnsafeMutablePointer<addrinfo>>
    {
        return Promise<UnsafeMutablePointer<addrinfo>>(on: self.executionQueue) { fulfill, reject in

            // Bind to client cellular interface
            // used to store addrinfo fields like sockaddr struct, socket type, protocol, and address length
            var res: UnsafeMutablePointer<addrinfo>!
            // getaddrinfo function makes ip + port conversion to sockaddr easy
            let error = getaddrinfo(clientIP, port, addrInfo, &res)
            if error != 0 {
                let sysError = SystemError.getaddrinfo(error, errno)
                Logger.shared.log(.network, .debug, "Client get addrinfo error is \(sysError)")
                reject(sysError)
            }
            // socket returns a socket descriptor
            let s = socket(res.pointee.ai_family, res.pointee.ai_socktype, 0)  // protocol set to 0 to choose proper protocol for given socktype
            if s == -1 {
                let sysError = SystemError.socket(s, errno)
                Logger.shared.log(.network, .debug, "Client socket error is \(sysError)")
                reject(sysError)
            }
            // bind to socket to client cellular network interface
            let b = bind(s, res.pointee.ai_addr, res.pointee.ai_addrlen)
            if b == -1 {
                let sysError = SystemError.bind(b, errno)
                Logger.shared.log(.network, .debug, "Client bind error is \(sysError)")
                reject(sysError)
            }

            // Connect to server
            var serverRes: UnsafeMutablePointer<addrinfo>!
            let serverError = getaddrinfo(serverFqdn, port, addrInfo, &serverRes)
            if serverError != 0 {
                let sysError = SystemError.getaddrinfo(serverError, errno)
                Logger.shared.log(.network, .debug, "Server get addrinfo error is \(sysError)")
                reject(sysError)
            }
            let serverSocket = socket(serverRes.pointee.ai_family, serverRes.pointee.ai_socktype, 0)
            if serverSocket == -1 {
                let sysError = SystemError.connect(serverSocket, errno)
                Logger.shared.log(.network, .debug, "Server socket error is \(sysError)")
                reject(sysError)
            }
            // connect our socket to the provisioned socket
            let c = connect(s, serverRes.pointee.ai_addr, serverRes.pointee.ai_addrlen)
            if c == -1 {
                let sysError = SystemError.connect(c, errno)
                Logger.shared.log(.network, .debug, "Connection error is \(sysError)")
                reject(sysError)
            }
            fulfill(res)
        }
    }
}

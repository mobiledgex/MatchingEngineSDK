// Copyright 2020 MobiledgeX, Inc. All rights and licenses reserved.
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
//  NetTest.swift
//

import os.log
import Combine

extension MobiledgeXiOSLibrary.PerformanceMetrics {
    
    @available(iOS 13.0, *)
    public class NetTest {
        
        var netTestDispatchQueue: DispatchQueue?
        public var sites: [Site]
        public var tests: [AnyCancellable]
        public var timeout = 5.0
        var interval: Int?
        
        let NANO_TO_MILLI = 1.0 / 1000000.0
        
        public enum TestType {
            case PING
            case CONNECT
        }
        
        public init(sites: [Site]) {
            self.sites = sites
            netTestDispatchQueue = DispatchQueue(label: "nettest.queue", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: .global())
            tests = [AnyCancellable]()
        }

        // interval in milliseconds
        public func runTest(interval: Int) {
            self.interval = interval
            for site in sites {
                let test = netTestDispatchQueue!.schedule(after: .init(.now()), interval: .milliseconds(interval), tolerance: .milliseconds(1), options: .init(),
                {
                    switch site.testType {
                    case .CONNECT:
                        if site.l7Path != nil {
                            self.connectAndDisconnect(site: site)
                        } else {
                            self.connectAndDisconnectSocket(site: site)
                        }
                    case .PING:
                        os_log("No ping implemented. Using CONNECT", log: OSLog.default, type: .debug)
                        if site.l7Path != nil {
                            self.connectAndDisconnect(site: site)
                        } else {
                            self.connectAndDisconnectSocket(site: site)
                        }
                    }
                })
                test.store(in: &tests)
            }
        }
        
        public func cancelTest() {
            for test in tests {
                test.cancel()
            }
            tests.removeAll()
        }
        
        public func addSite(site: Site) {
            self.sites.append(site)
            guard let interval = self.interval else {
                return
            }
            self.cancelTest()
            self.runTest(interval: interval)
        }
        
        public func removeSite(site: Site) {
            if let idx = sites.firstIndex(of: site) {
                self.sites.remove(at: idx)
            }
            guard let interval = self.interval else {
                return
            }
            self.cancelTest()
            self.runTest(interval: interval)
        }
        
        public func connectAndDisconnect(site: Site) {
            // check if http path or just host and port
            guard let path = site.l7Path else {
                os_log("HTTP connect and disconnect requires l7Path", log: OSLog.default, type: .debug)
                return
            }
            let url = URL(string: path)
            
            //initialize urlRequest
            var urlRequest = URLRequest(url: url!)
            urlRequest.httpMethod = "HEAD"
            if site.network == MobiledgeXiOSLibrary.NetworkInterface.CELLULAR {
                urlRequest.allowsCellularAccess = true
            }
            
            let before = DispatchTime.now()
            let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: { _, response, error in
                
                let after = DispatchTime.now()
                
                if error != nil {
                    os_log("Error is %@", log: OSLog.default, type: .debug, error.debugDescription)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    os_log("Cannot get response", log: OSLog.default, type: .debug)
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    let elapsedTime = after.uptimeNanoseconds - before.uptimeNanoseconds
                    site.addSample(sample: Double(elapsedTime) * self.NANO_TO_MILLI) // convert to milliseconds
                }
            })
            task.resume()
        }
        
        // Allows bind to cellular interface
        public func connectAndDisconnectSocket(site: Site) {
            
            if site.l7Path != nil {
                os_log("Connect and disconnect socket requires host and port", log: OSLog.default, type: .debug)
                return
            }
            
            var ip: String?
            if site.network != MobiledgeXiOSLibrary.NetworkInterface.WIFI {
                // default to Cellular interface unless wifi specified
                ip = MobiledgeXiOSLibrary.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibrary.NetworkInterface.CELLULAR)
            } else {
                ip = MobiledgeXiOSLibrary.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibrary.NetworkInterface.WIFI)
            }
            
            guard let localIP = ip else {
                os_log("Could not get network interface to bind to", log: OSLog.default, type: .debug)
                return
            }
            
            // initialize addrinfo fields
            var addrInfo = addrinfo.init()
            addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
            addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets
            
            bindAndConnectSocket(site: site, addrInfo: &addrInfo, localIP: localIP)
        }
        
        // Same function is in GetBSDSocketHelper (Create socket class outside of MatchingEngine?)
        private func bindAndConnectSocket(site: Site, addrInfo: UnsafeMutablePointer<addrinfo>, localIP: String) {
            
            // Bind to client cellular interface
            // used to store addrinfo fields like sockaddr struct, socket type, protocol, and address length
            var res: UnsafeMutablePointer<addrinfo>!
            // getaddrinfo function makes ip + port conversion to sockaddr easy
            let error = getaddrinfo(localIP, nil, addrInfo, &res)
            if error != 0 {
                let sysError = MobiledgeXiOSLibrary.SystemError.getaddrinfo(error, errno)
                os_log("Client get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            // socket returns a socket descriptor
            let s = socket(res.pointee.ai_family, res.pointee.ai_socktype, 0)  // protocol set to 0 to choose proper protocol for given socktype
            if s == -1 {
                let sysError = MobiledgeXiOSLibrary.SystemError.socket(s, errno)
                os_log("Client socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            // bind to socket to client cellular network interface
            let b = bind(s, res.pointee.ai_addr, res.pointee.ai_addrlen)
            if b == -1 {
                let sysError = MobiledgeXiOSLibrary.SystemError.bind(b, errno)
                os_log("Client bind error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }

            // Connect to server
            var serverRes: UnsafeMutablePointer<addrinfo>!
            let serverError = getaddrinfo(site.host, site.port, addrInfo, &serverRes)
            if serverError != 0 {
                let sysError = MobiledgeXiOSLibrary.SystemError.getaddrinfo(serverError, errno)
                os_log("Server get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            let serverSocket = socket(serverRes.pointee.ai_family, serverRes.pointee.ai_socktype, 0)
            if serverSocket == -1 {
                let sysError = MobiledgeXiOSLibrary.SystemError.connect(serverSocket, errno)
                os_log("Server socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            // connect our socket to the provisioned socket
            let before = DispatchTime.now()
            let c = connect(s, serverRes.pointee.ai_addr, serverRes.pointee.ai_addrlen)
            let after = DispatchTime.now()
            if c == -1 {
                let sysError = MobiledgeXiOSLibrary.SystemError.connect(c, errno)
                os_log("Connection error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            
            close(s)
            close(serverSocket)
            
            let elapsedTime = after.uptimeNanoseconds - before.uptimeNanoseconds
            site.addSample(sample: Double(elapsedTime) * self.NANO_TO_MILLI) // convert to milliseconds
        }
    }
}


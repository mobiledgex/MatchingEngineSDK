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
//  NetTest.swift
//

import Foundation
import os.log
import Combine
import Promises
import SPLPing

extension MobiledgeXiOSLibraryGrpc.PerformanceMetrics {
    
    /// Class that allows developers to easily test latency of their various backend servers.
    /// This is used in the implementation of FindCloudlet Performance Mode.
    @available(iOS 13.0, *)
    public class NetTest {
        
        var netTestDispatchQueue: DispatchQueue?
        public var sites: [Site]
        public var tests: [AnyCancellable]
        public var timeout = 5.0
        var interval: Int?
                
        let NANO_TO_MILLI = 1.0 / 1000000.0
        let DEFAULT_NUM_SAMPLES = 3
        
        /// TestType is either PING or CONNECT, where PING is ICMP Ping (not implemented) and CONNECT is is actually setting up a connection and then disconnecting immediately.
        public enum TestType {
            case PING
            case CONNECT
        }
        
        public init(sites: [Site], qos: DispatchQoS) {
            self.sites = sites
            netTestDispatchQueue = DispatchQueue(label: "mobiledgexioslibrary.performancemetrics.nettest", qos: qos, attributes: .concurrent, autoreleaseFrequency: .inherit, target: .global())
            tests = [AnyCancellable]()
        }

        /// Run tests at interval (milliseconds) indefinitely until call to cancelTest
        public func runTest(interval: Int) {
            cancelTest() // clear our previous data
                        
            self.interval = interval
            for site in sites {
                let test = netTestDispatchQueue!.schedule(after: .init(.now()), interval: .milliseconds(interval), tolerance: .milliseconds(1), options: .init(),
                {
                    self.testSite(site: site)
                })
                test.store(in: &tests)
            }
        }
        
        /// Run NetTest for numSamples per site
        public func runTest(numSamples: Int? = nil) -> Promise<[Site]> {
            let num = numSamples == nil ? DEFAULT_NUM_SAMPLES : numSamples!
            cancelTest() // clear our previous data
            let promise: Promise<[Site]> = Promise<[Site]>.pending()
                        
            let group = DispatchGroup()
            for _ in 1...num {
                for site in sites {
                    group.enter()
                    self.testSite(site: site).then { site in
                        group.leave()
                    }.catch { error in
                        os_log("Unable to test site. Error is %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        group.leave()
                    }
                }
            }
            // Once each testSite call completes and each "task" leaves the group, the following will be called
            group.notify(queue: DispatchQueue.main) {
                promise.fulfill(self.returnSortedSites())
            }
            
            return promise
        }
        
        // Based on test type and protocol, call the correct test
        private func testSite(site: Site) -> Promise<Site> {
            switch site.testType {
            case .CONNECT:
                if site.l7Path != nil {
                    return self.connectAndDisconnect(site: site)
                } else {
                    return self.connectAndDisconnectSocket(site: site)
                }
            case .PING:
                os_log("Swift does not have ping built in natively, so ping times may not be accurate. If possible, use connectAndDisconnect for more accurate results.", log: OSLog.default, type: .debug)
                return self.ping(site: site)
            }
        }
        
        /// Sorted list of Sites from best to worst
        public func returnSortedSites() -> [Site] {
            sites.sort { site1 , site2 in
                if site1.samples.count == 0 || site2.samples.count == 0 {
                    return site1.samples.count > site2.samples.count
                }
                
                if site1.avg == 0 || site2.avg == 0 {
                    return site1.avg > site2.avg
                }
                
                if site1.avg != site2.avg {
                    return site1.avg < site2.avg
                }
                
                if site1.stdDev == 0 || site2.stdDev == 0 {
                    return site1.stdDev > site2.stdDev
                }
                
                return site1.stdDev < site2.stdDev
            }
            return sites
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
        
        public func ping(site: Site) -> Promise<Site> {
            let promise = Promise<Site>.pending()
            let pingInterval: TimeInterval = 1.0
            let configuration = SPLPingConfiguration(pingInterval: pingInterval)
            SPLPing.pingOnce(site.host!, configuration: configuration) { (response: SPLPingResponse) in
                if response.error != nil {
                    promise.reject(response.error!)
                }
                site.addSample(sample: response.duration * 1000) // convert seconds to milliseconds
                promise.fulfill(site)
            }
            return promise
        }
        
        public func connectAndDisconnect(site: Site) -> Promise<Site> {
            let promise = Promise<Site>.pending()
            // check if http path or just host and port
            guard let path = site.l7Path else {
                os_log("HTTP connect and disconnect requires l7Path", log: OSLog.default, type: .debug)
                return promise
            }
            let url = URL(string: path)
            
            //initialize urlRequest
            var urlRequest = URLRequest(url: url!)
            urlRequest.httpMethod = "HEAD"
            if site.netInterfaceType == MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR {
                urlRequest.allowsCellularAccess = true
            }
            
            let before = DispatchTime.now()
            let task = URLSession.shared.dataTask(with: urlRequest, completionHandler: { _, response, error in
                
                let after = DispatchTime.now()
                
                if error != nil {
                    os_log("Error is %@", log: OSLog.default, type: .debug, error.debugDescription)
                    promise.reject(error!)
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    os_log("Cannot get response", log: OSLog.default, type: .debug)
                    promise.reject(NetTestErrors.nilHttpResponse)
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    let elapsedTime = after.uptimeNanoseconds - before.uptimeNanoseconds
                    site.addSample(sample: Double(elapsedTime) * self.NANO_TO_MILLI) // convert to milliseconds
                    promise.fulfill(site)
                } else {
                    promise.reject(NetTestErrors.badStatusCode(code: httpResponse.statusCode))
                }
            })
            task.resume()
            return promise
        }
        
        /// Allows bind to cellular interface
        public func connectAndDisconnectSocket(site: Site) -> Promise<Site> {
            let promise = Promise<Site>.pending()
            netTestDispatchQueue!.async {
                if site.l7Path != nil {
                    os_log("Connect and disconnect socket requires host and port", log: OSLog.default, type: .debug)
                    promise.reject(NetTestErrors.invalidSite(msg: "Connect and disconnect socket requires host and port"))
                    return
                }
                
                print("NetTest: host is \(site.host), port is \(site.port)")
                
                var localIP: String?
                do {
                    try localIP = MobiledgeXiOSLibraryGrpc.NetworkInterface.getClientIP(netInterfaceType: site.netInterfaceType, localEndpoint: site.localEndpoint)
                } catch {
                    promise.reject(error)
                    return
                }
                
                print("NetTest: localip is to bind \(localIP)")
                                
                // initialize addrinfo fields
                var addrInfo = addrinfo.init()
                addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets
                
                let err = self.bindAndConnectSocket(site: site, addrInfo: &addrInfo, localIP: localIP)
                if err != nil {
                    promise.reject(err!)
                } else {
                    promise.fulfill(site)
                }
            }
            return promise
        }
        
        // Same function is in GetBSDSocketHelper (Create socket class outside of MatchingEngine?)
        private func bindAndConnectSocket(site: Site, addrInfo: UnsafeMutablePointer<addrinfo>, localIP: String?, ipfamily: Int32? = AF_UNSPEC) -> Error? {
            
            // socket returns a socket descriptor
            let s = socket(ipfamily!, addrInfo.pointee.ai_socktype, 0)  // protocol set to 0 to choose proper protocol for given socktype
            if s == -1 {
                if errno == EAFNOSUPPORT {
                    // try to find correct ip family
                    if ipfamily == AF_UNSPEC {
                        return bindAndConnectSocket(site: site, addrInfo: addrInfo, localIP: localIP, ipfamily: AF_INET)
                    } else if ipfamily == AF_INET {
                        return bindAndConnectSocket(site: site, addrInfo: addrInfo, localIP: localIP, ipfamily: AF_INET)
                    } else {
                        return MobiledgeXiOSLibraryGrpc.SystemError.noValidIpFamily
                    }
                }
                let sysError = MobiledgeXiOSLibraryGrpc.SystemError.socket(s, errno)
                os_log("Client socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return sysError
            }
            
            var clientRes: UnsafeMutablePointer<addrinfo>?
            if localIP != nil {
                // Bind to client cellular interface
                // used to store addrinfo fields like sockaddr struct, socket type, protocol, and address length
                // getaddrinfo function makes ip + port conversion to sockaddr easy
                let error = getaddrinfo(localIP, nil, addrInfo, &clientRes)
                if error != 0 {
                    let sysError = MobiledgeXiOSLibraryGrpc.SystemError.getaddrinfo(error, errno)
                    os_log("Client get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                    return sysError
                }
                
                // bind to socket
                let b = bind(s, clientRes!.pointee.ai_addr, clientRes!.pointee.ai_addrlen)
                if b == -1 {
                    let sysError = MobiledgeXiOSLibraryGrpc.SystemError.bind(b, errno)
                    os_log("Client bind error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                    return sysError
                }
            }

            // Connect to server
            var serverRes: UnsafeMutablePointer<addrinfo>!
            let serverError = getaddrinfo(site.host, String(site.port!), addrInfo, &serverRes)
            if serverError != 0 {
                let sysError = MobiledgeXiOSLibraryGrpc.SystemError.getaddrinfo(serverError, errno)
                os_log("Server get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return sysError
            }
            let serverSocket = socket(serverRes.pointee.ai_family, serverRes.pointee.ai_socktype, 0)
            if serverSocket == -1 {
                let sysError = MobiledgeXiOSLibraryGrpc.SystemError.connect(serverSocket, errno)
                os_log("Server socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return sysError
            }
            // connect our socket to the provisioned socket
            let before = DispatchTime.now()
            let c = connect(s, serverRes.pointee.ai_addr, serverRes.pointee.ai_addrlen)
            let after = DispatchTime.now()
            if c == -1 {
                if errno == EAFNOSUPPORT {
                    // try to find correct ip family
                    if ipfamily == AF_UNSPEC {
                        return bindAndConnectSocket(site: site, addrInfo: addrInfo, localIP: localIP, ipfamily: AF_INET)
                    } else if ipfamily == AF_INET {
                        return bindAndConnectSocket(site: site, addrInfo: addrInfo, localIP: localIP, ipfamily: AF_INET)
                    } else {
                        return MobiledgeXiOSLibraryGrpc.SystemError.noValidIpFamily
                    }
                }
                let sysError = MobiledgeXiOSLibraryGrpc.SystemError.connect(c, errno)
                os_log("Connection error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return sysError
            }
            
            close(s)
            close(serverSocket)
            
            let elapsedTime = after.uptimeNanoseconds - before.uptimeNanoseconds
            site.addSample(sample: Double(elapsedTime) * self.NANO_TO_MILLI) // convert to milliseconds
            return nil
        }
    }
    
    public enum NetTestErrors: Error {
        case nilHttpResponse
        case badStatusCode(code: Int)
        case invalidSite(msg: String)
        case unableToGetIpAddress(msg: String)
        case nilDuration
        
        var localizedDescription: String {
            switch self {
            case .badStatusCode(let code):
              return "Code returned is \(code)"
            case .invalidSite(let msg):
                return msg
            case .unableToGetIpAddress(let msg):
                return msg
            default:
                return ""
            }
          }
    }
}


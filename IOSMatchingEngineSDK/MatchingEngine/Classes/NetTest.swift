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
//  NetTest.swift
//

import Combine
import os.log

public class PerformanceMetrics {
    
    @available(iOS 13.0, *)
    public class Site {
    
        public var host: String?
        public var port: String?
        public var l7Path: String? // http path
        public var network: String
        public var testType: NetTest.TestType
    
        public var lastPingMs: Double?
        public var avg: Double
        public var stdDev: Double?
        
        public var samples: [Double]
        public var capacity: Int
        
        var unbiasedAvg: Double // take average to prevent imprecision
        var unbiasedSquareAvg: Double
        
        let DEFAULT_CAPACITY = 5
        
        // initialize size with host and port
        public init(network: String, host: String, port: String, testType: NetTest.TestType?, numSamples: Int?) {
            self.network = network
            self.host = host
            self.port = port
            samples = [Double]()
            avg = 0.0
            unbiasedAvg = 0.0
            unbiasedSquareAvg = 0.0
            
            self.testType = testType != nil ? testType! : NetTest.TestType.CONNECT // default
            self.capacity = numSamples != nil ? numSamples! : DEFAULT_CAPACITY
        }
        
        // initialize http site
        public init(network: String, l7Path: String, testType: NetTest.TestType?, numSamples: Int?) {
            self.network = network
            self.l7Path = l7Path
            samples = [Double]()
            avg = 0.0
            unbiasedAvg = 0.0
            unbiasedSquareAvg = 0.0
            
            self.testType = testType != nil ? testType! : NetTest.TestType.CONNECT // default
            self.capacity = numSamples != nil ? numSamples! : DEFAULT_CAPACITY
        }
        
        public func addSample(sample: Double) {
            self.lastPingMs = sample
            samples.append(sample)
            lastPingMs = sample
            
            // rolling average
            var removed: Double?
            if samples.count > capacity {
                removed = samples.remove(at: 0)
            }
            updateStats(removedVal: removed)
        }
        
        private func updateStats(removedVal: Double?) {
            updateAvg(removedVal: removedVal)
            updateStdDev(removedVal: removedVal)
        }
        
        // constant time update to average
        private func updateAvg(removedVal: Double?) {
            var sum: Double
            // check if adding to samples or replacing element in samples
            if let remove = removedVal {
                sum = avg * Double(samples.count)
                sum -= remove
            } else {
                sum = avg * Double(samples.count - 1)
            }
            sum += lastPingMs!
            self.avg = sum / Double(samples.count)
        }
        
        // constant time update to stdDev
        // Expanding the formula for standard deviation yields 3 terms:
        // 1) sum of squared samples
        // 2) sum of samples multiplied by 2*mean
        // 3) squared mean multiplied by number of samples
        // (each of these terms are divided by n-1 for an unbiased sample standard deviation)
        private func updateStdDev(removedVal: Double?) {
            
            // prevent dividing by 0, no stddev from sample size <= 1
            if (samples.count > 1) {
                
                var sum: Double
                var sumSquare: Double
                
                // samples is full, replacing oldest sample (rolling window)
                if let remove = removedVal {
                    
                    sum = unbiasedAvg * Double(samples.count - 1)
                    sum -= remove
                    sum += lastPingMs!
                    self.unbiasedAvg = sum / Double(samples.count - 1)
                    
                    sumSquare = unbiasedSquareAvg * Double(samples.count - 1)
                    sumSquare -= remove * remove
                    sumSquare += lastPingMs! * lastPingMs!
                    self.unbiasedSquareAvg = sumSquare / Double(samples.count - 1)
                
                // samples is not yet filled
                } else {
                    
                    sum = samples.count == 2 ? unbiasedAvg * Double(self.samples.count - 1) : unbiasedAvg * Double(samples.count - 2)
                    sum += lastPingMs!
                    self.unbiasedAvg = sum / Double(samples.count - 1)
                    
                    sumSquare = samples.count == 2 ? unbiasedSquareAvg * Double(samples.count - 1): unbiasedSquareAvg * Double(samples.count - 2)
                    sumSquare += lastPingMs! * lastPingMs!
                    self.unbiasedSquareAvg = sumSquare / Double(samples.count - 1)
                }
                
                let term1 = unbiasedSquareAvg
                let term2 = 2.0 * avg * unbiasedAvg
                let term3 = Double(samples.count) * avg * avg / Double(samples.count - 1)
                self.stdDev = sqrt(term1 - term2 + term3)
                
            } else {
                
                self.unbiasedAvg += lastPingMs!
                self.unbiasedSquareAvg += lastPingMs! * lastPingMs!
            }
        }
    }

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
            if site.network == NetworkInterface.CELLULAR {
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
            if site.network != NetworkInterface.WIFI {
                // default to Cellular interface unless wifi specified
                ip = NetworkInterface.getIPAddress(netInterfaceType: NetworkInterface.CELLULAR)
            } else {
                ip = NetworkInterface.getIPAddress(netInterfaceType: NetworkInterface.WIFI)
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
                let sysError = SystemError.getaddrinfo(error, errno)
                os_log("Client get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            // socket returns a socket descriptor
            let s = socket(res.pointee.ai_family, res.pointee.ai_socktype, 0)  // protocol set to 0 to choose proper protocol for given socktype
            if s == -1 {
                let sysError = SystemError.socket(s, errno)
                os_log("Client socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            // bind to socket to client cellular network interface
            let b = bind(s, res.pointee.ai_addr, res.pointee.ai_addrlen)
            if b == -1 {
                let sysError = SystemError.bind(b, errno)
                os_log("Client bind error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }

            // Connect to server
            var serverRes: UnsafeMutablePointer<addrinfo>!
            let serverError = getaddrinfo(site.host, site.port, addrInfo, &serverRes)
            if serverError != 0 {
                let sysError = SystemError.getaddrinfo(serverError, errno)
                os_log("Server get addrinfo error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            let serverSocket = socket(serverRes.pointee.ai_family, serverRes.pointee.ai_socktype, 0)
            if serverSocket == -1 {
                let sysError = SystemError.connect(serverSocket, errno)
                os_log("Server socket error is %@", log: OSLog.default, type: .debug, sysError.localizedDescription)
                return
            }
            // connect our socket to the provisioned socket
            let before = DispatchTime.now()
            let c = connect(s, serverRes.pointee.ai_addr, serverRes.pointee.ai_addrlen)
            let after = DispatchTime.now()
            if c == -1 {
                let sysError = SystemError.connect(c, errno)
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

@available(iOS 13.0, *)
extension PerformanceMetrics.Site: Equatable {
    public static func == (lhs: PerformanceMetrics.Site, rhs: PerformanceMetrics.Site) -> Bool {
        return
            lhs.l7Path == rhs.l7Path &&
            lhs.host == rhs.host &&
            lhs.port == rhs.port
    }
}

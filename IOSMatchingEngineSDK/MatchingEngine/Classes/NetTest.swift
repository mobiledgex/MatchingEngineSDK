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

public class PerformanceMetrics {
    
    public class Site {
    
        var host: String
        var port: String
        var network: String
        var L7Path: String?
    
        var lastPingMs: Double?
        var avg: Double?
        var stdDev: Double?
        
        var samples: [Double]?
        var size: Int?
    
        public init(network: String, host: String, port: String) {
            self.host = host
            self.port = port
            self.network = network
        }
    }

    public class NetTest {
        
        var netTestDispatchQueue: DispatchQueue?
        var sites: [Site]
        
        public init(sites: [Site]) {
            self.sites = sites
            netTestDispatchQueue = DispatchQueue(label: "nettest.queue", qos: .background, attributes: .concurrent, autoreleaseFrequency: .inherit, target: .global())
        }
        
        @available(iOS 13.0, *)
        // interval in milliseconds
        public func runTest(interval: Int) {
            for site in sites {
                let dispatchWorkItem = DispatchWorkItem(qos: .background, flags: .init(), block: {self.ping(site: site)})
                netTestDispatchQueue!.schedule(after: .init(.now()), interval: .milliseconds(interval), tolerance: .zero, options: .init(), {self.ping(site: site)})
            }
        }
        
        public func ping(site: Site) {
            print("hello from site: \(site.host)")
        }
        
        public func addSite(site: Site) {
            
        }
        
        public func removeSite(site: Site) {
            
        }
    }
}

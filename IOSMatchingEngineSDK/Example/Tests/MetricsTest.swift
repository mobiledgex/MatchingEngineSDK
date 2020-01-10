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

import XCTest

@testable import MatchingEngine
@testable import Promises
import Network

class MetricsTest: XCTestCase {
    
    var performanceMetrics: PerformanceMetrics!

    override func setUp() {
        super.setUp()
        performanceMetrics = PerformanceMetrics()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        super.tearDown()
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "pass")
    }
    
    @available(iOS 13.0, *)
    func testNetTest() {
        // Initialize sites
        let site1 = PerformanceMetrics.Site(network: NetworkInterface.CELLULAR, l7Path: "https://www.google.com", testType: PerformanceMetrics.NetTest.TestType.CONNECT, numSamples: 10)
        let site2 = PerformanceMetrics.Site(network: NetworkInterface.CELLULAR, host: "mextest-app-cluster.frankfurt-main.tdg.mobiledgex.net", port: "3001", testType: PerformanceMetrics.NetTest.TestType.PING, numSamples: 10)
        let site3 = PerformanceMetrics.Site(network: NetworkInterface.CELLULAR, host: "www.google.com", port: "443", testType: PerformanceMetrics.NetTest.TestType.CONNECT, numSamples: 10)
        // put sites in an array
        let sites = [site1, site2, site3]
        // Initialize NetTest and run in background
        let netTest = PerformanceMetrics.NetTest(sites: sites)
        netTest.runTest(interval: 100)
        
        sleep(10)
        
        XCTAssert(site1.avg > 0 && site1.stdDev != nil, "No data from site1")
        XCTAssert(site2.avg > 0 && site2.stdDev != nil, "No data from site2")
        XCTAssert(site3.avg > 0 && site3.stdDev != nil, "No data from site3")
    
        netTest.cancelTest()
    }
}

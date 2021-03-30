// Copyright 2018-2021 MobiledgeX, Inc. All rights and licenses reserved.
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

@testable import MobiledgeXiOSLibraryGrpc
@testable import Promises
@testable import SocketIO
import Network

class EdgeEventsTests: XCTestCase {
    
    var matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine!
    
    let dmeHost = "eu-qa.dme.mobiledgex.net"
    let dmePort: UInt16 = 50051
    
    let appName =  "automation-sdk-porttest"
    let appVers = "1.0"
    let orgName =  "MobiledgeX"
    let carrierName = "TDG"

    override func setUp() {
        super.setUp()
        matchingEngine = MobiledgeXiOSLibraryGrpc.MatchingEngine()
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

    @available(iOS 13.4, *)
    func testStartEdgeEventsConnection() {
        // on real device use: MobiledgeXiOSLibrary.MobiledgeXLocation.startLocationServices()
        var loc = DistributedMatchEngine_Loc.init()
        loc.latitude = 37.459609
        loc.longitude = -122.149349
                
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        var registerReply = DistributedMatchEngine_RegisterClientReply.init()
        let replyPromise = self.matchingEngine.registerClient(host: dmeHost, port: dmePort, request: regRequest)
        .then { reply -> Promise<DistributedMatchEngine_FindCloudletReply> in
            registerReply = reply
            let req = try self.matchingEngine.createFindCloudletRequest(
            gpsLocation: loc, carrierName: self.carrierName)
            return self.matchingEngine.findCloudlet(host: self.dmeHost, port: self.dmePort, request: req)
        }.then { fcReply -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> in
            if fcReply.status != .findFound {
                XCTAssert(false, "Bad findcloudlet. Status is \(fcReply.status)")
            }
            MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.setLastLocation(loc: loc)
            return self.matchingEngine.startEdgeEvents(host: self.dmeHost, port: self.dmePort, newFindCloudletHandler: self.handleFindCloudlet)
        }.catch { error in
            XCTAssert(false, "EdgeEventsConnection encountered error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        
        guard let status = replyPromise.value else {
            XCTAssert(false, "startedgeevents did not return a value.")
            return
        }
        XCTAssertTrue(status == .success, "EdgeEventsConnection failed")
    }
    
    func handleFindCloudlet(reply: DistributedMatchEngine_FindCloudletReply) {
        print("got new findcloudlet \(reply)")
    }
}
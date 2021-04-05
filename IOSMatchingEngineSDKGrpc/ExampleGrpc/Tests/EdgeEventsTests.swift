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

@available(iOS 13.0, *)
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
        // on real device use: MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.startLocationServices()
        var loc = DistributedMatchEngine_Loc.init()
        loc.latitude = 37.459609
        loc.longitude = -122.149349
        MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.startLocationServices()
                
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        var registerReply = DistributedMatchEngine_RegisterClientReply.init()
        let replyPromise = self.matchingEngine.registerClient(host: dmeHost, port: dmePort, request: regRequest)
        .then { reply -> Promise<DistributedMatchEngine_FindCloudletReply> in
            registerReply = reply
            let req = try self.matchingEngine.createFindCloudletRequest(
            gpsLocation: loc, carrierName: self.carrierName)
            return self.matchingEngine.findCloudlet(host: self.dmeHost, port: self.dmePort, request: req)
        }.then { fcReply -> Promise<MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus> in
            print("fcreply is \(fcReply)")
            if fcReply.status != .findFound {
                XCTAssert(false, "Bad findcloudlet. Status is \(fcReply.status)")
            }
            MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.setLastLocation(loc: loc)
            return self.matchingEngine.startEdgeEvents(host: self.dmeHost, port: self.dmePort, newFindCloudletHandler: self.handleNewFindCloudlet, config: self.matchingEngine.createDefaultEdgeEventsConfig(latencyUpdateIntervalSeconds: 30, locationUpdateIntervalSeconds: 30, latencyThresholdTriggerMs: 50))
        }.catch { error in
            XCTAssert(false, "EdgeEventsConnection encountered error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 20))
        
        guard let status = replyPromise.value else {
            XCTAssert(false, "startedgeevents did not return a value.")
            return
        }
        XCTAssertTrue(status == .success, "EdgeEventsConnection failed")
    }
    
    func handleNewFindCloudlet(status: MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsStatus, fcEvent: MobiledgeXiOSLibraryGrpc.EdgeEvents.FindCloudletEvent?) {
        switch status {
        case .success :
            guard let event = fcEvent else {
                print("nil findcloudlet event")
                return
            }
            print("got new findcloudlet \(event.newCloudlet), on event \(event.trigger)")
        case .fail(let error):
            print("error during edgeevents \(error)")
            if error as! MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError == MobiledgeXiOSLibraryGrpc.EdgeEvents.EdgeEventsError.eventTriggeredButCurrentCloudletIsBest {
                // fallback to public cloud
            }
        }
    }
}

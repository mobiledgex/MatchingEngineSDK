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

import XCTest

@testable import MobiledgeXiOSLibrary
@testable import Promises
@testable import SocketIO
import Network

class Tests: XCTestCase {
    
    let TEST = true
    
    // Use hardcoded dme host and port if TEST is true
    let dmeStageHost = "eu-stage.dme.mobiledgex.net"
    let dmePort: UInt16 = 38001
    
    var appName: String!
    var appVers: String!
    var orgName: String!
    var carrierName: String!
    var authToken: String?
    var uniqueIDType: MobiledgeXiOSLibrary.MatchingEngine.IDTypes?
    var uniqueID: String?
    var cellID: UInt32?
    var tags: [MobiledgeXiOSLibrary.MatchingEngine.Tag]?
    
    var matchingEngine: MobiledgeXiOSLibrary.MatchingEngine!
    
    func propertyAssert(propertyNameList: [String], object: [String: AnyObject]) {
        for propertyName in propertyNameList {
            guard let _ = object[propertyName] else {
                XCTAssert(false, "Object is missing required property: \(propertyName)")
                return
            }
        }
    }
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        matchingEngine = MobiledgeXiOSLibrary.MatchingEngine()
        matchingEngine.state.setUseWifiOnly(enabled: true) // for simulator tests and phones without SIM
        if TEST
        {
            appName =  "MobiledgeX SDK Demo"
            appVers = "k8s"
            orgName =  "MobiledgeX"
            carrierName = "GDDT"
            authToken = nil
            uniqueIDType = MobiledgeXiOSLibrary.MatchingEngine.IDTypes.ID_UNDEFINED
            uniqueID = matchingEngine.getUniqueID()
            cellID = 0
            tags = nil
        }
        else
        {
            // Unlikely path for testing...
            appName =  matchingEngine.getAppName()
            appVers =  matchingEngine.getAppVersion()
            orgName =  "MobiledgeX"             //   replace this with your orgName
            carrierName = matchingEngine.getCarrierName() ?? ""  // This value can change, and is observed by the MatchingEngine.
            authToken = nil // opaque developer specific String? value.
            uniqueIDType = MobiledgeXiOSLibrary.MatchingEngine.IDTypes.ID_UNDEFINED
            uniqueID = matchingEngine.getUniqueID()
            cellID = 0
            tags = nil
        }
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }
    
    func testRegisterClient() {
        let request = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName)

        // Host goes to mexdemo, not gddt. gddt is the registered name for the app.
        var replyPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.RegisterClientReply>!
        
        replyPromise = matchingEngine.registerClient(host: dmeStageHost, port: dmePort, request: request)
        .catch { error in
            XCTAssert(false, "Did not succeed registerClient. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "Register did not return a value.")
            return
        }
        print("RegisterClientReply is \(promiseValue)")

        XCTAssert(promiseValue.status == MobiledgeXiOSLibrary.MatchingEngine.ReplyStatus.RS_SUCCESS, "Register Failed.")
        
        XCTAssertNil(replyPromise.error)
        
        matchingEngine.registerClientResult(promiseValue)
    }
    
    // Test the FindCloudlet DME API
    @available(iOS 13.0, *)
    func testFindCloudletAPI() {
        let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude:  37.459609, longitude: -122.149349)
                
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName)
        
        var replyPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.FindCloudletReply>!
            replyPromise = matchingEngine.registerClient(host: dmeStageHost, port: dmePort, request: regRequest)
                .then { reply in
                    self.matchingEngine.findCloudletAPI(host: self.dmeStageHost, port: self.dmePort, request: self.matchingEngine.createFindCloudletRequest(
                        gpsLocation: loc, carrierName: self.carrierName))
                }.catch { error in
                    XCTAssert(false, "FindCloudlet encountered error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "FindCloudlet missing a return value.")
            return
        }
        print("FindCloudletReply is \(val)")

        let findCloudletReply = MobiledgeXiOSLibrary.MatchingEngine.FindCloudletReply.self
        XCTAssert(val.status == findCloudletReply.FindStatus.FIND_FOUND, "FindCloudlet failed, status: \(String(describing: val.status))")
        
        XCTAssertNil(replyPromise.error)
    }
    
    // Test FindCloudlet that call AppInstList and NetTest to find cloudlet with lowest latency
    @available(iOS 13.0, *)
    func testFindCloudlet() {
        let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude:  37.459609, longitude: -122.149349)
                
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName)
        
        var replyPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.FindCloudletReply>!
            replyPromise = matchingEngine.registerClient(host: dmeStageHost, port: dmePort, request: regRequest)
                .then { reply in
                    self.matchingEngine.findCloudlet(host: self.dmeStageHost, port: self.dmePort, request: self.matchingEngine.createFindCloudletRequest(
                        gpsLocation: loc, carrierName: self.carrierName))
                }.catch { error in
                    XCTAssert(false, "FindCloudlet encountered error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "FindCloudlet missing a return value.")
            return
        }
        print("FindCloudletReply is \(val)")

        let findCloudletReply = MobiledgeXiOSLibrary.MatchingEngine.FindCloudletReply.self
        XCTAssert(val.status == findCloudletReply.FindStatus.FIND_FOUND, "FindCloudlet failed, status: \(String(describing: val.status))")
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testVerifyLocation() {
        let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude:  37.459609, longitude: -122.149349)

        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName)
        
        var replyPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.VerifyLocationReply>!

        replyPromise = matchingEngine.registerClient(host: dmeStageHost, port: dmePort, request: regRequest)
                .then { reply in
                    self.matchingEngine.verifyLocation(host: self.dmeStageHost, port: self.dmePort, request: self.matchingEngine.createVerifyLocationRequest(
                                                        gpsLocation: loc,
                                                        carrierName: self.carrierName))
                }.catch { error in
                    XCTAssert(false, "VerifyLocationReply hit an error: \(error).")
            }

        
        XCTAssert(waitForPromises(timeout: 30))
        guard let val = replyPromise.value else {
            XCTAssert(false, "VerifyLocationReply missing a return value.")
            return
        }
        print("VerifyLocationReply is \(val)")
        
        let VerifyLocationReply = MobiledgeXiOSLibrary.MatchingEngine.VerifyLocationReply.self
        let gpsStatus = val.gps_location_status
        
        // The next value may change. Range of values are possible depending on location.
        XCTAssert(gpsStatus == VerifyLocationReply.GPSLocationStatus.LOC_VERIFIED, "VerifyLocation failed: \(gpsStatus)")
        
        XCTAssertNil(replyPromise.error, "VerifyLocation Error is set: \(String(describing: replyPromise.error))")
    }
    
    func testAppInstList() {
        let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude:  37.459609, longitude: -122.149349)
        
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName)
        
        // Host goes to mexdemo, not gddt. gddt is the registered name for the app.
        var replyPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.AppInstListReply>!

            replyPromise = matchingEngine.registerClient(host: dmeStageHost, port: dmePort, request: regRequest)
                .then { reply in
                    self.matchingEngine.getAppInstList(host: self.dmeStageHost, port: self.dmePort, request: self.matchingEngine.createGetAppInstListRequest(
                        gpsLocation: loc, carrierName: self.carrierName))
                    }.catch { error in
                        XCTAssert(false, "AppInstList hit an error: \(error).")
                    }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "AppInstList missing a return value.")
            return
        }
        print("AppInstListReply is \(val)")
        
        let AppInstListReply = MobiledgeXiOSLibrary.MatchingEngine.AppInstListReply.self
        XCTAssert(val.status == AppInstListReply.AIStatus.AI_SUCCESS, "AppInstList failed, status: \(String(describing: val.status))")
        
        // This one depends on the server for the number of cloudlets:
        if val.cloudlets.count == 0 {
            XCTAssert(false, "AppInstList: No cloudlets!")
            return
        }
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
    func createQoSPositionList(loc: MobiledgeXiOSLibrary.MatchingEngine.Loc, directionDegrees: Double, totalDistanceKm: Double, increment: Double) -> [MobiledgeXiOSLibrary.MatchingEngine.QosPosition]
    {
        var qosPositionList = [MobiledgeXiOSLibrary.MatchingEngine.QosPosition]()
        let kmPerDegreeLong = 111.32 //at Equator
        let kmPerDegreeLat = 110.57 //at Equator
        let addLongitude = (cos(directionDegrees * (.pi/180)) * increment) / kmPerDegreeLong
        let addLatitude = (sin(directionDegrees * (.pi/180)) * increment) / kmPerDegreeLat
        var i = 0.0
        var idx: Int64 = 1
        var longitude = loc.longitude ?? 0
        var latitude = loc.latitude ?? 0
        
        while i < totalDistanceKm {
            let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude: latitude, longitude: longitude)
            let qosPosition = MobiledgeXiOSLibrary.MatchingEngine.QosPosition(positionId: idx, gpsLocation: loc)
            
            qosPositionList.append(qosPosition)
            
            longitude = longitude + addLongitude
            latitude = latitude  + addLatitude
            i += increment
            idx += 1
        }
        
        return qosPositionList
    }
    
    func testGetQosPositionKpi() {
        let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude: 52.5200, longitude: 13.4050)   //Beacon
        let positions = createQoSPositionList(loc: loc,
                                              directionDegrees: 45,
                                              totalDistanceKm: 200,
                                              increment: 1)
        
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName)
        
        var replyPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.QosPositionKpiReply>!
        
            replyPromise = matchingEngine.registerClient(host: dmeStageHost, port: dmePort, request: regRequest)
                .then { reply in
                    self.matchingEngine.getQosKPIPosition(host: self.dmeStageHost, port: self.dmePort, request: self.matchingEngine.createQosKPIRequest(
                                                            requests: positions))
                } .catch { error in
                    XCTAssert(false, "Did not succeed get QOS Position KPI. Error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "Get QOS Position did not return a value.")
            return
        }
        print("QosPositionKpiReply is \(promiseValue)")
        
        let QosPositionKpiReply = MobiledgeXiOSLibrary.MatchingEngine.QosPositionKpiReply.self
        let status = promiseValue.status
        
        XCTAssert(status == MobiledgeXiOSLibrary.MatchingEngine.ReplyStatus.RS_SUCCESS, "QoSPosition failed: \(status)")
        
        XCTAssertNil(replyPromise.error, "QoSPosition Error is set: \(String(describing: replyPromise.error))")
    }
    
    func testGetLocation() {
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName)
        
        var replyPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.GetLocationReply>!
        
            replyPromise = matchingEngine.registerClient(host: dmeStageHost, port: dmePort, request: regRequest)
                .then { reply in
                    self.matchingEngine.getLocation(host: self.dmeStageHost, port: self.dmePort, request: self.matchingEngine.createGetLocationRequest(
                        carrierName: self.carrierName))
                } .catch { error in
                    XCTAssert(false, "Did not succeed getLocation. Error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetLocation did not return a value.")
            return
        }
        print("GetLocationReply is \(promiseValue)")
        
        let GetLocationReply = MobiledgeXiOSLibrary.MatchingEngine.GetLocationReply.self
        XCTAssert(promiseValue.status == GetLocationReply.LocStatus.LOC_FOUND, "GetLocation Failed.")
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testAddUsertoGroup() {
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName)
        
        var replyPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.DynamicLocGroupReply>!

            replyPromise = matchingEngine.registerClient(host: dmeStageHost, port: dmePort, request: regRequest)
                .then { reply in
                    self.matchingEngine.addUserToGroup(host: self.dmeStageHost, port: self.dmePort, request: self.matchingEngine.createDynamicLocGroupRequest())
                } .catch { error in
                    XCTAssert(false, "Did not succeed addUserToGroup. Error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "AddUserToGroup did not return a value.")
            return
        }
        print("DynamicLocGroupReply is \(promiseValue)")
        
        let DynamicLocGroupReply = MobiledgeXiOSLibrary.MatchingEngine.DynamicLocGroupReply.self
        XCTAssert(promiseValue.status == MobiledgeXiOSLibrary.MatchingEngine.ReplyStatus.RS_SUCCESS, "AddUserToGroup Failed.")
        
        XCTAssertNil(replyPromise.error)
    }
    
    @available(iOS 13.0, *)
    func testRegisterAndFindCloudlet() {
        let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude: 37.459609, longitude: -122.149349)
        let replyPromise = matchingEngine.registerAndFindCloudlet(host: dmeStageHost, port: dmePort, orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName, gpsLocation: loc)
        .catch { error in
            XCTAssert(false, "Error is \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "TestRegisterAndFindCloudlet did not return a value.")
            return
        }
    }
    
    func testGetCarrierName() {
        let carrierName = matchingEngine.getCarrierName()
        XCTAssert(carrierName == "wifi", "Incorrect carrier name \(carrierName)")
    }
    
    func testUniqueID() {
        let uuid = matchingEngine.getUniqueID()
        XCTAssert(uuid != nil, "No uuid returned")
        print("uuid is \(uuid)")
    }
}

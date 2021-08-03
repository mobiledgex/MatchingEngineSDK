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

@testable import MobiledgeXiOSLibraryGrpc
@testable import Promises
@testable import SocketIO
import Network

@available(iOS 13.0, *)
class Tests: XCTestCase {
    
    let TEST = true
    
    // Use hardcoded dme host and port if TEST is true
    let dmeHost = "eu-mexdemo.dme.mobiledgex.net"
    let dmePort: UInt16 = 50051
    
    var appName: String!
    var appVers: String!
    var orgName: String!
    var carrierName: String!
    
    var matchingEngine: MobiledgeXiOSLibraryGrpc.MatchingEngine!
    
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
        
        matchingEngine = MobiledgeXiOSLibraryGrpc.MatchingEngine()
        // matchingEngine.state.setUseWifiOnly(enabled: true) // for simulator tests and phones without SIM
        
        if TEST {
            appName =  "sdktest"
            appVers = "9.0"
            orgName =  "MobiledgeX-Samples"
            carrierName = "TDG"
        } else {
            // Unlikely path for testing...
            appName =  matchingEngine.getAppName()
            appVers =  matchingEngine.getAppVersion()
            orgName =  "MobiledgeX-Samples"             //   replace this with your orgName
            carrierName = matchingEngine.getCarrierName() ?? ""  // This value can change, and is observed by the MatchingEngine.
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
        let request = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        // Host goes to mexdemo, not tdg. tdg is the registered name for the app.
        var replyPromise: Promise<DistributedMatchEngine_RegisterClientReply>!
        
        replyPromise = matchingEngine.registerClient(host: dmeHost, port: dmePort, request: request)
        .catch { error in
            XCTAssert(false, "Did not succeed registerClient. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "Register did not return a value.")
            return
        }
        print("RegisterClientReply is \(promiseValue)")

        XCTAssert(promiseValue.status == DistributedMatchEngine_ReplyStatus.rsSuccess, "Register Failed.")
        
        XCTAssertNil(replyPromise.error)
        
        matchingEngine.registerClientResult(promiseValue)
    }
    

    // Test the FindCloudlet DME API
    func testFindCloudletProximity() {
        var loc = DistributedMatchEngine_Loc.init()
        loc.latitude = 37.459609
        loc.longitude = -122.149349
                
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        
        var replyPromise: Promise<DistributedMatchEngine_FindCloudletReply>!
            replyPromise = matchingEngine.registerClient(host: dmeHost, port: dmePort, request: regRequest)
                .then { reply in
                    let req = try self.matchingEngine.createFindCloudletRequest(
                    gpsLocation: loc, carrierName: self.carrierName)
                    return self.matchingEngine.findCloudlet(host: self.dmeHost, port: self.dmePort, request: req)
                }.catch { error in
                    XCTAssert(false, "FindCloudlet encountered error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "FindCloudlet missing a return value.")
            return
        }
        print("FindCloudletReply is \(val)")

        let findCloudletReply = DistributedMatchEngine_FindCloudletReply.self
        XCTAssert(val.status == DistributedMatchEngine_FindCloudletReply.FindStatus.findFound, "FindCloudlet failed, status: \(String(describing: val.status))")
        
        XCTAssertNil(replyPromise.error)
    }
    
    // Test FindCloudlet that call AppInstList and NetTest to find cloudlet with lowest latency
    func testFindCloudletPerformance() {
        var loc = DistributedMatchEngine_Loc.init()
        loc.latitude = 37.459609
        loc.longitude = -122.149349
        
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        
        var replyPromise: Promise<DistributedMatchEngine_FindCloudletReply>!
            replyPromise = matchingEngine.registerClient(host: dmeHost, port: dmePort, request: regRequest)
                .then { reply in
                    let req = try self.matchingEngine.createFindCloudletRequest(
                    gpsLocation: loc, carrierName: self.carrierName)
                    return self.matchingEngine.findCloudlet(host: self.dmeHost, port: self.dmePort, request: req, mode: MobiledgeXiOSLibraryGrpc.MatchingEngine.FindCloudletMode.PERFORMANCE)
                }.catch { error in
                    XCTAssert(false, "FindCloudlet encountered error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "FindCloudlet missing a return value.")
            return
        }
        let cloudletLoc = val.cloudletLocation;
        XCTAssert(cloudletLoc.longitude != 0 && cloudletLoc.latitude != 0, "Received a bad gps cloudlet_location for findCloudlet performance mode")

        print("FindCloudletReply is \(val)")

        let findCloudletReply = DistributedMatchEngine_FindCloudletReply.self
        XCTAssert(val.status == DistributedMatchEngine_FindCloudletReply.FindStatus.findFound, "FindCloudlet failed, status: \(String(describing: val.status))")
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testVerifyLocation() {
        var loc = DistributedMatchEngine_Loc.init()
        loc.latitude = 37.459609
        loc.longitude = -122.149349
        
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        
        var replyPromise: Promise<DistributedMatchEngine_VerifyLocationReply>!

        replyPromise = matchingEngine.registerClient(host: dmeHost, port: dmePort, request: regRequest)
                .then { reply in
                    let req = try self.matchingEngine.createVerifyLocationRequest(
                    gpsLocation: loc,
                    carrierName: self.carrierName)
                    return self.matchingEngine.verifyLocation(host: self.dmeHost, port: self.dmePort, request: req)
                }.catch { error in
                    XCTAssert(false, "VerifyLocationReply hit an error: \(error).")
            }

        
        XCTAssert(waitForPromises(timeout: 30))
        guard let val = replyPromise.value else {
            XCTAssert(false, "VerifyLocationReply missing a return value.")
            return
        }
        print("VerifyLocationReply is \(val)")
        
        let VerifyLocationReply = DistributedMatchEngine_VerifyLocationReply.self
        let gpsStatus = val.gpsLocationStatus
        
        // The next value may change. Range of values are possible depending on location.
        XCTAssert(gpsStatus == DistributedMatchEngine_VerifyLocationReply.GPSLocationStatus.locUnknown, "VerifyLocation failed: \(gpsStatus)")
        
        XCTAssertNil(replyPromise.error, "VerifyLocation Error is set: \(String(describing: replyPromise.error))")
    }
    
    func testAppInstList() {
        var loc = DistributedMatchEngine_Loc.init()
        loc.latitude = 37.459609
        loc.longitude = -122.149349
        
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        
        // Host goes to mexdemo, not tdg. tdg is the registered name for the app.
        var replyPromise: Promise<DistributedMatchEngine_AppInstListReply>!

            replyPromise = matchingEngine.registerClient(host: dmeHost, port: dmePort, request: regRequest)
                .then { reply in
                    let req = try self.matchingEngine.createGetAppInstListRequest(
                    gpsLocation: loc, carrierName: self.carrierName)
                    return self.matchingEngine.getAppInstList(host: self.dmeHost, port: self.dmePort, request: req)
                    }.catch { error in
                        XCTAssert(false, "AppInstList hit an error: \(error).")
                    }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "AppInstList missing a return value.")
            return
        }
        print("AppInstListReply is \(val)")
        
        let AppInstListReply = DistributedMatchEngine_AppInstListReply.self
        XCTAssert(val.status == DistributedMatchEngine_AppInstListReply.AIStatus.aiSuccess, "AppInstList failed, status: \(String(describing: val.status))")
        
        // This one depends on the server for the number of cloudlets:
        let cloudlets = val.cloudlets
        if cloudlets.count == 0 {
            XCTAssert(false, "AppInstList: No cloudlets!")
            return
        }
        
        let appinstances = cloudlets[0].appinstances
        if appinstances.count == 0 {
            XCTAssert(false, "AppInstList: No app instances")
            return
        }
        
        let appinstance = appinstances[0]
        if appinstance.appName == "" {
            XCTAssert(false, "Missing app_name in appinstance")
            return
        }
        
        if appinstance.appVers == "" {
            XCTAssert(false, "Missing app_vers in appinstance")
            return
        }
        
        if appinstance.fqdn == "" {
            XCTAssert(false, "Missing fqdn in appinstance")
            return
        }
        
        if appinstance.orgName == "" {
            XCTAssert(false, "Missing org_name in appinstance")
            return
        }
        
        if appinstance.ports.count == 0 {
            XCTAssert(false, "Missing ports in appinstance")
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
    
    func createQoSPositionList(loc: DistributedMatchEngine_Loc, directionDegrees: Double, totalDistanceKm: Double, increment: Double) -> [DistributedMatchEngine_QosPosition]
    {
        var qosPositionList = [DistributedMatchEngine_QosPosition]()
        let kmPerDegreeLong = 111.32 //at Equator
        let kmPerDegreeLat = 110.57 //at Equator
        let addLongitude = (cos(directionDegrees * (.pi/180)) * increment) / kmPerDegreeLong
        let addLatitude = (sin(directionDegrees * (.pi/180)) * increment) / kmPerDegreeLat
        var i = 0.0
        var idx: Int64 = 1
        var longitude = loc.longitude
        var latitude = loc.latitude
        
        while i < totalDistanceKm {
        
            var loc = DistributedMatchEngine_Loc.init()
            loc.latitude = latitude
            loc.longitude = longitude
            var qosPosition = DistributedMatchEngine_QosPosition.init()
            qosPosition.positionid = idx
            qosPosition.gpsLocation = loc
            
            qosPositionList.append(qosPosition)
            
            longitude = longitude + addLongitude
            latitude = latitude  + addLatitude
            i += increment
            idx += 1
        }
        
        return qosPositionList
    }
    
    func testGetQosPositionKpi() {
        var loc = DistributedMatchEngine_Loc.init()
        loc.latitude = 52.5200
        loc.longitude = 13.4050   //Berlin
        
        let positions = createQoSPositionList(loc: loc,
                                              directionDegrees: 45,
                                              totalDistanceKm: 200,
                                              increment: 1)
        
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        
        var replyPromise: Promise<DistributedMatchEngine_QosPositionKpiReply>!
        
            replyPromise = matchingEngine.registerClient(host: dmeHost, port: dmePort, request: regRequest)
                .then { reply in
                    let req = try self.matchingEngine.createQosKPIRequest(
                    requests: positions)
                    return self.matchingEngine.getQosKPIPosition(host: self.dmeHost, port: self.dmePort, request: req)
                } .catch { error in
                    XCTAssert(false, "Did not succeed get QOS Position KPI. Error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "Get QOS Position did not return a value.")
            return
        }
        print("QosPositionKpiReply is \(promiseValue)")
        
        let QosPositionKpiReply = DistributedMatchEngine_QosPositionKpiReply.self
        let status = promiseValue.status
        
        XCTAssert(status == DistributedMatchEngine_ReplyStatus.rsSuccess, "QoSPosition failed: \(status)")
        
        XCTAssertNil(replyPromise.error, "QoSPosition Error is set: \(String(describing: replyPromise.error))")
    }
    
    func testAddUsertoGroup() {
        let regRequest = matchingEngine.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers)
        
        var replyPromise: Promise<DistributedMatchEngine_DynamicLocGroupReply>!

            replyPromise = matchingEngine.registerClient(host: dmeHost, port: dmePort, request: regRequest)
                .then { reply in
                    let req = try self.matchingEngine.createDynamicLocGroupRequest()
                    return self.matchingEngine.addUserToGroup(host: self.dmeHost, port: self.dmePort, request: req)
                } .catch { error in
                    XCTAssert(false, "Did not succeed addUserToGroup. Error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "AddUserToGroup did not return a value.")
            return
        }
        print("DynamicLocGroupReply is \(promiseValue)")
        
        let DynamicLocGroupReply = DistributedMatchEngine_DynamicLocGroupReply.self
        XCTAssert(promiseValue.status == DistributedMatchEngine_ReplyStatus.rsSuccess, "AddUserToGroup Failed.")
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testRegisterAndFindCloudlet() {
        var loc = DistributedMatchEngine_Loc.init()
        loc.latitude = 37.459609
        loc.longitude = -122.149349
        
        let replyPromise = matchingEngine.registerAndFindCloudlet(host: dmeHost, port: dmePort, orgName: orgName, appName: appName, appVers: appVers, gpsLocation: loc, carrierName: carrierName)
        .catch { error in
            XCTAssert(false, "Error is \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let val = replyPromise.value else {
            XCTAssert(false, "TestRegisterAndFindCloudlet did not return a value.")
            return
        }
        print("FindCloudletReply is \(val)")

        let findCloudletReply = DistributedMatchEngine_FindCloudletReply.self
        XCTAssert(val.status == DistributedMatchEngine_FindCloudletReply.FindStatus.findFound, "FindCloudlet failed, status: \(String(describing: val.status))")
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testGetCarrierName() {
        let carrierName = matchingEngine.getCarrierName()
        XCTAssert(carrierName == "26201", "Incorrect carrier name \(carrierName)") // depends on device
    }
    
    func testUniqueID() {
        let uuid = matchingEngine.getUniqueID()
        XCTAssert(uuid != nil, "No uuid returned")
        print("uuid is \(uuid)")
    }
    
    func testLocationServices() {
        let startLocationPromise = MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.startLocationServices()
        .then { success in
            let country = MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.getLastISOCountryCode()
            print("country code is \(country)")
            print("lastLocation is \(MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.getLastLocation())")
        }.catch { error in
            XCTAssert(false, "Error in location services test \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let successStartLocation = startLocationPromise.value else {
            XCTAssert(false, "TestLocationServices did not return a value.")
            return
        }
        
        XCTAssert(successStartLocation)
        MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.stopLocationServices()
    }
    
    func testIsRoaming() {
        let roamingPromise = MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.startLocationServices()
        .then { success -> Bool in
            let roaming = try MobiledgeXiOSLibraryGrpc.NetworkInterface.isRoaming()
            return roaming
        }.catch { error in
            XCTAssert(false, "Error in isRoaming test \(error)")
        }
            
        XCTAssert(waitForPromises(timeout: 5))
        guard let isRoaming = roamingPromise.value else {
            XCTAssert(false, "isRoaming did not return a value.")
            return
        }
        XCTAssert(isRoaming)
        MobiledgeXiOSLibraryGrpc.MobiledgeXLocation.stopLocationServices()
    }
}

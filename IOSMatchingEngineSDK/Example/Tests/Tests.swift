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

import XCTest

@testable import MobiledgeXiOSLibrary
@testable import Promises
@testable import SocketIO
import Network

class Tests: XCTestCase {
    
    let TEST = true
    
    var host = ""
    var port: UInt = 38001
    var appName: String!
    var appVers: String!
    var devName: String!
    var carrierName: String!
    var authToken: String?
    var uniqueIDType: String?
    var uniqueID: String?
    var cellID: UInt32?
    var tags: [[String: String]]?
    
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
            port = MobiledgeXiOSLibrary.MatchingEngine.DMEConstants.dmeRestPort
            appName =  "MobiledgeX SDK Demo"
            appVers = "1.0"
            devName =  "MobiledgeX"
            carrierName = "TDG"
            authToken = nil
            uniqueIDType = nil
            uniqueID = matchingEngine.getUniqueID()
            cellID = nil
            tags = nil
        }
        else
        {
            // Unlikely path for testing...
            appName =  matchingEngine.getAppName()
            appVers =  matchingEngine.getAppVersion()
            devName =  "MobiledgeX"             //   replace this with your devName
            carrierName = matchingEngine.getCarrierName() ?? ""  // This value can change, and is observed by the MatchingEngine.
            authToken = nil // opaque developer specific String? value.
            uniqueIDType = nil
            uniqueID = matchingEngine.getUniqueID()
            cellID = nil
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
        let request = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)

        // Host goes to mexdemo, not tdg. tdg is the registered name for the app.
        var replyPromise: Promise<[String: AnyObject]>!
        replyPromise = matchingEngine.registerClient(request: request)
        .catch { error in
            XCTAssert(false, "Did not succeed registerClient. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "Register did not return a value.")
            return
        }
        
        let RegisterClientReply = MobiledgeXiOSLibrary.MatchingEngine.RegisterClientReply.self
        XCTAssert(promiseValue[RegisterClientReply.status] as? String ?? "" == MobiledgeXiOSLibrary.MatchingEngine.ReplyStatus.RS_SUCCESS, "Register Failed.")
        
        XCTAssertNil(replyPromise.error)
        
        matchingEngine.registerClientResult(promiseValue)
    }
    
    func testFindCloudlet() {
        let loc = [ "longitude": -122.149349, "latitude": 37.459609]
        
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        // Host goes to mexdemo, not tdg. tdg is the registered name for the app.
        var replyPromise: Promise<[String: AnyObject]>!
            replyPromise = matchingEngine.registerClient(request: regRequest)
                .then { reply in
                    self.matchingEngine.findCloudlet(request: self.matchingEngine.createFindCloudletRequest(
                                                        carrierName: nil,
                                                        gpsLocation: loc,
                                                        devName: self.devName,
                                                        appName: self.appName,
                                                        appVers: self.appVers,
                                                        cellID: self.cellID,
                                                        tags: self.tags))
                }.catch { error in
                    XCTAssert(false, "FindCloudlet encountered error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "FindCloudlet missing a return value.")
            return
        }
        
        let FindCloudletReply = MobiledgeXiOSLibrary.MatchingEngine.FindCloudletReply.self
        XCTAssert(val[FindCloudletReply.status] as? String ?? "" == FindCloudletReply.FindStatus.FIND_FOUND, "FindCloudlet failed, status: \(String(describing: val[FindCloudletReply.status]))")
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testVerifyLocation() {
        let loc = [ "longitude": -122.149349, "latitude": 37.459609]
        
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        var replyPromise: Promise<[String: AnyObject]>!

            replyPromise = matchingEngine.registerClient(request: regRequest)
                .then { reply in
                    self.matchingEngine.verifyLocation(request: self.matchingEngine.createVerifyLocationRequest(
                                                        carrierName: nil,
                                                        gpsLocation: loc,
                                                        cellID: self.cellID,
                                                        tags: self.tags))
                }.catch { error in
                    XCTAssert(false, "VerifyLocationReply hit an error: \(error).")
            }

        
        XCTAssert(waitForPromises(timeout: 20))
        guard let val = replyPromise.value else {
            XCTAssert(false, "VerifyLocationReply missing a return value.")
            return
        }
        
        let VerifyLocationReply = MobiledgeXiOSLibrary.MatchingEngine.VerifyLocationReply.self
        let gpsStatus = val[VerifyLocationReply.gps_location_status] as? String ?? ""
        
        // The next value may change. Range of values are possible depending on location.
        XCTAssert(gpsStatus == VerifyLocationReply.GPSLocationStatus.LOC_VERIFIED, "VerifyLocation failed: \(gpsStatus)")
        
        XCTAssertNil(replyPromise.error, "VerifyLocation Error is set: \(String(describing: replyPromise.error))")
    }
    
    func testAppInstList() {
        let loc = [ "longitude": -122.149349, "latitude": 37.459609]
        
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        // Host goes to mexdemo, not tdg. tdg is the registered name for the app.
        var replyPromise: Promise<[String: AnyObject]>!

            replyPromise = matchingEngine.registerClient(request: regRequest)
                .then { reply in
                    self.matchingEngine.getAppInstList(request: self.matchingEngine.createGetAppInstListRequest(
                                                        carrierName: nil,
                                                        gpsLocation: loc,
                                                        cellID: self.cellID,
                                                        tags: self.tags))
                    }.catch { error in
                        XCTAssert(false, "AppInstList hit an error: \(error).")
                    }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "AppInstList missing a return value.")
            return
        }
        
        let AppInstListReply = MobiledgeXiOSLibrary.MatchingEngine.AppInstListReply.self
        XCTAssert(val[AppInstListReply.status] as? String ?? "" == AppInstListReply.AIStatus.AI_SUCCESS, "AppInstList failed, status: \(String(describing: val[AppInstListReply.status]))")
        
        // This one depends on the server for the number of cloudlets:
        guard let cloudlets = val[AppInstListReply.cloudlets] as? [[String: AnyObject]] else {
            XCTAssert(false, "AppInstList: No cloudlets!")
            return
        }
        
        // Basic assertions:
        let propertyNameList = ["carrier_name", "cloudlet_name", "gps_location", "distance", "appinstances"]
        for cloudlet in cloudlets {
            propertyAssert(propertyNameList: propertyNameList, object: cloudlet)
        }
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
    func createQoSPositionList(loc: [String: Any], directionDegrees: Double, totalDistanceKm: Double, increment: Double) -> [[String: Any]]
    {
        var qosPositionList = [[String: Any]]()
        let kmPerDegreeLong = 111.32 //at Equator
        let kmPerDegreeLat = 110.57 //at Equator
        let addLongitude = (cos(directionDegrees * (.pi/180)) * increment) / kmPerDegreeLong
        let addLatitude = (sin(directionDegrees * (.pi/180)) * increment) / kmPerDegreeLat
        var i = 0.0;
        let Loc = MobiledgeXiOSLibrary.MatchingEngine.Loc.self
        var longitude = loc[Loc.longitude] ?? 0
        var latitude = loc[Loc.latitude] ?? 0
        
        while i < totalDistanceKm {
            let loc = [Loc.longitude: longitude, Loc.latitude: latitude]
            
            qosPositionList.append(loc)
            
            longitude = longitude as! Double + addLongitude
            latitude = latitude as! Double + addLatitude
            i += increment
        }
        
        return qosPositionList
    }
    
    func testGetQosPositionKpi() {
        let loc = [ "longitude": 13.4050, "latitude": 52.5200]   //Berlin
        let positions = createQoSPositionList(loc: loc,
                                              directionDegrees: 45,
                                              totalDistanceKm: 200,
                                              increment: 1)
        
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        var replyPromise: Promise<[String: AnyObject]>!
        
            replyPromise = matchingEngine.registerClient(request: regRequest)
                .then { reply in
                    self.matchingEngine.getQosKPIPosition(request: self.matchingEngine.createQosKPIRequest(
                                                            requests: positions,
                                                            lte_category: nil,
                                                            band_selection: nil,
                                                            cellID: self.cellID,
                                                            tags: self.tags))
                } .catch { error in
                    XCTAssert(false, "Did not succeed get QOS Position KPI. Error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "Get QOS Position did not return a value.")
            return
        }
        
        let QosPositionKpiReply = MobiledgeXiOSLibrary.MatchingEngine.QosPositionKpiReply.self
        let status = promiseValue[QosPositionKpiReply.status] as? String ?? ""
        
        XCTAssert(status != MobiledgeXiOSLibrary.MatchingEngine.ReplyStatus.RS_SUCCESS, "QoSPosition failed: \(status)")
        
        XCTAssertNil(replyPromise.error, "QoSPosition Error is set: \(String(describing: replyPromise.error))")
    }
    
    func testGetLocation() {
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        var replyPromise: Promise<[String: AnyObject]>!
        
            replyPromise = matchingEngine.registerClient(request: regRequest)
                .then { reply in
                    self.matchingEngine.getLocation(request: self.matchingEngine.createGetLocationRequest(
                        carrierName: nil, cellID: self.cellID, tags: self.tags))
                } .catch { error in
                    XCTAssert(false, "Did not succeed getLocation. Error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetLocation did not return a value.")
            return
        }
        
        let GetLocationReply = MobiledgeXiOSLibrary.MatchingEngine.GetLocationReply.self
        XCTAssert(promiseValue[GetLocationReply.status] as? String ?? "" == GetLocationReply.LocStatus.LOC_FOUND, "GetLocation Failed.")
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testAddUsertoGroup() {
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        var replyPromise: Promise<[String: AnyObject]>!

            replyPromise = matchingEngine.registerClient(request: regRequest)
                .then { reply in
                    self.matchingEngine.addUserToGroup(request: self.matchingEngine.createDynamicLocGroupRequest(lg_id: nil, commType: nil, userData: nil, cellID: self.cellID, tags: self.tags))
                } .catch { error in
                    XCTAssert(false, "Did not succeed addUserToGroup. Error: \(error)")
            }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "AddUserToGroup did not return a value.")
            return
        }
        
        let DynamicLocGroupReply = MobiledgeXiOSLibrary.MatchingEngine.DynamicLocGroupReply.self
        XCTAssert(promiseValue[DynamicLocGroupReply.status] as? String ?? "" == MobiledgeXiOSLibrary.MatchingEngine.ReplyStatus.RS_SUCCESS, "AddUserToGroup Failed.")
        
        XCTAssertNil(replyPromise.error)
    }
    
    func testRegisterAndFindCloudlet() {
        let loc = [ "longitude": -122.149349, "latitude": 37.459609]
        let replyPromise = matchingEngine.registerAndFindCloudlet(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, gpsLocation: loc, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        .catch { error in
            XCTAssert(false, "Error is \(error.localizedDescription)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "TestRegisterAndFindCloudlet did not return a value.")
            return
        }
    }
    
    func testGetCarrierName() {
        let carrierName = matchingEngine.getCarrierName()
        XCTAssert(carrierName == "26201", "Incorrect carrier name \(carrierName)")
    }
    
    func testUniqueID() {
        let uuid = matchingEngine.getUniqueID()
        print("uuid is \(uuid)")
    }
}

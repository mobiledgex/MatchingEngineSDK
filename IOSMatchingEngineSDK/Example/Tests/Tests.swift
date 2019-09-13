import XCTest

@testable import MatchingEngine
@testable import Promises

class Tests: XCTestCase {
    
    let TEST = true
    var host = ""
    var port: UInt = 38001
    var appName: String!
    var appVers: String!
    var devName: String!
    var carrierName: String!
    var authToken: String?
    var matchingEngine: MatchingEngine!
    
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
        
        matchingEngine = MatchingEngine()
        if TEST
        {
            host = MexUtil.shared.generateDmeHost(carrierName: "mexdemo")
            port = matchingEngine.getDefaultDmePort()
            appName =  "MobiledgeX SDK Demo"
            appVers = "1.0"
            devName =  "MobiledgeX"
            carrierName = "tdg"
            authToken = nil
        }
        else
        {
            // Unlikely path for testing...
            appName =  matchingEngine.getAppName()
            appVers =  matchingEngine.getAppVersion()
            devName =  "MobiledgeX"             //   replace this with your devName
            carrierName = matchingEngine.getCarrierName() ?? ""  // This value can change, and is observed by the MatchingEngine.
            authToken = nil // opaque developer specific String? value.
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
        let request = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: nil)
        
        // Host goes to mexdemo, not tdg. tdg is the registered name for the app.
        let replyPromise = matchingEngine.registerClient(host: host, port: port, request: request)
            .catch { error in
                XCTAssert(false, "Did not succeed registerClient. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "Register did not return a value.")
            return
        }
        XCTAssert(promiseValue["status"] as? String ?? "" == "RS_SUCCESS", "Register Failed.")
        XCTAssertNil(replyPromise.error)
        matchingEngine.registerClientResult(promiseValue)
    }
    
    func testFindCloudlet() {
        let loc = [ "longitude": -122.149349, "latitude": 37.459609]
        
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: nil)
        
        // Host goes to mexdemo, not tdg. tdg is the registered name for the app.
        let replyPromise = matchingEngine.registerClient(host: host, port: port, request: regRequest)
            .then { reply in
                self.matchingEngine.findCloudlet(host: self.host, port: self.port,
                                                 request: self.matchingEngine.createFindCloudletRequest(
                                                    carrierName: self.carrierName,
                                                    gpsLocation: loc,
                                                    devName: self.devName,
                                                    appName: self.appName,
                                                    appVers: self.appVers))
            }.catch { error in
                XCTAssert(false, "FindCloudlet encountered error: \(error)")
        }
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "FindCloudlet missing a return value.")
            return
        }
        XCTAssert(val["status"] as? String ?? "" == "FIND_FOUND", "FindCloudlet failed, status: \(String(describing: val["status"]))")
        XCTAssertNil(replyPromise.error)
    }
    
    func testVerfiyLocation() {
        let loc = [ "longitude": -122.149349, "latitude": 37.459609]
        
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: nil)
        
        let replyPromise = matchingEngine.registerClient(host: host, port: port, request: regRequest)
            .then { reply in
                self.matchingEngine.verifyLocation(host: self.host, port: self.port,
                                                   request: self.matchingEngine.createVerifyLocationRequest(
                                                    carrierName: self.carrierName, // Test override values
                                                    gpsLocation: loc))
            }.catch { error in
                XCTAssert(false, "VerifyLocationReply hit an error: \(error).")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "VerifyLocationReply missing a return value.")
            return
        }
        let gpsStatus = val["gps_location_status"] as? String ?? ""
        // The next value may change. Range of values are possible depending on location.
        XCTAssert(gpsStatus == "LOC_ROAMING_COUNTRY_MATCH", "VerifyLocation failed: \(gpsStatus)")
        XCTAssertNil(replyPromise.error, "VerifyLocation Error is set: \(String(describing: replyPromise.error))")
    }
    
    func testAppInstList() {
        let loc = [ "longitude": -122.149349, "latitude": 37.459609]
        
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: nil)
        
        // Host goes to mexdemo, not tdg. tdg is the registered name for the app.
        let replyPromise = matchingEngine.registerClient(host: host, port: port, request: regRequest)
            .then { reply in
                self.matchingEngine.getAppInstList(host: self.host, port: self.port,
                                                   request: self.matchingEngine.createGetAppInstListRequest(
                                                    carrierName: self.carrierName,
                                                    gpsLocation: loc))
        }
        XCTAssert(waitForPromises(timeout: 10))
        guard let val = replyPromise.value else {
            XCTAssert(false, "AppInstList missing a return value.")
            return
        }
        XCTAssert(val["status"] as? String ?? "" == "AI_SUCCESS", "AppInstList failed, status: \(String(describing: val["status"]))")
        // This one depends on the server for the number of cloudlets:
        guard let cloudlets = val["cloudlets"] as? [[String: AnyObject]] else {
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
        let addLongitude = (cos(directionDegrees) * increment) / kmPerDegreeLong
        let addLatitude = (sin(directionDegrees) * increment) / kmPerDegreeLat
        var i = 0.0;
        var longitude = loc["longitude"] ?? 0
        var latitude = loc["latitude"] ?? 0
        
        while i < totalDistanceKm {
            let loc = [ "longitude": longitude, "latitude": latitude]
            
            qosPositionList.append(loc)
            
            longitude = longitude as! Double + addLongitude
            latitude = latitude as! Double + addLatitude
            i += increment
        }
        
        return qosPositionList
    }
    
    func testGetQosPositionKpi() {
        let loc = [ "longitude": -122.149349, "latitude": 37.459609]
        let positions = createQoSPositionList(loc: loc,
                                              directionDegrees: 45,
                                              totalDistanceKm: 200,
                                              increment: 1)
        
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: nil)
        
        let replyPromise = matchingEngine.registerClient(host: host, port: port, request: regRequest)
            .then { reply in
                self.matchingEngine.getQosKPIPosition(host: self.host,
                                                      port: self.port,
                                                      request: self.matchingEngine.createQosKPIRequest(requests: positions, lte_category: nil, band_selection: nil))
            } .catch { error in
                XCTAssert(false, "Did not succeed get QOS Position KPI. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "Get QOS Position did not return a value.")
            return
        }
        
        let status = promiseValue["status"] as? String ?? ""
        XCTAssert(status != "RS_SUCCESS", "QoSPosition failed: \(status)")
        XCTAssertNil(replyPromise.error, "QoSPosition Error is set: \(String(describing: replyPromise.error))")
    }
    
    func testGetLocation() {
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: nil)
        
        let replyPromise = matchingEngine.registerClient(host: host, port: port, request: regRequest)
            .then { reply in
                self.matchingEngine.getLocation(host: self.host,
                                                port: self.port,
                                                request: self.matchingEngine.createGetLocationRequest(carrierName: self.carrierName))
            } .catch { error in
                XCTAssert(false, "Did not succeed getLocation. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetLocation did not return a value.")
            return
        }
        XCTAssert(promiseValue["status"] as? String ?? "" == "LOC_FOUND", "GetLocation Failed.")
        XCTAssertNil(replyPromise.error)
    }
    
    func testAddUsertoGroup() {
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: nil)
        
        let replyPromise = matchingEngine.registerClient(host: host, port: port, request: regRequest)
            .then { reply in
                self.matchingEngine.addUserToGroup(host: self.host,
                                                   port: self.port,
                                                   request: self.matchingEngine.createDynamicLocGroupRequest(commType: nil, userData: nil))
            } .catch { error in
                XCTAssert(false, "Did not succeed addUserToGroup. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "AddUserToGroup did not return a value.")
            return
        }
        XCTAssert(promiseValue["status"] as? String ?? "" == "RS_SUCCESS", "AddUserToGroup Failed.")
        XCTAssertNil(replyPromise.error)
    }
    
    func testGetConnection() {
        let loc = ["longitude": -122.149349, "latitude": 37.459609]
        let regRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: nil)
        
        let replyPromise = matchingEngine.registerClient(host: host, port: port, request: regRequest)
            .then { reply in
                self.matchingEngine.findCloudlet(host: self.host, port: self.port,
                                                 request: self.matchingEngine.createFindCloudletRequest(carrierName: self.carrierName, gpsLocation: loc, devName: self.devName, appName: self.appName, appVers: self.appVers))
                    .then { reply in
                        self.matchingEngine.getConnection(netInterfaceType: "pdp_ip0", findCloudletReply: reply, ports: nil, proto: "TCP")
                }
        }
        
        XCTAssert(waitForPromises(timeout: 20))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetConnection did not return a value.")
            return
        }
        Swift.print("promiseValue is \(promiseValue)")
    }
}

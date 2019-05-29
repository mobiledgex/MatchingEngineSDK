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
        XCTAssert(replyPromise.value!["Status"] as? String ?? "" == "RS_SUCCESS", "Register was a success")
        XCTAssertNil(replyPromise.error)
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
                                                    appVers: "1.0"))
        }
        
        XCTAssert(waitForPromises(timeout: 10))
        let val = replyPromise.value!
        XCTAssert(val["status"] as? String ?? "" == "FIND_FOUND", "FindCloudlet was a success")
        XCTAssertNil(replyPromise.error)
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure() {
            // Put the code you want to measure the time of here.
        }
    }
    
}

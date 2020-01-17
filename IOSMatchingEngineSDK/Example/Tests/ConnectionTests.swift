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

class ConnectionTests: XCTestCase {
    
    var matchingEngine: MobiledgeXiOSLibrary.MatchingEngine!
    var connection: NWConnection!
    let queue = DispatchQueue.global(qos: .background)
    
    enum TestError: Error {
        case runtimeError(String)
    }

    override func setUp() {
        super.setUp()
        matchingEngine = MobiledgeXiOSLibrary.MatchingEngine()
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
    
    func testIsCellular() {
        let hasCellular = MobiledgeXiOSLibrary.NetworkInterface.hasCellularInterface()
        if !hasCellular {
            XCTAssert(false, "Failed")
        }
    }
    
    func testIsWifi() {
        let wifiOn = true // tester specifies this
        let hasWifi = MobiledgeXiOSLibrary.NetworkInterface.hasWifiInterface()
        if hasWifi != wifiOn {
            XCTAssert(false, "Failed")
        }
    }
    
    // Helper function for NWConnection send data
    private func sendData(data: String) {
        self.connection.send(content: Data(data.utf8), completion: .contentProcessed { (sendError) in
            print("NWConnection sendError is \(sendError)")
        })
    }
    
    // Helper function for NWConnection receive data
    private func receiveData() {
        self.connection.receiveMessage { (data, context, isComplete, error) in
            print("data received by NWConnection is \(data)")
        }
    }
    
    // Helper function to set up NWConnection path and state handlers
    private func connectWithNWConnection() {
        // Implement Path UpdateHandler
        connection.pathUpdateHandler = { path in
            if path.status == .satisfied {
                return
            } else {
                self.connection.restart()
            }
        }
        // Implement State UpdateHandler
        connection.stateUpdateHandler = { (newState) in
            switch newState {
            case .ready:
                print("ready")
            case .failed(let error):
                self.connection.restart()
            case .cancelled:
                self.connection.restart()
            case .preparing:
                self.connection.restart()
            default:
                self.connection.restart()
                break
            }
        }
    }
    
    // Helper function to check NWConnection State and and Path State
    private func checkPathAndState() -> Promise<Bool> {
        let promiseInputs: Promise<Bool> = Promise<Bool>.pending()
        // Real app would time this out
        while(connection.currentPath == nil || connection.state != .ready) {
            print("currentPath is \(connection.currentPath) and currentState is \(connection.state)")
        }
        // If Path is satisfied and state is ready, connection has been made
        self.sendData(data: "test")
        self.receiveData()
        promiseInputs.fulfill(true)
        return promiseInputs
    }
    
    // test this against google
    @available(iOS 13.0, *)
    func testTCPTLSConnection() {
        let host = "google.com"
        let port = "443"
        // Bool states if Path is Satisfied and State is Ready -> successful connection
        var replyPromise = matchingEngine.getTCPTLSConnection(host: host, port: port, timeout: 5)

        .then { c -> Promise<Bool> in
            let promiseInputs: Promise<Bool> = Promise<Bool>.pending()
            self.connection = c
            promiseInputs.fulfill(true)
            return promiseInputs
            
        }.catch { error in
            print("Did not succeed registerAndFindTCPConnection. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetTCPConnection did not return a value.")
            return
        }
        
        if promiseValue == false {
            XCTAssert(false, "path and state not ready")
        }
    }
    
    func testBSDTCPConnection() {
        let host = "mextest-app-cluster.fairview-main.gddt.mobiledgex.net"
        let port = "3001"
        
        var replyPromise: Promise<Socket>!
        replyPromise = matchingEngine.getBSDTCPConnection(host: host, port: port)
            
        .then { socket in
            let string = try self.readAndWriteBSDSocket(socket: socket)
            // make sure to close socket on completion and errors
            close(socket.sockfd)
            if !string.contains("Data") {
                XCTAssert(false, "Echoed data is not correct")
                throw TestError.runtimeError("Echoed data is not correct")
            }
            
        }.catch { error in
            print("error is \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetTCPConnection did not return a value.")
            return
        }
    }
    
    func testWebsocketConnection() {
        var socket: SocketIOClient!
        var manager: SocketManager!
        
        let host = "iostestcluster.fairview-main.gddt.mobiledgex.net"
        let port = "6668"
        var connected = false
        
        let replyPromise = matchingEngine.getWebsocketConnection(host: host, port: port)
            
        .then { m in
            manager = m
            socket = manager.defaultSocket
            socket.on(clientEvent: .connect) { data, ack in
                connected = true
            }
            socket.connect()
            socket.disconnect()
            
        }.catch { error in
            print("Did not succeed WebsocketConnection. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetWebsocketConnection did not return a value.")
            return
        }
        if !connected {
            XCTAssert(false, "never connected")
        }
    }
    
    func testHTTPConnection() {
        var urlRequest: URLRequest!
        
        let host = "mextest-app-cluster.fairview-main.gddt.mobiledgex.net"
        let port = "3001"
        let uri = "http://" + host + ":" + port
        let url = URL(string: uri)
        
        let replyPromise = matchingEngine.getHTTPClient(url: url!)
            
        .then { request -> Promise<URLResponse> in
            let promiseInputs: Promise<URLResponse> = Promise<URLResponse>.pending()
            // Initialize HTTP request
            urlRequest = request
            let testString = "test string"
            let testDict: [String: String] = ["Data": testString]
            let jsonRequest = try JSONSerialization.data(withJSONObject: testDict)
            urlRequest.httpBody = jsonRequest
            urlRequest.httpMethod = "POST"
            
            //send request via URLSession API
            let task = URLSession.shared.dataTask(with: urlRequest as URLRequest, completionHandler: { data, response, error in
                if (error != nil) {
                    XCTAssert(false, "Error in response: \(error)")
                    return
                }
                if response == nil {
                    XCTAssert(false, "No response")
                }
                guard let data = data else {
                    XCTAssert(false, "Nothing echoed")
                    return
                }
                do {
                    // Converts json object to a Swift [String: String]? object
                    let d = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : String]
                    // Make sure echo is correct
                    guard let value = d!["Data"] else {
                        XCTAssert(false, "Can't access response")
                        return
                    }
                    if value != testString {
                        XCTAssert(false, "Value is not correct")
                    }
                    promiseInputs.fulfill(response!)
                } catch {
                    XCTAssert(false, "unable to deserialize json \(error.localizedDescription)")
                    return
                }
            })
            task.resume()
            return(promiseInputs)
            
        }.catch { error in
            print("Did not succeed getHTTPConnection. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetHTTPConnection did not return a value.")
            return
        }
    }
    
    // Test the developer workflow: RegisterAndFindCloudlet() -> Pick App Port -> GetConnection()
    func testGetConnectionWorkflow() {
        let loc = ["longitude": -122.149349, "latitude": 37.459609]
        
        let replyPromise = matchingEngine.registerAndFindCloudlet(devName: "MobiledgeX", appName: "HttpEcho", appVers: "20191204", carrierName: nil, authToken: nil, gpsLocation: loc, uniqueIDType: nil, uniqueID: nil, cellID: nil, tags: nil)
            
        .then { findCloudletReply -> Promise<Socket> in
            // Get Dictionary: key -> internal port, value -> AppPort Dictionary
            guard let appPortsDict = self.matchingEngine.getTCPAppPorts(findCloudletReply: findCloudletReply) else {
                XCTAssert(false, "GetTCPPorts returned nil")
                throw TestError.runtimeError("GetTCPPorts returned nil")
            }
            if appPortsDict.capacity == 0 {
                XCTAssert(false, "No AppPorts in dictionary")
                throw TestError.runtimeError("No AppPorts in dictionary")
            }
            // Select AppPort Dictionary corresponding to internal port 3001
            guard let appPort = appPortsDict["3001"] else {
                XCTAssert(false, "No app ports with specified internal port")
                throw TestError.runtimeError("No app ports with specified internal port")
            }
            
            return self.matchingEngine.getBSDTCPConnection(findCloudletReply: findCloudletReply, appPort: appPort, desiredPort: "3001", timeout: 5000)
            
        }.then { socket in
            let string = try self.readAndWriteBSDSocket(socket: socket)
            close(socket.sockfd)
            if !string.contains("Data") {
                XCTAssert(false, "Echoed data is not correct")
                throw TestError.runtimeError("Echoed data is not correct")
            }
            
        }.catch { error in
            XCTAssert(false, "Error is \(error.localizedDescription)")
        }
        
        XCTAssert(waitForPromises(timeout: 5))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "TestGetConnection workflow did not return a value.")
            return
        }
    }
    
    // Helper function for reading the writing data for Socket struct
    private func readAndWriteBSDSocket(socket: Socket) throws -> String {
        // returns Socket struct with fields: file descriptor and addrinfo struct
        let sockfd = socket.sockfd
        let addrInfo = socket.addrInfo
        
        // format string to write to HTTP server
        let test = "{\"Data\": \"test string\"}"
        var post = "POST / HTTP/1.1\r\n" +
            "Host: 10.227.69.96:3001\r\n" +
            "User-Agent: curl/7.54.0\r\n" +
            "Accept: */*\r\n" +
            "Content-Length: " +
            String(describing: test.count) + "\r\n" +
            "Content-Type: application/json\r\n" + "\r\n" + test
        // Convert string to data
        let data = post.data(using: .utf8) as! NSData
        let bytes = data.bytes
        let length = data.length
        
        // write data to server
        let writeError = write(sockfd, bytes, length)
        // WriteError tells number of bytes written or -1 for error
        if writeError == -1 {
            let sysError = MobiledgeXiOSLibrary.SystemError.getaddrinfo(Int32(writeError), errno)
            close(socket.sockfd)
            throw(sysError)
        } else if writeError != length {
            let sysError = MobiledgeXiOSLibrary.SystemError.getaddrinfo(Int32(writeError), errno)
            close(socket.sockfd)
            throw(sysError)
        }
        
        // read data echoed from server
        var buffer = UnsafeMutableRawPointer.allocate(byteCount: 4096, alignment: MemoryLayout<CChar>.size)
        let readError = read(sockfd, buffer, length)
        // ReadError tells number of bytes read or -1 for error
        if readError <= 0 {
            XCTAssert(false, "Nothing returned")
            close(socket.sockfd)
            throw TestError.runtimeError("nothing returned")
        }
        // Reads from buffer and converts data to String
        let s = String(bytesNoCopy: buffer, length: readError, encoding: .utf8, freeWhenDone: false)
        if s == nil {
            XCTAssert(false, "Unable to convert string")
            close(socket.sockfd)
            throw TestError.runtimeError("Unable to convert string")
        }
        return s!
    }
    
    @available(iOS 13.0, *)
    func testTimeout() {
        let loc = ["longitude": -122.149349, "latitude": 37.459609]
        
        let replyPromise = matchingEngine.registerAndFindCloudlet(devName: "MobiledgeX", appName: "HttpEcho", appVers: "20191204", carrierName: "GDDT", authToken: nil, gpsLocation: loc, uniqueIDType: nil, uniqueID: nil, cellID: nil, tags: nil)
            
        .then { findCloudletReply -> Promise<NWConnection> in
            // Get Dictionary: key -> internal port, value -> AppPort Dictionary
            print("findCloudletReply is \(findCloudletReply)")
            guard let appPortsDict = self.matchingEngine.getTCPAppPorts(findCloudletReply: findCloudletReply) else {
                XCTAssert(false, "GetTCPPorts returned nil")
                throw TestError.runtimeError("GetTCPPorts returned nil")
            }
            if appPortsDict.capacity == 0 {
                XCTAssert(false, "No AppPorts in dictionary")
                throw TestError.runtimeError("No AppPorts in dictionary")
            }
            // Select AppPort Dictionary corresponding to internal port 3001
            guard let appPort = appPortsDict["3001"] else {
                XCTAssert(false, "No app ports with specified internal port")
                throw TestError.runtimeError("No app ports with specified internal port")
            }
            
            return self.matchingEngine.getTCPTLSConnection(findCloudletReply: findCloudletReply, appPort: appPort, desiredPort: "3001", timeout: 100)
        }.then { connection in
            XCTAssert(false, "Should have timed out")
        }.catch { error in
            if case MobiledgeXiOSLibrary.MatchingEngine.GetConnectionError.connectionTimeout = error {
                print("error is \(error)")
                XCTAssert(true, "error is \(error)")
            } else {
                XCTAssert(false, "other error \(error)")
            }
        }
        
        XCTAssert(waitForPromises(timeout: 15))
    }
}


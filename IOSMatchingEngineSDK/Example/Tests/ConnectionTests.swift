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
@testable import SocketIO
import Network

class ConnectionTests: XCTestCase {
    
    var matchingEngine: MatchingEngine!
    var connection: NWConnection!
    let queue = DispatchQueue.global(qos: .background)

    override func setUp() {
        super.setUp()
        matchingEngine = MatchingEngine()
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
        let isCellular = matchingEngine.isCellular()
        if !isCellular {
            XCTAssert(false, "Failed")
        }
    }
    
    func testIsWifi() {
        let wifiOn = true // tester specifies this
        let isWifi = matchingEngine.isWifi()
        if isWifi != wifiOn {
            XCTAssert(false, "Failed")
        }
    }
    
    // NWConnection send data
    private func sendData(data: String) {
        self.connection.send(content: Data(data.utf8), completion: .contentProcessed { (sendError) in
            print("sendError is \(sendError)")
        })
    }
    
    // NWConnection receive data
    private func receiveData() {
        self.connection.receiveMessage { (data, context, isComplete, error) in
            print("Got it")
            print(data)
        }
    }
    
    // Set up NWConnection path and state handlers
    private func connectWithNWConnection() {
        connection.pathUpdateHandler = { path in
            if path.status == .satisfied {
                return
            } else {
                self.connection.restart()
            }
        }
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
    
    // If Path is satisfied and state is ready, connection has been made
    private func checkPathAndState() -> Promise<Bool> {
        let promiseInputs: Promise<Bool> = Promise<Bool>.pending()
        while(connection.currentPath == nil || connection.state != .ready) {
            print("currentPath is \(connection.currentPath) and currentState is \(connection.state)")
        }
        self.sendData(data: "test")
        self.receiveData()
        promiseInputs.fulfill(true)
        return promiseInputs
    }
    
    // test this against google
    func testTCPTLSConnection() {
        let host = "google.com"
        let port = "443"
        
        var replyPromise = matchingEngine.getTCPTLSConnection(host: host, port: port)
        .then { c -> Promise<Bool> in
            self.connection = c
            print("params are \(self.connection.parameters)")
            self.connectWithNWConnection()
            self.connection.start(queue: .global())
            return self.checkPathAndState()
        }.catch { error in
            print("Did not succeed registerAndFindTCPConnection. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 15))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetTCPConnection did not return a value.")
            return
        }
        
        if promiseValue == false {
            XCTAssert(false, "path and state not ready")
        }
    }
    
    func testBSDTCPConnection() {
        let host = "iostestcluster.fairview-main.gddt.mobiledgex.net"
        let port = "6667"
        
        var replyPromise: Promise<Socket>!
        replyPromise = matchingEngine.getBSDTCPConnection(host: host, port: port)
        .then { socket in
            
            // returns Socket struct with fields: file descriptor and addrinfo struct
            let sockfd = socket.sockfd
            let addrInfo = socket.addrInfo
            
            // format string to write to server
            let test = "test string"
            let data = test.data(using: .utf8) as! NSData
            let bytes = data.bytes
            let length = data.length
            
            // write data to server
            let writeError = write(sockfd, bytes, length)
            if writeError == -1 {
                let sysError = SystemError.getaddrinfo(Int32(writeError), errno)
                XCTAssert(false, "Error in writing data: \(sysError)")
            } else if writeError != length {
                let sysError = SystemError.getaddrinfo(Int32(writeError), errno)
                XCTAssert(false, "Error in amount of data written: \(sysError)")
            }
            
            // read data echoed from server
            var buffer = UnsafeMutableRawPointer.allocate(byteCount: length, alignment: MemoryLayout<CChar>.size)
            let readError = read(sockfd, &buffer, length)
            let s = String(bytesNoCopy: &buffer, length: length, encoding: .utf8, freeWhenDone: false)
            if s! != test {
                XCTAssert(false, "Not the same string returned")
            }
        }.catch { error in
            print("error is \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 15))
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
                print("connected")
                connected = true
            }
            print("connecting")
            socket.connect()
        }.catch { error in
            print("Did not succeed registerAndFindWebsocketConnection. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 15))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetWebsocketConnection did not return a value.")
            return
        }
        if !connected {
            XCTAssert(false, "never connected")
        }
        Swift.print("promiseValue is \(promiseValue)")
    }
    
    func testHTTPConnection() {
        var urlRequest: URLRequest!
        let host = "iostestcluster.fairview-main.gddt.mobiledgex.net"
        let port = "6666"
        
        let replyPromise = matchingEngine.getHTTPConnection(host: host, port: port)
        .then { request -> Promise<URLResponse> in
            let promiseInputs: Promise<URLResponse> = Promise<URLResponse>.pending()
            
            urlRequest = request
            let testString = "test string"
            let testDict: [String: String] = ["data": testString]
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
                print("result: \(String(describing: response))")
                guard let data = data else {
                    XCTAssert(false, "Nothing echoed")
                    return
                }
                do {
                    let d = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : String]
                    guard let value = d!["data"] else {
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
        
        XCTAssert(waitForPromises(timeout: 15))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetHTTPConnection did not return a value.")
            return
        }
    }
    
    func testRegisterAndFindHTTPConnection() {
        let loc = ["longitude": -122.149349, "latitude": 37.459609]
        var urlRequest: URLRequest!
        
        let replyPromise = matchingEngine.registerAndFindHTTPConnection(devName: "franklin-mobiledgex", appName: "ios_connection_test", appVers: "1.0", carrierName: "GDDT", location: loc)
        .then { request -> Promise<URLResponse> in
            let promiseInputs: Promise<URLResponse> = Promise<URLResponse>.pending()

            urlRequest = request
            let testString = "test string"
            let testDict: [String: String] = ["data": testString]
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
                    let d = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : String]
                    guard let value = d!["data"] else {
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
            print("Did not succeed registerAndFindHTTPConnection. Error: \(error)")
        }
        
        XCTAssert(waitForPromises(timeout: 15))
        guard let promiseValue = replyPromise.value else {
            XCTAssert(false, "GetHTTPConnection did not return a value.")
            return
        }
    }
}


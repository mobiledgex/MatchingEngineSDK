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
//
//  GetTLSConnectionHelper.swift
//

import Foundation
import os.log
import Promises
import Network
import SocketIO

extension MatchingEngine {
    
    // returns a TCP NWConnection promise
    @available(iOS 13.0, *)
    func getTCPTLSConnection(host: String, port: String, timeout: Double) -> Promise<NWConnection>
    {
        let promise = Promise<NWConnection>(on: .global(qos: .background)) { fulfill, reject in

            // local ip bind to cellular network interface
            guard let clientIP = NetworkInterface.getIPAddress(netInterfaceType: NetworkInterface.CELLULAR) else {
                os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                reject(GetConnectionError.invalidNetworkInterface)
                return
            }
        
            let localEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(clientIP), port: NWEndpoint.Port(port)!)
        
            let serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(port)!)
            // default tls and tcp options, developer can adjust
            let parameters = NWParameters(tls: .init(), tcp: .init())
            // bind to specific local cellular ip
            parameters.requiredInterfaceType = .cellular // works without specifying endpoint?? (does apple prevent non-wifi?)
            parameters.requiredLocalEndpoint = localEndpoint
            // create NWConnection object with connection to server host and port
            let nwConnection = NWConnection(to: serverEndpoint, using: parameters)
            
            let semaphore = DispatchSemaphore(value: 0)
            self.setUpStateHandler(connection: nwConnection, semaphore: semaphore)

            nwConnection.start(queue: DispatchQueue.global(qos: .background))
            
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                reject(GetConnectionError.connectionTimeout)
            }
            
            fulfill(nwConnection)
        }
        return promise
    }
    
    // returns a UDP NWConnection promise
    @available(iOS 13.0, *)
    func getUDPDTLSConnection(host: String, port: String, timeout: Double) -> Promise<NWConnection>
    {
        let promise = Promise<NWConnection>(on: .global(qos: .background)) { fulfill, reject in
            // local ip bind to cellular network interface
            guard let clientIP = NetworkInterface.getIPAddress(netInterfaceType: NetworkInterface.CELLULAR) else {
                os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                reject(GetConnectionError.invalidNetworkInterface)
                return
            }
        
            // default tls and tcp options
            let parameters = NWParameters(dtls: .init(), udp: .init())
            // bind to specific cellular ip
            parameters.requiredInterfaceType = .cellular // works without specifying endpoint?? (does apple prevent non-wifi?)
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(clientIP), port: NWEndpoint.Port(port)!)
            let nwConnection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(port)!, using: parameters)
            
            let semaphore = DispatchSemaphore(value: 0)
            self.setUpStateHandler(connection: nwConnection, semaphore: semaphore)
            
            nwConnection.start(queue: DispatchQueue.global(qos: .background))
            
            if semaphore.wait(timeout: .now() + timeout) == .timedOut {
                reject(GetConnectionError.connectionTimeout)
            }
            
            fulfill(nwConnection)
        }
        return promise
    }
    
    // Returns SocketIOClient promise
    func getSecureWebsocketConnection(host: String, port: String) -> Promise<SocketManager>
    {
        let promise = Promise<SocketManager>(on: .global(qos: .background)) { fulfill, reject in
            
            // DNS Lookup
            do {
                try MexUtil.shared.verifyDmeHost(host: host)
            } catch {
                reject(error)
            }
            let url = "wss://\(host):\(port)/"
            let manager = SocketManager(socketURL: URL(string: url)!)
            fulfill(manager)
        }
        return promise
    }
    
    @available(iOS 13.0, *)
    private func setUpStateHandler(connection: NWConnection, semaphore: DispatchSemaphore) {
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                semaphore.signal()
            default:
                print("state update is \(state)")
            }
        }
    }
}

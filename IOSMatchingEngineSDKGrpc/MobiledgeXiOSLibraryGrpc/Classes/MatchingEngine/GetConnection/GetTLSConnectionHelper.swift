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
//
//  GetTLSConnectionHelper.swift
//

import os.log
import Promises
import Network
import SocketIO

extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    // returns a TCP NWConnection promise
    @available(iOS 13.0, *)
    func getTCPTLSConnection(host: String, port: UInt16, timeout: Double) -> Promise<NWConnection>
    {
        let promise = Promise<NWConnection>(on: .global(qos: .background)) { fulfill, reject in

            // local ip bind to cellular network interface
            guard let clientIP = MobiledgeXiOSLibraryGrpc.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR) else {
                os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                reject(GetConnectionError.invalidNetworkInterface)
                return
            }
        
            let localEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(clientIP), port: NWEndpoint.Port(String(describing: port))!)
        
            let serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(String(describing: port))!)
            // default tls and tcp options, developer can adjust
            let options = NWProtocolTLS.Options()
            sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
                
                let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
                var error: CFError?
                if SecTrustEvaluateWithError(trust, &error) {
                    sec_protocol_verify_complete(true)
                } else {
                    if self.allowSelfSignedCertsGetConnection == true {
                        sec_protocol_verify_complete(true)
                    } else {
                        sec_protocol_verify_complete(false)
                    }
                }
            }, self.state.executionQueue)
            let parameters = NWParameters(tls: options, tcp: .init())
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
    func getUDPDTLSConnection(host: String, port: UInt16, timeout: Double) -> Promise<NWConnection>
    {
        let promise = Promise<NWConnection>(on: .global(qos: .background)) { fulfill, reject in
            // local ip bind to cellular network interface
            guard let clientIP = MobiledgeXiOSLibraryGrpc.NetworkInterface.getIPAddress(netInterfaceType: MobiledgeXiOSLibraryGrpc.NetworkInterface.CELLULAR) else {
                os_log("Cannot get ip address with specified network interface", log: OSLog.default, type: .debug)
                reject(GetConnectionError.invalidNetworkInterface)
                return
            }
        
            // default tls and tcp options
            let options = NWProtocolTLS.Options()
            sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
                    
                let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
                var error: CFError?
                if SecTrustEvaluateWithError(trust, &error) {
                    sec_protocol_verify_complete(true)
                } else {
                    if self.allowSelfSignedCertsGetConnection == true {
                        sec_protocol_verify_complete(true)
                    } else {
                        sec_protocol_verify_complete(false)
                    }
                }
            }, self.state.executionQueue)
            let parameters = NWParameters(dtls: options, udp: .init())
            // bind to specific cellular ip
            parameters.requiredInterfaceType = .cellular // works without specifying endpoint?? (does apple prevent non-wifi?)
            parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(clientIP), port: NWEndpoint.Port(String(describing: port))!)
            let nwConnection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(String(describing: port))!, using: parameters)
            
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

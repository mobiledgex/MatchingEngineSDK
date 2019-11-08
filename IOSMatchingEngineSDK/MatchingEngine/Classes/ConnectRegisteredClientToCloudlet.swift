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
//  ConnectRegisteredClientToCloudlet.swift
//

import Promises
import SocketIO
import Network

extension MatchingEngine {
    
    // Developer will not be able to implement callbacks....
    public func registerAndFindTCPConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<CFSocket>
    {
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(request: registerClientRequest)
            .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            return self.getTCPConnection(findCloudletReply: findCloudletReply)
        }.catch { error in
            return error
        }
    }
    
    // RegisterClient -> FindCloudlet -> GetTCPConnection (returns Promise<CFSocket>)
    @available(iOS 12.0, *)
    public func registerAndFindTCPTLSConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<NWConnection>
    {
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(request: registerClientRequest)
            .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            if #available(iOS 12.0, *) {
                return self.getTCPTLSConnection(findCloudletReply: findCloudletReply)
            } else {
                // Fallback on earlier versions
                let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
                promiseInputs.reject(GetConnectionError.outdatedIOS)
                return promiseInputs
            }
        }.catch { error in
            return error
        }
    }
    
    // DME host and port specified (returns Promise<CFSocket>)
    @available(iOS 12.0, *)
    public func registerAndFindTCPConnection(host: String, port: UInt, devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<NWConnection>
    {
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(host: host, port: port, request: registerClientRequest)
        .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(host: host, port: port, request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            if #available(iOS 12.0, *) {
                return self.getTCPTLSConnection(findCloudletReply: findCloudletReply)
            } else {
                // Fallback on earlier versions
                let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
                promiseInputs.reject(GetConnectionError.outdatedIOS)
                return promiseInputs
            }
        }.catch { error in
            return error
        }
    }
    
    // RegisterClient -> FindCloudlet -> GetUDPConnection (returns Promise<CFSocket>)
    public func registerAndFindUDPConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<CFSocket>
    {
        /*let promiseInputs: Promise<URLSessionStreamTask> = Promise<URLSessionStreamTask>.pending()*/
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(request: registerClientRequest)
            .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            return self.getUDPConnection(findCloudletReply: findCloudletReply)
        }.catch { error in
            return error
        }
    }
    
    // DME host and port are specified (returns Promise<CFSocket>)
    public func registerAndFindUDPConnection(host: String, port: UInt, devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<CFSocket>
    {
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(host: host, port: port, request: registerClientRequest)
        .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(host: host, port: port, request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            return self.getUDPConnection(findCloudletReply: findCloudletReply)
        }.catch { error in
            return error
        }
    }
    
    // RegisterClient -> FindCloudlet -> GetHTTPConnection (returns Promise<URLRequest>)
    public func registerAndFindHTTPConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<URLRequest>
    {
        /*let promiseInputs: Promise<URLSessionStreamTask> = Promise<URLSessionStreamTask>.pending()*/
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(request: registerClientRequest)
            .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            return self.getHTTPConnection(findCloudletReply: findCloudletReply)
        }.catch { error in
            return error
        }
    }
    
    // DME host and port are specified (returns Promise<URLRequest>)
    public func registerAndFindHTTPConnection(host: String, port: UInt, devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<URLRequest>
    {
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(host: host, port: port, request: registerClientRequest)
        .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(host: host, port: port, request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            return self.getHTTPConnection(findCloudletReply: findCloudletReply)
        }.catch { error in
            return error
        }
    }
    
    // RegisterClient -> FindCloudlet -> GetWebsocketConnection (returns Promise<SocketIOClient>)
    public func registerAndFindWebsocketConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<SocketManager>
    {
        /*let promiseInputs: Promise<URLSessionStreamTask> = Promise<URLSessionStreamTask>.pending()*/
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(request: registerClientRequest)
            .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            return self.getWebsocketConnection(findCloudletReply: findCloudletReply)
        }.catch { error in
            return error
        }
    }
    
    // DME host and port are specified (returns Promise<SocketIOClient>)
    public func registerAndFindWebsocketConnection(host: String, port: UInt, devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<SocketManager>
    {
        let registerClientRequest = self.createRegisterClientRequest(devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers,
                                                                     carrierName: carrierName,
                                                                     authToken: nil)
        return self.registerClient(host: host, port: port, request: registerClientRequest)
        .then { (registerClientReply) -> Promise<[String: AnyObject]> in
            print("RegisterClientReply is \(registerClientReply)")
            
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName,
                                                                     gpsLocation: location,
                                                                     devName: devName,
                                                                     appName: appName,
                                                                     appVers: appVers)
            return self.findCloudlet(host: host, port: port, request: findCloudletRequest)
        }.then { findCloudletReply in
            print("FindCloudletReply is \(findCloudletReply)")
            return self.getWebsocketConnection(findCloudletReply: findCloudletReply)
        }.catch { error in
            return error
        }
    }
}

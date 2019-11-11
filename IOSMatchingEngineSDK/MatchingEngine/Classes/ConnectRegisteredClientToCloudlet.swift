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
// Wrapper functions to RegisterClient -> FindCloudlet -> and GetConnection using the findCloudletReply

import Promises
import SocketIO
import Network
import NSLogger

extension MatchingEngine {
    
    public func registerAndFindBSDTCPConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<Socket>
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
            let promiseInputs: Promise<Socket> = Promise<Socket>.pending()
            // list of available TCP ports on server
            guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
                Logger.shared.log(.network, .debug, "Cannot get public port")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            // Make sure there are ports for specified protocol
            if ports.capacity == 0 {
                Logger.shared.log(.network, .debug, "Cannot find ports for TCP")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            let port = ports[0]
            // server host
            guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
                Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                promiseInputs.reject(GetConnectionError.missingServerFqdn)
                return promiseInputs
            }
            return self.getBSDTCPConnection(host: serverFqdn, port: port)
        }.catch { error in
            return error
        }
    }
    
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
            let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
            // list of available TCP ports on server
            guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
                Logger.shared.log(.network, .debug, "Cannot get public port")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            // Make sure there are ports for specified protocol
            if ports.capacity == 0 {
                Logger.shared.log(.network, .debug, "Cannot find ports for TCP")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            let port = ports[0]
            // server host
            guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
                Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                promiseInputs.reject(GetConnectionError.missingServerFqdn)
                return promiseInputs
            }
            return self.getTCPConnection(host: serverFqdn, port: port)
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
                let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
                // list of available TCP ports on server
                guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
                    Logger.shared.log(.network, .debug, "Cannot get public port")
                    promiseInputs.reject(GetConnectionError.missingServerPort)
                    return promiseInputs
                }
                // Make sure there are ports for specified protocol
                if ports.capacity == 0 {
                    Logger.shared.log(.network, .debug, "Cannot find ports for TCP")
                    promiseInputs.reject(GetConnectionError.missingServerPort)
                    return promiseInputs
                }
                let port = ports[0]
                // server host
                guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
                    Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                    promiseInputs.reject(GetConnectionError.missingServerFqdn)
                    return promiseInputs
                }
                return self.getTCPTLSConnection(host: serverFqdn, port: port)
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
    
    public func registerAndFindBSDUDPConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<Socket>
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
            let promiseInputs: Promise<Socket> = Promise<Socket>.pending()
            // list of available TCP ports on server
            guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
                Logger.shared.log(.network, .debug, "Cannot get public port")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            // Make sure there are ports for specified protocol
            if ports.capacity == 0 {
                Logger.shared.log(.network, .debug, "Cannot find ports for TCP")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            let port = ports[0]
            // server host
            guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
                Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                promiseInputs.reject(GetConnectionError.missingServerFqdn)
                return promiseInputs
            }
            return self.getBSDUDPConnection(host: serverFqdn, port: port)
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
            let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
            // list of available TCP ports on server
            guard let ports = self.getUDPPorts(findCloudletReply: findCloudletReply) else {
                Logger.shared.log(.network, .debug, "Cannot get public port")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            // Make sure there are ports for specified protocol
            if ports.capacity == 0 {
                Logger.shared.log(.network, .debug, "Cannot find ports for TCP")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            let port = ports[0]
            // server host
            guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
                Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                promiseInputs.reject(GetConnectionError.missingServerFqdn)
                return promiseInputs
            }
            return self.getUDPConnection(host: serverFqdn, port: port)
        }.catch { error in
            return error
        }
    }
    
    @available(iOS 12.0, *)
    public func registerAndFindUDPDTLSConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<NWConnection>
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
                let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
                // list of available TCP ports on server
                guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
                    Logger.shared.log(.network, .debug, "Cannot get public port")
                    promiseInputs.reject(GetConnectionError.missingServerPort)
                    return promiseInputs
                }
                // Make sure there are ports for specified protocol
                if ports.capacity == 0 {
                    Logger.shared.log(.network, .debug, "Cannot find ports for TCP")
                    promiseInputs.reject(GetConnectionError.missingServerPort)
                    return promiseInputs
                }
                let port = ports[0]
                // server host
                guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
                    Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                    promiseInputs.reject(GetConnectionError.missingServerFqdn)
                    return promiseInputs
                }
                return self.getUDPDTLSConnection(host: serverFqdn, port: port)
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
    
    // RegisterClient -> FindCloudlet -> GetHTTPConnection (returns Promise<URLRequest>)
    public func registerAndFindHTTPConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<URLRequest>
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
            let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
            // list of available TCP ports on server
            guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {  
                Logger.shared.log(.network, .debug, "Cannot get public port")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            // Make sure there are ports for specified protocol
            if ports.capacity == 0 {
                Logger.shared.log(.network, .debug, "Cannot find ports for TCP")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            let port = ports[0]
            // server host
            guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
                Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                promiseInputs.reject(GetConnectionError.missingServerFqdn)
                return promiseInputs
            }
            return self.getHTTPConnection(host: serverFqdn, port: port)
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
            return self.getHTTPConnection(host: host, port: String(port))
        }.catch { error in
            return error
        }
    }
    
    // RegisterClient -> FindCloudlet -> GetWebsocketConnection (returns Promise<SocketIOClient>)
    public func registerAndFindWebsocketConnection(devName: String, appName: String, appVers: String, carrierName: String, location: [String: Any]) -> Promise<SocketManager>
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
            let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
            // list of available TCP ports on server
            guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
                Logger.shared.log(.network, .debug, "Cannot get public port")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            // Make sure there are ports for specified protocol
            if ports.capacity == 0 {
                Logger.shared.log(.network, .debug, "Cannot find ports for TCP")
                promiseInputs.reject(GetConnectionError.missingServerPort)
                return promiseInputs
            }
            let port = ports[0]
            // server host
            guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
                Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                promiseInputs.reject(GetConnectionError.missingServerFqdn)
                return promiseInputs
            }
            return self.getWebsocketConnection(host: serverFqdn, port: port)
        }.catch { error in
            return error
        }
    }
}

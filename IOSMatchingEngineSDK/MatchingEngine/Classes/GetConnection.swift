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
//  GetConnection.swift
//

import Foundation
import NSLogger
import Promises

class Ports {
    public static let proto = "proto"
    public static let internal_port = "internal_port"
    public static let public_port = "public_port"
    public static let path_prefix = "path_prefix"
    public static let fqdn_prefix = "fqdn_prefix"
    public static let end_port = "end_port"
}

extension MatchingEngine {
    
    //Get a TCP or UDP connection on client interface specified with the provisioned appInst server and port
    public func getConnection(netInterfaceType: String?, findCloudletReply: [String: AnyObject], ports: [String]?, proto: String?) -> Promise<UnsafeMutablePointer<addrinfo>> {
        return Promise<UnsafeMutablePointer<addrinfo>>(on: self.executionQueue) { fulfill, reject in
            //client host
            let clientIP = self.getIPAddress(netInterfaceType: netInterfaceType)
            //server host
            guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply) else {
                Logger.shared.log(.network, .debug, "Cannot get server fqdn")
                return
            }
            //server port
            guard let port = self.getPort(findCloudletReply: findCloudletReply, ports: ports) else {
                Logger.shared.log(.network, .debug, "Cannot get public port")
                return
            }
            
            //used to store addrinfo fields like sockaddr struct, socket type, protocol, and address length
            var res: UnsafeMutablePointer<addrinfo>!
            var serverRes: UnsafeMutablePointer<addrinfo>!
            //initialize addrnfo fields
            var addrInfo = addrinfo.init()
            addrInfo.ai_family = AF_UNSPEC //IPv4 or IPv6
            if proto == "UDP" {
                addrInfo.ai_socktype = SOCK_DGRAM //UDP
            } else {
                addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets (default)
            }
            
            //getaddrinfo function makes ip + port conversion to sockaddr easy
            let error = getaddrinfo(clientIP, port, &addrInfo, &res)
            if error != 0 {
                let sysError = SystemError.getaddrinfo(error, errno)
                Logger.shared.log(.network, .debug, "Client get addrinfo error is \(sysError)")
                reject(sysError)
            }
            
            //socket returns a socket descriptor
            let s = socket(res.pointee.ai_family, res.pointee.ai_socktype, 0)  //protocol set to 0 to choose proper protocol for given socktype
            if s == -1 {
                let sysError = SystemError.socket(s, errno)
                Logger.shared.log(.network, .debug, "Client socket error is \(sysError)")
                reject(sysError)
            }
            
            //bind to socket to client cellular network interface
            let b = bind(s, res.pointee.ai_addr, res.pointee.ai_addrlen)
            if b == -1 {
                let sysError = SystemError.bind(b, errno)
                Logger.shared.log(.network, .debug, "Client bind error is \(sysError)")
                reject(sysError)
            }
            
            let serverError = getaddrinfo(serverFqdn, port, &addrInfo, &serverRes)
            if serverError != 0 {
                let sysError = SystemError.getaddrinfo(serverError, errno)
                Logger.shared.log(.network, .debug, "Server get addrinfo error is \(sysError)")
                reject(sysError)
            }
            
            let serverSocket = socket(serverRes.pointee.ai_family, serverRes.pointee.ai_socktype, 0)
            if serverSocket == -1 {
                let sysError = SystemError.connect(serverSocket, errno)
                Logger.shared.log(.network, .debug, "Server socket error is \(sysError)")
                reject(sysError)
            }
            
            //connect our socket to the provisioned socket
            let c = connect(s, serverRes.pointee.ai_addr, serverRes.pointee.ai_addrlen)
            if c == -1 {
                let sysError = SystemError.connect(c, errno)
                Logger.shared.log(.network, .debug, "Connection error is \(sysError)")
                reject(sysError)
            }
            fulfill(res)
        }
    }
    
    //Returns the server side port
    private func getPort(findCloudletReply: [String: AnyObject], ports: [String]?) -> String? {
        guard let ports = ports else {
            return getPortBackup(findCloudletReply: findCloudletReply)
        }
        if ports.count > 0 {
            return ports[0]   //Not sure what to do if given multiple ports, so just returning the first in list
        } else {
            return getPortBackup(findCloudletReply: findCloudletReply)
        }
    }
    
    //This will look at the findCloudletReply if the user does not specify port
    //TODO: Handle end ports
    private func getPortBackup(findCloudletReply: [String: AnyObject]) -> String? {
        //Gets port dictionary to find public port
        guard let portDict = getPortDict(findCloudletReply: findCloudletReply) else {
            return nil
        }
        //get public port from port dictionary
        guard let publicPort = portDict[Ports.public_port] as? NSNumber else {    //type Optional<Any> cast to NSNumber
            return nil
        }
        return publicPort.stringValue
    }
    
    //Returns the server side fqdn
    private func getAppFqdn(findCloudletReply: [String: AnyObject]) -> String? {
        guard let appFqdn = findCloudletReply[FindCloudletReply.fqdn] as? String else {
            return nil
        }
        let baseFqdn = appFqdn
        //get the port dict to find fqdn prefix
        guard let portDict = getPortDict(findCloudletReply: findCloudletReply) else {
            return baseFqdn
        }
        //get fqdn prefix from port dictionary
        guard let fqdnPrefix = portDict[Ports.fqdn_prefix] as? NSString else {    //type Optional<Any> cast to NSNumber
            return baseFqdn
        }
        return fqdnPrefix as String + baseFqdn
    }
    
    //Returns the value of the "ports" key in findCloudletReply ([String: Any])
    private func getPortDict(findCloudletReply: [String: AnyObject]) -> [String: Any]? {
        //array of dictionaries
        guard let portDict = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        //first dictionary in array
        guard let port = portDict.first else {
            return nil
        }
        return port
    }
    
    //Gets the client IP Address on the interface specified
    //TODO: check for multiple cellular ip addresses (multiple SIM subscriptions possible)
    private func getIPAddress(netInterfaceType: String?) -> String? {
        var specifiedNetInterface: Bool
        if netInterfaceType == nil {
            specifiedNetInterface = false //default is cellular interface
        } else {
            specifiedNetInterface = true
        }
        var address : String?
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return nil }
        guard let firstAddr = ifaddr else { return nil }
        
        // For each interface ...
        for ifptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let interface = ifptr.pointee
            
            // Check interface name:
            let name = String(cString: interface.ifa_name)
            if  name == netInterfaceType || !specifiedNetInterface {     //Cellular interface
                    
                //return interface.ifa_addr.pointee
                let data = NSData(bytes: &interface.ifa_addr.pointee, length: MemoryLayout<sockaddr_in>.size) as CFData                 //Convert interface address to a human readable string:
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                            &hostname, socklen_t(hostname.count),
                            nil, socklen_t(0), NI_NUMERICHOST)
                address = String(cString: hostname)
            }
        }
        freeifaddrs(ifaddr)
        return address
    }
}

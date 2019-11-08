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
import SocketIO
import Network

class Ports {
    public static let proto = "proto"
    public static let internal_port = "internal_port"
    public static let public_port = "public_port"
    public static let path_prefix = "path_prefix"
    public static let fqdn_prefix = "fqdn_prefix"
    public static let end_port = "end_port"
}

// FIGURE THESE OUT
class NetworkInterface {
    public static let cellular = "pdp_ip0" // 3G?? -> shouldn't use
    public static let wifi = "en0"
    public static let currConnection = "ap1"
}

public class Protocol {
    public static let tcp = "L_PROTO_TCP"
    public static let udp = "L_PROTO_UDP"
    public static let http = "L_PROTO_HTTP"
    public static let unknown = "L_PROTO_UNKNOWN"
}

extension MatchingEngine {
    
    // Returns TCP CFSocket promise
    public func getTCPConnection(findCloudletReply: [String: AnyObject]) -> Promise<CFSocket>
    {
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        // local ip bind to cellular network interface
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
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
        //let port = ports[0]
        let port = "6667"
        // server host
        guard let serverFqdn = self.getAppFqdn(findCloudletReply: findCloudletReply, port: port) else {
            Logger.shared.log(.network, .debug, "Cannot get server fqdn")
            promiseInputs.reject(GetConnectionError.missingServerFqdn)
            return promiseInputs
        }
        
        // initialize CFSocket (no callbacks provided -> developer will implement)
        guard let socket = CFSocketCreate(kCFAllocatorDefault, AF_INET, SOCK_STREAM, IPPROTO_TCP, 0, nil, nil) else {
            promiseInputs.reject(GetConnectionError.unableToCreateSocket)
            return promiseInputs
        }
        // initialize addrinfo fields, depending on protocol
        var addrInfo = addrinfo.init()
        addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
        addrInfo.ai_socktype = SOCK_STREAM // TCP stream sockets (default)
        
        return connectAndBindSocket(serverHost: serverFqdn, clientHost: clientIP, port: port, addrInfo: &addrInfo, socket: socket)
    }
    
    // returns a TCP NWConnection promise
    @available(iOS 12.0, *)
    public func getTCPTLSConnection(findCloudletReply: [String: AnyObject]) -> Promise<NWConnection>
    {
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
        // local ip bind to cellular network interface
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        // list of available TCP ports on server
        guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
            Logger.shared.log(.network, .debug, "Cannot get public port")
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
        
        let serverHost = "https://www.example.com"
        //let serverHost = "https://www.google.com"
        //let serverHost = "10.227.69.233"
        //let serverHost = "50.207.175.42"
        //let serverHost = "24.6.13.76"
        //let serverPort = "7777"
        let serverPort = "80"
        //let serverPort = "443"
        
        
        let localEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(clientIP), port: NWEndpoint.Port(port)!)
        let serverEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(serverHost), port: NWEndpoint.Port(serverPort)!)
        // default tls and tcp options, developer can adjust
        let parameters = NWParameters(tls: .init(), tcp: .init())
        print("paramteters are \(parameters.debugDescription)")
        // bind to specific local cellular ip
        parameters.requiredInterfaceType = .cellular // works without specifying endpoint?? (does apple prevent non-wifi?)
        parameters.requiredLocalEndpoint = localEndpoint
        // create NWConnection object with connection to server host and port
        let nwConnection = NWConnection(to: serverEndpoint, using: parameters)
        //ensureStateAndPathReady(connection: nwConnection)
        promiseInputs.fulfill(nwConnection)
        return promiseInputs
    }
    
    // Returns UDP CFSocket promise
    public func getUDPConnection(findCloudletReply: [String: AnyObject]) -> Promise<CFSocket>
    {
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        // local ip bind to cellular network interface
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        // list of available UDP ports on server
        guard let ports = self.getUDPPorts(findCloudletReply: findCloudletReply) else {
            Logger.shared.log(.network, .debug, "Cannot get public port")
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
        // initialize socket (no callbacks provided -> developer will implement)
        guard let socket = CFSocketCreate(kCFAllocatorDefault, AF_UNSPEC, SOCK_DGRAM, IPPROTO_UDP, 0, nil, nil) else {
            promiseInputs.reject(GetConnectionError.unableToCreateSocket)
            return promiseInputs
        }
        // initialize addrinfo fields, depending on protocol
        var addrInfo = addrinfo.init()
        addrInfo.ai_family = AF_UNSPEC // IPv4 or IPv6
        addrInfo.ai_socktype = SOCK_DGRAM // UDP datagrams
                        
        return connectAndBindSocket(serverHost: serverFqdn, clientHost: clientIP, port: port, addrInfo: &addrInfo, socket: socket)
    }
    
    // returns a UDP NWConnection promise
    @available(iOS 12.0, *)
    public func getUDPTLSConnection(findCloudletReply: [String: AnyObject]) -> Promise<NWConnection>
    {
        let promiseInputs: Promise<NWConnection> = Promise<NWConnection>.pending()
        // local ip bind to cellular network interface
        guard let clientIP = self.getIPAddress(netInterfaceType: NetworkInterface.cellular) else {
            Logger.shared.log(.network, .debug, "Cannot get ip address with specified network interface")
            promiseInputs.reject(GetConnectionError.invalidNetworkInterface)
            return promiseInputs
        }
        // list of available TCP ports on server
        guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
            Logger.shared.log(.network, .debug, "Cannot get public port")
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
        
        // default tls and tcp options
        let parameters = NWParameters(dtls: .init(), udp: .init())
        // bind to specific cellular ip
        parameters.requiredInterfaceType = .cellular // works without specifying endpoint?? (does apple prevent non-wifi?)
        parameters.requiredLocalEndpoint = NWEndpoint.hostPort(host: NWEndpoint.Host(clientIP), port: NWEndpoint.Port(port)!)
        let nwConnection = NWConnection(host: NWEndpoint.Host(serverFqdn), port: NWEndpoint.Port(port)!, using: parameters)
        
        promiseInputs.fulfill(nwConnection)
        return promiseInputs
    }
    
    // Returns URLRequest promise
    public func getHTTPConnection(findCloudletReply: [String: AnyObject]) -> Promise<URLRequest>
    {
        let promiseInputs: Promise<URLRequest> = Promise<URLRequest>.pending()
        // list of available HTTP ports on server
        guard let ports = self.getHTTPPorts(findCloudletReply: findCloudletReply) else {
            Logger.shared.log(.network, .debug, "Cannot get public port")
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
        let uri = "https://\(serverFqdn):\(port)"
        let url = URL(string: uri)
        let urlRequest = URLRequest(url: url!)
        promiseInputs.fulfill(urlRequest)
        return promiseInputs
    }
    
    // Returns SocketIOClient promise
    public func getWebsocketConnection(findCloudletReply: [String: AnyObject]) -> Promise<SocketManager>
    {
        let promiseInputs: Promise<SocketManager> = Promise<SocketManager>.pending()
        // list of available TCP ports on server
        guard let ports = self.getTCPPorts(findCloudletReply: findCloudletReply) else {
            Logger.shared.log(.network, .debug, "Cannot get public port")
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
        let url = "wss://\(serverFqdn):\(port)/"   // wss should returned in path_prefix?
        let manager = SocketManager(socketURL: URL(string: url)!)
        //let socket = manager.defaultSocket
        promiseInputs.fulfill(manager)
        return promiseInputs
    }
    
    // Connect CFSocket to given host and port and bind to cellular interface
    private func connectAndBindSocket(serverHost: String, clientHost: String, port: String, addrInfo: UnsafeMutablePointer<addrinfo>, socket: CFSocket) -> Promise<CFSocket>
    {
        let promiseInputs: Promise<CFSocket> = Promise<CFSocket>.pending()
        return all (
            getSockAddr(host: serverHost, port: port, addrInfo: addrInfo),
            getSockAddr(host: clientHost, port: port, addrInfo: addrInfo)
        ).then { serverSockAddr, clientSockAddr -> Promise<CFSocket> in // getSockAddr promises returns a pointer to sockaddr struct
            // connect to server
            print("serverSockAddr is \(serverSockAddr.pointee)")
            let serverData = NSData(bytes: serverSockAddr, length: MemoryLayout<sockaddr>.size) as CFData
            let serverError = CFSocketConnectToAddress(socket, serverData, 5) // 5 second timeout
            print("serverError is \(serverError)")
            // bind to client cellular interface
            print("clientSockAddr is \(clientSockAddr.pointee)")
            let clientData = NSData(bytes: clientSockAddr, length: MemoryLayout<sockaddr>.size) as CFData
            let clientError = CFSocketSetAddress(socket, clientData)
            print("client error is \(clientError.rawValue)")
            if clientError != CFSocketError.success {
                promiseInputs.reject(GetConnectionError.unableToBind)
                return promiseInputs
            }
            print("client bind success")
            
            switch serverError {
            case .success:
                promiseInputs.fulfill(socket)
            case .error:
                promiseInputs.reject(GetConnectionError.unableToConnectToServer)
            case .timeout:
                promiseInputs.reject(GetConnectionError.connectionTimeout)
            }
            return promiseInputs
        }.catch { error in
            promiseInputs.reject(error)
        }
    }
    
    // creates an addrinfo object, which stores sockaddr struct, return sockaddr struct
    private func getSockAddr(host: String, port: String, addrInfo: UnsafeMutablePointer<addrinfo>) -> Promise<UnsafeMutablePointer<sockaddr>>
    {
        return Promise<UnsafeMutablePointer<sockaddr>>(on: self.executionQueue) { fulfill, reject in
            // Stores addrinfo fields like sockaddr struct, socket type, protocol, and address length
            var res: UnsafeMutablePointer<addrinfo>!
            
            print("host is \(host)")
            let error = getaddrinfo(host, port, addrInfo, &res)
            if error != 0 {
                let sysError = SystemError.getaddrinfo(error, errno)
                Logger.shared.log(.network, .debug, "Get addrinfo error is \(sysError)")
                reject(sysError)
            }
            fulfill(res.pointee.ai_addr)
            /*print("serversockaddr before _in is \(res.pointee.ai_addr.pointee)")
            let addr_in = withUnsafePointer(to: res.pointee.ai_addr) {
                $0.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
                    $0.pointee
                }
            }
            print("serversockaddr after _in is \(addr_in)")
            let ptr = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: MemoryLayout<sockaddr_in>.size)
            ptr.initialize(to: addr_in)
            print("serversockaddr before is \(ptr.pointee)")
            fulfill(ptr)*/
            //let inAddr = inet_addr(host)
            /*let inAddr = inet_addr("10.227.65.109")
            var sin = sockaddr_in()
            sin.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
            sin.sin_family = sa_family_t(AF_INET)
            sin.sin_port = UInt16(port)!
            //sin.sin_port = 6666
            sin.sin_addr.s_addr = inAddr
            sin.sin_zero = (0,0,0,0,0,0,0,0)*/
            
            /*let ptr = UnsafeMutablePointer<sockaddr_in>.allocate(capacity: MemoryLayout<sockaddr_in>.size)
            ptr.initialize(to: sin)
            //print("sin before fulfill \(ptr.pointee)")
            fulfill(ptr)
            //fulfill(res.pointee.ai_addr)*/
        }
    }
    
    // Can get port by any protocol, customized or not
    public func getPortsByProtocol(findCloudletReply: [String: AnyObject], proto: String) -> [String]? {
        var portsList = [String]()
        // array of dictionaries
        guard let portDicts = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        // iterate through all dictionaries
        for portDict in portDicts {
            // check for protocol
            if portDict[Ports.proto] as! String == proto {
                if let publicPort = portDict[Ports.public_port] as? String {
                    portsList.append(publicPort)
                    portToPathPrefixDict[publicPort] = portDict[Ports.path_prefix] as? String
                }
            }
        }
        return portsList
    }
    
    // Return list of TCP ports given in findCloudletReply
    public func getTCPPorts(findCloudletReply: [String: AnyObject]) -> [String]? {
        var portsList = [String]()
        // array of dictionaries
        guard let portDicts = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        // iterate through all dictionaries
        for portDict in portDicts {
            // check for protocol
            if portDict[Ports.proto] as! String == Protocol.tcp {
                if let publicPort = portDict[Ports.public_port] as? NSNumber {
                    portsList.append("\(publicPort)")
                    portToPathPrefixDict["\(publicPort)"] = portDict[Ports.path_prefix] as? String
                }
            }
        }
        return portsList
    }
    
    // Return list of UDP ports given in findCloudletReply
    public func getUDPPorts(findCloudletReply: [String: AnyObject]) -> [String]? {
        var portsList = [String]()
        // array of dictionaries
        guard let portDicts = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        // iterate through all dictionaries
        for portDict in portDicts {
            // check for protocol
            if portDict[Ports.proto] as! String == Protocol.udp {
                if let publicPort = portDict[Ports.public_port] as? String {
                    portsList.append(publicPort)
                    portToPathPrefixDict[publicPort] = portDict[Ports.path_prefix] as? String
                }
            }
        }
        return portsList
    }
    
    // Return list of HTTP ports given in findCloudletReply
    public func getHTTPPorts(findCloudletReply: [String: AnyObject]) -> [String]? {
        var portsList = [String]()
        // array of dictionaries
        guard let portDicts = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        // iterate through all dictionaries
        for portDict in portDicts {
            // check for protocol
            if portDict[Ports.proto] as! String == Protocol.http {
                if let publicPort = portDict[Ports.public_port] as? String {
                    portsList.append(publicPort)
                    portToPathPrefixDict[publicPort] = portDict[Ports.path_prefix] as? String
                }
            }
        }
        return portsList
    }
    
    // Returns the server side fqdn from findCloudletReply
    public func getAppFqdn(findCloudletReply: [String: AnyObject], port: String) -> String?
    {
        guard let appFqdn = findCloudletReply[FindCloudletReply.fqdn] as? String else {
            return nil
        }
        let baseFqdn = appFqdn
        // get fqdn prefix from port dictionary
        guard let fqdnPrefix = portToPathPrefixDict[port] else {
            return baseFqdn
        }
        return fqdnPrefix + baseFqdn
    }
    
    // Gets the client IP Address on the interface specified
    // TODO: check for multiple cellular ip addresses (multiple SIM subscriptions possible)
    public func getIPAddress(netInterfaceType: String?) -> String?
    {
        var specifiedNetInterface: Bool
        if netInterfaceType == nil {
            specifiedNetInterface = false // default is cellular interface
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
            if  name == netInterfaceType || !specifiedNetInterface {     // Cellular interface
                    
                // return interface.ifa_addr.pointee
                let data = NSData(bytes: &interface.ifa_addr.pointee, length: MemoryLayout<sockaddr_in>.size) as CFData                 // Convert interface address to a human readable string:
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

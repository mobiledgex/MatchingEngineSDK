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
//  GetPorts.swift
//

public class Protocol {
    public static let tcp = "L_PROTO_TCP"
    public static let udp = "L_PROTO_UDP"
    public static let http = "L_PROTO_HTTP"
    public static let unknown = "L_PROTO_UNKNOWN"
}

class Ports {
    public static let proto = "proto"
    public static let internal_port = "internal_port"
    public static let public_port = "public_port"
    public static let path_prefix = "path_prefix"
    public static let fqdn_prefix = "fqdn_prefix"
    public static let end_port = "end_port"
}

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // Returns the server side fqdn from findCloudletReply with specified port (fqdn prefix based on port)
    public func getAppFqdn(findCloudletReply: [String: AnyObject], port: String) -> String?
    {
        guard let appFqdn = findCloudletReply[FindCloudletReply.fqdn] as? String else {
            return nil
        }
        let baseFqdn = appFqdn
        // get fqdn prefix from port dictionary
        guard let fqdnPrefix = state.portToPathPrefixDict[port] else {
            return baseFqdn
        }
        return fqdnPrefix + baseFqdn
    }
    
    // Returns dictionary: key -> internal port, value -> "AppPort" dictionary
    public func getAppPortsByProtocol(findCloudletReply: [String: AnyObject], proto: String) -> [String: [String: Any]]?
    {
        var appPortsByProtocol: [String: [String: Any]]?
        // array of "AppPort" dictionaries returned in findCloudlet
        guard let portDicts = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        // iterate through all "AppPorts"
        for portDict in portDicts {
            // check for protocol
            if portDict[Ports.proto] as! String == proto {
                if let internalPort = portDict[Ports.internal_port] {
                    appPortsByProtocol![String(describing: internalPort)] = portDict
                }
            }
        }
        return appPortsByProtocol
    }
    
    // Return dictionary of TCP AppPorts given in findCloudletReply
    public func getTCPAppPorts(findCloudletReply: [String: AnyObject]) -> [String: [String: Any]]?
    {
        var tcpAppPorts = [String: [String: Any]]()
        // array of dictionaries
        guard let portDicts = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        // iterate through all dictionaries
        for portDict in portDicts {
            // check for protocol
            if portDict[Ports.proto] as! String == Protocol.tcp {
                if let internalPort = portDict[Ports.internal_port] {
                    tcpAppPorts[String(describing: internalPort)] = portDict
                }
            }
        }
        return tcpAppPorts
    }
    
    // Return dictionary of UDP AppPorts given in findCloudletReply
    public func getUDPAppPorts(findCloudletReply: [String: AnyObject]) -> [String: [String: Any]]?
    {
        var udpAppPorts: [String: [String: Any]]?
        // array of dictionaries
        guard let portDicts = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        // iterate through all dictionaries
        for portDict in portDicts {
            // check for protocol
            if portDict[Ports.proto] as! String == Protocol.udp {
                if let internalPort = portDict[Ports.internal_port] {
                    udpAppPorts![String(describing: internalPort)] = portDict
                }
            }
        }
        return udpAppPorts
    }
    
    // Return dictionary of HTTP AppPorts given in findCloudletReply
    public func getHTTPAppPorts(findCloudletReply: [String: AnyObject]) -> [String: [String: Any]]?
    {
        var httpAppPorts: [String: [String: Any]]?
        // array of dictionaries
        guard let portDicts = findCloudletReply[FindCloudletReply.ports] as? [[String: Any]] else {
            return nil
        }
        // iterate through all dictionaries
        for portDict in portDicts {
            // check for protocol
            if portDict[Ports.proto] as! String == Protocol.http {
                if let internalPort = portDict[Ports.internal_port] {
                    httpAppPorts![String(describing: internalPort)] = portDict
                }
            }
        }
        return httpAppPorts
    }
}

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
//  GetPorts.swift
//

import Foundation
//import NSLogger
//import Promises
//import SocketIO
//import Network

extension MatchingEngine {


    // Can get port by any protocol, customized or not
    public func getPortsByProtocol(findCloudletReply: [String: AnyObject], proto: String) -> [String]?
    {
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
    public func getTCPPorts(findCloudletReply: [String: AnyObject]) -> [String]?
    {
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
    public func getUDPPorts(findCloudletReply: [String: AnyObject]) -> [String]?
    {
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
    public func getHTTPPorts(findCloudletReply: [String: AnyObject]) -> [String]?
    {
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
}

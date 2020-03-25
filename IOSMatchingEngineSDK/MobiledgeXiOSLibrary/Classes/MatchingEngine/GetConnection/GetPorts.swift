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

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // Returns the server side fqdn from findCloudletReply with specified port (fqdn prefix based on port)
    public func getAppFqdn(findCloudletReply: FindCloudletReply, port: UInt16) -> String?
    {
        let appFqdn = findCloudletReply.fqdn
        let baseFqdn = appFqdn
        // get fqdn prefix from port dictionary
        guard let fqdnPrefix = state.portToPathPrefixDict[port] else {
            return baseFqdn
        }
        return fqdnPrefix + baseFqdn
    }
    
    // Returns dictionary: key -> internal port, value -> AppPort
    public func getAppPortsByProtocol(findCloudletReply: FindCloudletReply, proto: LProto) -> [UInt16: AppPort]?
    {
        var appPortsByProtocol = [UInt16: AppPort]()
        // array of AppPorts returned in findCloudlet
        let appPorts = findCloudletReply.ports
        // iterate through all "AppPorts"
        for appPort in appPorts {
            // check for protocol
            if appPort.proto == proto {
                let internalPort = UInt16(truncatingIfNeeded: appPort.internal_port)
                appPortsByProtocol[internalPort] = appPort
            }
        }
        return appPortsByProtocol
    }
    
    // Return dictionary of TCP AppPorts given in findCloudletReply
    public func getTCPAppPorts(findCloudletReply: FindCloudletReply) -> [UInt16: AppPort]?
    {
        var tcpAppPorts = [UInt16: AppPort]()
        // array of AppPorts
        let appPorts = findCloudletReply.ports
        // iterate through all AppPorts
        for appPort in appPorts {
            // check for protocol
            if appPort.proto == LProto.L_PROTO_TCP {
                let internalPort = UInt16(truncatingIfNeeded: appPort.internal_port)
                tcpAppPorts[internalPort] = appPort
            }
        }
        return tcpAppPorts
    }
    
    // Return dictionary of UDP AppPorts given in findCloudletReply
    public func getUDPAppPorts(findCloudletReply: FindCloudletReply) -> [UInt16: AppPort]?
    {
        var udpAppPorts = [UInt16: AppPort]()
        // array of AppPorts
        let appPorts = findCloudletReply.ports
        // iterate through all AppPorts
        for appPort in appPorts {
            // check for protocol
            if appPort.proto == LProto.L_PROTO_UDP {
                let internalPort = UInt16(truncatingIfNeeded: appPort.internal_port)
                udpAppPorts[internalPort] = appPort
            }
        }
        return udpAppPorts
    }
    
    // Return dictionary of HTTP AppPorts given in findCloudletReply
    public func getHTTPAppPorts(findCloudletReply: FindCloudletReply) -> [UInt16: AppPort]?
    {
        var httpAppPorts = [UInt16: AppPort]()
        // array of AppPorts
        let appPorts = findCloudletReply.ports
        // iterate through all AppPorts
        for appPort in appPorts {
            // check for protocol
            if appPort.proto == LProto.L_PROTO_HTTP {
                let internalPort = UInt16(truncatingIfNeeded: appPort.internal_port)
                httpAppPorts[internalPort] = appPort
            }
        }
        return httpAppPorts
    }
}

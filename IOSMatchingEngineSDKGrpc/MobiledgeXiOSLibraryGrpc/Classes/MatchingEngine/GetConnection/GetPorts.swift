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

extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    /// Returns dictionary: key -> internal port, value -> AppPort
    public func getAppPortsByProtocol(findCloudletReply: DistributedMatchEngine_FindCloudletReply, proto: DistributedMatchEngine_LProto) throws -> [UInt16: DistributedMatchEngine_AppPort]?
    {
        var appPortsByProtocol = [UInt16: DistributedMatchEngine_AppPort]()
        // array of AppPorts returned in findCloudlet
        let appPorts = findCloudletReply.ports
        // iterate through all "AppPorts"
        for appPort in appPorts {
            // check for protocol
            if appPort.proto == proto {
                // Make sure internal port is a valid port
                if !isValidPort(port: appPort.internalPort) {
                    throw MatchingEngineError.invalidInternalPort
                }
                // truncate Int32 to UInt16
                let internalPort = UInt16(truncatingIfNeeded: appPort.internalPort)
                appPortsByProtocol[internalPort] = appPort
            }
        }
        return appPortsByProtocol
    }
    
    /// Return dictionary of TCP AppPorts given in findCloudletReply
    public func getTCPAppPorts(findCloudletReply: DistributedMatchEngine_FindCloudletReply) throws -> [UInt16: DistributedMatchEngine_AppPort]?
    {
        var tcpAppPorts = [UInt16: DistributedMatchEngine_AppPort]()
        // array of AppPorts
        let appPorts = findCloudletReply.ports
        // iterate through all AppPorts
        for appPort in appPorts {
            // check for protocol
            if appPort.proto == DistributedMatchEngine_LProto.tcp {
                // Make sure internal port is a valid port
                if !isValidPort(port: appPort.internalPort) {
                    throw MatchingEngineError.invalidInternalPort
                }
                // truncate Int32 to UInt16
                let internalPort = UInt16(truncatingIfNeeded: appPort.internalPort)
                tcpAppPorts[internalPort] = appPort
            }
        }
        return tcpAppPorts
    }
    
    /// Return dictionary of UDP AppPorts given in findCloudletReply
    public func getUDPAppPorts(findCloudletReply: DistributedMatchEngine_FindCloudletReply) throws -> [UInt16: DistributedMatchEngine_AppPort]?
    {
        var udpAppPorts = [UInt16: DistributedMatchEngine_AppPort]()
        // array of AppPorts
        let appPorts = findCloudletReply.ports
        // iterate through all AppPorts
        for appPort in appPorts {
            // check for protocol
            if appPort.proto == DistributedMatchEngine_LProto.udp {
                // Make sure internal port is a valid port
                if !isValidPort(port: appPort.internalPort) {
                    throw MatchingEngineError.invalidInternalPort
                }
                // truncate Int32 to UInt16
                let internalPort = UInt16(truncatingIfNeeded: appPort.internalPort)
                udpAppPorts[internalPort] = appPort
            }
        }
        return udpAppPorts
    }
    
    private func isValidPort(port: Int32) -> Bool {
        return (port <= 65535) && (port > 0)
    }
}

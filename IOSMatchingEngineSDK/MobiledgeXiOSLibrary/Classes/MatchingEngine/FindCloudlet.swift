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
//  FindCloudlet.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibrary.MatchingEngine {
    
    // FindCloudletRequest struct
    public struct FindCloudletRequest: Encodable {
        // Required fields
        public var ver: uint
        public var session_cookie: String
        public var carrier_name: String?
        public var gps_location: Loc
        // Optional fields
        public var cell_id: uint?
        public var tags: [String: String]?
    }

    // FindCloudletReply struct
    public struct FindCloudletReply: Decodable {
        // Required fields
        public var ver: uint
        public var status: FindStatus
        public var fqdn: String
        public var ports: [AppPort]
        public var cloudlet_location: Loc
        // Optional fields
        public var tags: [String: String]?
        
        // Values for FindCloudletReply status enum
        public enum FindStatus: String, Decodable {
            case FIND_UNKNOWN = "FIND_UNKNOWN"
            case FIND_FOUND = "FIND_FOUND"
            case FIND_NOTFOUND = "FIND_NOTFOUND"
        }
    }
    
    public enum FindCloudletMode {
        case PROXIMITY
        case PERFORMANCE
        case UNDEFINED
    }
    
    // Carrier name can change depending on cell tower.
    //
    
    /// createFindCloudletRequest
    ///
    /// - Parameters:
    ///   - carrierName: carrierName description
    ///   - gpslocation: gpslocation description
    /// - Returns: API  Dictionary/json
    
    // Carrier name can change depending on cell tower.
    public func createFindCloudletRequest(gpsLocation: Loc, carrierName: String? = "", cellID: uint? = nil, tags: [String: String]? = nil) throws
        -> FindCloudletRequest {
            
        let req = FindCloudletRequest(
            ver: 1,
            session_cookie: state.getSessionCookie() ?? "",
            carrier_name: carrierName ?? getCarrierName(),
            gps_location: gpsLocation,
            cell_id: cellID,
            tags: tags)
            
        try validateFindCloudletRequest(request: req)
        return req
    }
    
    func validateFindCloudletRequest(request: FindCloudletRequest) throws {
        if request.session_cookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
    }
    
    /// API findCloudlet
    ///
    /// Takes a FindCloudlet request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - request: FindCloudletRequest from createFindCloudletRequest.
    /// - Returns: FindCloudletReply
    @available(iOS 13.0, *)
    public func findCloudlet(request: FindCloudletRequest, mode: FindCloudletMode = FindCloudletMode.PROXIMITY) -> Promise<FindCloudletReply> {
        let promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
        
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeRestPort
        
        switch mode {
        case FindCloudletMode.PROXIMITY:
            return findCloudletProximity(host: host, port: port, request: request)
        case FindCloudletMode.PERFORMANCE:
            return findCloudletPerformance(host: host, port: port, request: request)
        default:
            return findCloudletProximity(host: host, port: port, request: request)
        }
    }
    
    // Host and Port overload for findCloudlet
    @available(iOS 13.0, *)
    public func findCloudlet(host: String, port: UInt16, request: FindCloudletRequest, mode: FindCloudletMode = FindCloudletMode.PROXIMITY) -> Promise<FindCloudletReply> {
        
        switch mode {
        case FindCloudletMode.PROXIMITY:
            return findCloudletProximity(host: host, port: port, request: request)
        case FindCloudletMode.PERFORMANCE:
            return findCloudletPerformance(host: host, port: port, request: request)
        default:
            return findCloudletProximity(host: host, port: port, request: request)
        }
    }
    
    /// FindCloudlet
    ///
    /// Calls findCloudletAPI to get findCloudletReply
    /// Calls getAppInstList to find list of cloudlets
    /// Runs NetTest to find nearest cloudlet
    /// Return FindCloudletReply with nearest cloudlet found from NetTest
    /// - Parameters:
    ///   - host: dmeHost either generated or given explicitly
    ///   - port: dmePort either generated or given explicitly
    ///   - request: FindCloudletRequest from createFindCloudletRequest.
    /// - Returns: FindCloudletReply
    @available(iOS 13.0, *)
    private func findCloudletPerformance(host: String, port: UInt16, request: FindCloudletRequest) -> Promise<FindCloudletReply> {
        let promise: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
        var fcReply: FindCloudletReply? = nil
        
        // Promise Chain:
        // 1. FindCloudlet
        // 2. GetAppInstList
        // 3. NetTest
        // 4. Return Modified FindCloudletReply with closest cloudlet according to NetTest
        return findCloudletProximity(host: host, port: port, request: request)
            
        .then { findCloudletReply -> Promise<AppInstListReply> in
            // Make sure we found a cloudlet from FindCloudletReply
            if findCloudletReply.status != FindCloudletReply.FindStatus.FIND_FOUND {
                let appInstPromise = Promise<AppInstListReply>.init(MatchingEngineError.findCloudletFailed)
                return appInstPromise
            }
            // initialize fcReply (to be used later)
            fcReply = findCloudletReply
            
            // Dummy bytes to send to "load" mobile network
            let bytes = Array(repeating: UInt8(1), count: 2048)
            var tags = ["buffer": String(bytes: bytes, encoding: .utf8) ?? ""]
            let appInstRequest = try self.createGetAppInstListRequest(gpsLocation: request.gps_location, carrierName: request.carrier_name, tags: tags)
            return self.getAppInstList(host: host, port: port, request: appInstRequest)
            }
            
        .then { appInstListReply -> Promise<[MobiledgeXiOSLibrary.PerformanceMetrics.Site]> in
            // Check for successful getAppInstList
            if appInstListReply.status != AppInstListReply.AIStatus.AI_SUCCESS || appInstListReply.cloudlets.count == 0 {
                let sitesPromise = Promise<[MobiledgeXiOSLibrary.PerformanceMetrics.Site]>.init(MatchingEngineError.getAppInstListFailed)
                return sitesPromise
            }
            // Initialize list of Sites from the given App instances
            let sites = self.createSitesFromAppInstReply(reply: appInstListReply)
            // Make sure sites is not empty
            if sites.count == 0 {
                let sitesPromise = Promise<[MobiledgeXiOSLibrary.PerformanceMetrics.Site]>.init(MatchingEngineError.unknownAppInsts)
                return sitesPromise
            }
            // Initialize and run NetTest 10 times per site
            let netTest = MobiledgeXiOSLibrary.PerformanceMetrics.NetTest(sites: sites, qos: .background)
            return netTest.runTest()
            }
            
        .then { orderedSites -> Promise<FindCloudletReply> in
            
            // Log list of sites in order
            var idx = 0
            for site in orderedSites {
                os_log("Site %d is %@. Avg is %f. StdDev is %f", log: OSLog.default, type: .debug, idx, site.host ?? site.l7Path ?? "No url for site", site.avg, site.stdDev ?? 0)
                idx += 1
            }
            // Create FindCloudletReply from actual FindCloudletReply and the best site from NetTest
            let findCloudletReply = self.createFindCloudletReplyFromBestSite(findCloudletReply: fcReply!, site: orderedSites[0])
            promise.fulfill(findCloudletReply)
            return promise
            }
            
        .catch { error in
            promise.reject(error)
            return
        }
    }
    
    /// API findCloudlet
    ///
    /// Takes a FindCloudlet request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: FindCloudletRequest from createFindCloudletRequest.
    /// - Returns: FindCloudletReply
    private func findCloudletProximity(host: String, port: UInt16, request: FindCloudletRequest)
        -> Promise<FindCloudletReply>
    {
        os_log("Finding nearest Cloudlet appInsts matching this MatchingEngine client.", log: OSLog.default, type: .debug)
        os_log("======================================================================", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.findcloudletAPI
        
        // postRequest is dispatched to background by default:
        return self.postRequest(uri: urlStr, request: request, type: FindCloudletReply.self)
    }
    
    
    // Modify FindCloudletReply to hold the AppPorts and fqdn from nearest Site
    @available(iOS 13.0, *)
    private func createFindCloudletReplyFromBestSite(findCloudletReply: FindCloudletReply, site: MobiledgeXiOSLibrary.PerformanceMetrics.Site) -> FindCloudletReply {
        let appInst = site.appInst
        
        return FindCloudletReply(
            ver: findCloudletReply.ver,
            status: FindCloudletReply.FindStatus.FIND_FOUND,
            fqdn: appInst!.fqdn,
            ports: appInst!.ports,
            cloudlet_location: site.cloudletLocation ?? Loc(latitude: 0, longitude: 0),
            tags: findCloudletReply.tags
        )
    }
    
    // Create a Site object per appInstance per CloudletLocation returned from AppInstListReply
    // This will be used as the array of Sites for NetTest
    @available(iOS 13.0, *)
    private func createSitesFromAppInstReply(reply: AppInstListReply) -> [MobiledgeXiOSLibrary.PerformanceMetrics.Site] {
        var sites: [MobiledgeXiOSLibrary.PerformanceMetrics.Site] = []
        
        for cloudlet in reply.cloudlets {
            for appInstance in cloudlet.appinstances {
                let appPort = appInstance.ports[0]
                
                switch(appPort.proto) {
                case LProto.L_PROTO_TCP:
                    var site: MobiledgeXiOSLibrary.PerformanceMetrics.Site?
                    site = initTcpSite(appPort: appPort, appInstance: appInstance, numSamples: 10)
                    site!.appInst = appInstance
                    site!.cloudletLocation = cloudlet.gps_location
                    sites.append(site!)
                    break
                    
                case LProto.L_PROTO_UDP:
                    let site = initUdpSite(appPort: appPort, appInstance: appInstance, numSamples: 10)
                    site.appInst = appInstance
                    site.cloudletLocation = cloudlet.gps_location
                    sites.append(site)
                    break
                    
                default:
                    os_log("Unknown protocol %@ from appPort at %@%@.", log: OSLog.default, type: .debug, appPort.proto.rawValue, appPort.fqdn_prefix ?? "", appInstance.fqdn)
                    break
                }
                
            }
        }
        return sites
    }
    
    @available(iOS 13.0, *)
    private func initTcpSite(appPort: AppPort, appInstance: Appinstance, numSamples: Int) -> MobiledgeXiOSLibrary.PerformanceMetrics.Site {
        // initialize host, port, and testType
        let host = (appPort.fqdn_prefix ?? "") + appInstance.fqdn
        let port = appPort.public_port
        let testType = MobiledgeXiOSLibrary.PerformanceMetrics.NetTest.TestType.CONNECT
        
        return MobiledgeXiOSLibrary.PerformanceMetrics.Site(network: "", host: host, port: UInt16(port), testType: testType, numSamples: numSamples)
    }
    
    @available(iOS 13.0, *)
    private func initUdpSite(appPort: AppPort, appInstance: Appinstance, numSamples: Int) -> MobiledgeXiOSLibrary.PerformanceMetrics.Site {
        // initialize host, port, and testType
        let host = (appPort.fqdn_prefix ?? "") + appInstance.fqdn
        let port = appPort.public_port
        let testType = MobiledgeXiOSLibrary.PerformanceMetrics.NetTest.TestType.PING
        
        return MobiledgeXiOSLibrary.PerformanceMetrics.Site(network: "", host: host, port: UInt16(port), testType: testType, numSamples: numSamples)
    }
}

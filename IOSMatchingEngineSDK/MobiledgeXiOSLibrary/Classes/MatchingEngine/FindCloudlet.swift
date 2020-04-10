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
        public var carrier_name: String
        public var gps_location: Loc
        // Optional fields
        public var org_name: String?
        public var app_name: String?
        public var app_vers: String?
        public var cell_id: uint?
        public var tags: [Tag]?
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
        public var tags: [Tag]?
        
        // Values for FindCloudletReply status enum
        public enum FindStatus: String, Decodable {
            case FIND_UNKNOWN = "FIND_UNKNOWN"
            case FIND_FOUND = "FIND_FOUND"
            case FIND_NOTFOUND = "FIND_NOTFOUND"
        }
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
    public func createFindCloudletRequest(gpsLocation: Loc, carrierName: String?,
                                          orgName: String? = nil, appName: String? = nil, appVers: String? = nil, cellID: uint? = nil, tags: [Tag]? = nil)
        -> FindCloudletRequest {
            
        return FindCloudletRequest(
            ver: 1,
            session_cookie: state.getSessionCookie() ?? "",
            carrier_name: carrierName ?? state.carrierName ?? getCarrierName(),
            gps_location: gpsLocation,
            org_name: orgName,
            app_name: appName,
            app_vers: appVers,
            cell_id: cellID,
            tags: tags)
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
    ///   - request: FindCloudlet dictionary, from createFindCloudletReqwuest.
    /// - Returns: API Dictionary/json
    public func findCloudlet(request: FindCloudletRequest) -> Promise<FindCloudletReply>
    {
        let promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()

        let carrierName = state.carrierName
        
        var host: String
        do {
            host = try generateDmeHost(carrierName: carrierName)
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeRestPort
        return findCloudlet(host: host, port: port, request: request)
    }
    
    /// API findCloudlet
    ///
    /// Takes a FindCloudlet request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - host: host override of the dme host server. DME must be reachable from current carrier.
    ///   - port: port override of the dme server port
    ///   - request: FindCloudlet dictionary, from createFindCloudletReqwuest.
    /// - Returns: API Dictionary/json
    public func findCloudlet(host: String, port: UInt16, request: FindCloudletRequest)
        -> Promise<FindCloudletReply>
    {
        os_log("Finding nearest Cloudlet appInsts matching this MatchingEngine client.", log: OSLog.default, type: .debug)
        os_log("======================================================================", log: OSLog.default, type: .debug)
        let promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
        
        let baseuri = generateBaseUri(host: host, port: port)
        let urlStr = baseuri + APIPaths.findcloudletAPI
        
        do
        {
            try validateFindCloudletRequest(request: request)
        }
        catch
        {
            promiseInputs.reject(error) // catch and reject
            return promiseInputs
        }
        
        // postRequest is dispatched to background by default:
        return self.postRequest(uri: urlStr, request: request, type: FindCloudletReply.self)
    }
    
    @available(iOS 13.0, *)
    public func findCloudletNew(host: String, port: UInt16, request: FindCloudletRequest) -> Promise<FindCloudletReply> {
        
        let promise: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
        
        var fcReply: FindCloudletReply? = nil
        
        return findCloudlet(host: host, port: port, request: request)
            
            
        .then { findCloudletReply -> Promise<AppInstListReply> in
            if findCloudletReply.status != FindCloudletReply.FindStatus.FIND_FOUND {
                let appInstPromise = Promise<AppInstListReply>.init(MatchingEngineError.findCloudletFailed)
                return appInstPromise
            }
            fcReply = findCloudletReply
            let appInstRequest = self.createGetAppInstListRequest(gpsLocation: request.gps_location, carrierName: request.carrier_name)
        
            return self.getAppInstList(host: host, port: port, request: appInstRequest)
            }
            
            
        .then { appInstListReply -> Promise<[MobiledgeXiOSLibrary.PerformanceMetrics.Site]> in
            // Check for successful getAppInstList
            if appInstListReply.status != AppInstListReply.AIStatus.AI_SUCCESS || appInstListReply.cloudlets.count == 0 {
                let sitesPromise = Promise<[MobiledgeXiOSLibrary.PerformanceMetrics.Site]>.init(MatchingEngineError.getAppInstListFailed)
                return sitesPromise
            }
            
            print("appInstList in new findCloudlet is \(appInstListReply)")
            let sites = self.createSitesFromAppInstReply(reply: appInstListReply)
            
            let netTest = MobiledgeXiOSLibrary.PerformanceMetrics.NetTest(sites: sites, qos: .background)
            
            return netTest.runTest(numSamples: 10)
            }
            
            
        .then { orderedSites -> Promise<FindCloudletReply> in
            for site in orderedSites {
                print("site name is \(site.host), avg is \(site.avg), stddev is \(site.stdDev)")
            }
            let findCloudletReply = self.createFindCloudletReplyFromBestSite(findCloudletReply: fcReply!, site: orderedSites[0])
            promise.fulfill(findCloudletReply)
            return promise
            }
            
            
        .catch { error in
            promise.reject(error)
            return
        }
    }
    
    @available(iOS 13.0, *)
    func createFindCloudletReplyFromBestSite(findCloudletReply: FindCloudletReply, site: MobiledgeXiOSLibrary.PerformanceMetrics.Site) -> FindCloudletReply {
        
        let appInst = site.appInst
        
        return FindCloudletReply(
            ver: findCloudletReply.ver,
            status: FindCloudletReply.FindStatus.FIND_FOUND,
            fqdn: findCloudletReply.fqdn,
            ports: appInst!.ports,
            cloudlet_location: findCloudletReply.cloudlet_location,
            tags: findCloudletReply.tags
        )
    }
    
    @available(iOS 13.0, *)
    func createSitesFromAppInstReply(reply: AppInstListReply) -> [MobiledgeXiOSLibrary.PerformanceMetrics.Site] {
        
        var sites: [MobiledgeXiOSLibrary.PerformanceMetrics.Site] = []
        
        for cloudlet in reply.cloudlets {
            for appInstance in cloudlet.appinstances {
                let appPort = appInstance.ports[0]
                let host = "\(appPort.fqdn_prefix!)\(appInstance.fqdn)"
                let port = appPort.public_port
                let testType = MobiledgeXiOSLibrary.PerformanceMetrics.NetTest.TestType.CONNECT
                
                // CHECK PROTOCOLS AND L7PATH
                let site = MobiledgeXiOSLibrary.PerformanceMetrics.Site(network: "", host: host, port: UInt16(port), testType: testType, numSamples: 10)
                site.appInst = appInstance
                sites.append(site)
        
            }
        }
        return sites
    }
}

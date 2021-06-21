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

@available(iOS 13.0, *)
extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    /// Two modes to call FindCloudlet. First is Proximity (default) which finds the nearest cloudlet based on gps location with application instance
    /// Second is Performance. This mode will test all cloudlets with application instance deployed to find cloudlet with lowest latency. This mode takes longer to finish because of latency test.
    public enum FindCloudletMode {
        case PROXIMITY
        case PERFORMANCE
        case UNDEFINED
    }
    
    // Carrier name can change depending on cell tower.
    
    /// createFindCloudletRequest
    /// Creates the FindCloudletRequest object that will be used in the FindCloudlet function.
    /// The FindCloudletRequest object wraps the parameters that have been provided to this function.
    ///
    /// - Parameters:
    ///   - carrierName: carrierName
    ///   - gpslocation: gpslocation
    /// - Returns: DistributedMatchEngine_FindCloudletRequest
    public func createFindCloudletRequest(gpsLocation: DistributedMatchEngine_Loc, carrierName: String? = nil, cellID: uint? = nil, tags: [String: String]? = nil) throws
        -> DistributedMatchEngine_FindCloudletRequest {
            
        var req = DistributedMatchEngine_FindCloudletRequest.init()
        req.ver = 1
        req.sessionCookie = state.getSessionCookie() ?? ""
        req.carrierName = carrierName ?? getCarrierName()
        req.gpsLocation = gpsLocation
        req.cellID = cellID ?? 0
        req.tags = tags ?? [String: String]()
            
        try validateFindCloudletRequest(request: req)
        return req
    }
    
    func validateFindCloudletRequest(request: DistributedMatchEngine_FindCloudletRequest) throws {
        if request.sessionCookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
    }
    
    /// API findCloudlet
    /// FindCloudlet returns information needed for the client app to connect to an application backend deployed through MobiledgeX.
    /// If there is an application backend instance found, FindCloudetReply will contain the fqdn of the application backend and an array of AppPorts (with information specific to each application
    /// backend endpoint)
    ///
    /// Takes a FindCloudlet request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - request: DistributedMatchEngine_FindCloudletRequest from createFindCloudletRequest.
    ///   - mode: (Optional): FindCloudletMode, default is PROXIMITY
    /// - Returns: Promise<DistributedMatchEngine_FindCloudletReply>
    @available(iOS 13.0, *)
    public func findCloudlet(request: DistributedMatchEngine_FindCloudletRequest, mode: FindCloudletMode = FindCloudletMode.PROXIMITY) -> Promise<DistributedMatchEngine_FindCloudletReply> {
        let promiseInputs: Promise<DistributedMatchEngine_FindCloudletReply> = Promise<DistributedMatchEngine_FindCloudletReply>.pending()
        
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeGrpcPort
        
        return findCloudlet(host: host, port: port, request: request, mode: mode)
    }
    
    /// FindCloudlet overload with hardcoded DME host and port. Only use for testing.
    @available(iOS 13.0, *)
    public func findCloudlet(host: String, port: UInt16, request: DistributedMatchEngine_FindCloudletRequest, mode: FindCloudletMode = FindCloudletMode.PROXIMITY) -> Promise<DistributedMatchEngine_FindCloudletReply> {
        
        var promise: Promise<DistributedMatchEngine_FindCloudletReply>
        switch mode {
        case FindCloudletMode.PROXIMITY:
            promise = findCloudletProximity(host: host, port: port, request: request)
        case FindCloudletMode.PERFORMANCE:
            promise = Promise<DistributedMatchEngine_FindCloudletReply>.pending()
            findCloudletPerformance(host: host, port: port, request: request).then { performanceReply in
                promise.fulfill(performanceReply.reply)
            }.catch { error in
                promise.reject(error)
            }
        default:
            promise = findCloudletProximity(host: host, port: port, request: request)
        }
        
        // Store lastFindCloudletReply
        self.state.executionQueue.async {
            promise.then { reply in
                self.state.lastFindCloudletReply = reply
                os_log("saved lastFindCloudletReply", log: OSLog.default, type: .debug)
            }
        }
        return promise
    }
    
    struct FindCloudletPerformanceReply {
        var reply: DistributedMatchEngine_FindCloudletReply
        var bestSite: MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site
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
    ///   - request: DistributedMatchEngine_FindCloudletRequest from createFindCloudletRequest.
    /// - Returns: FindCloudletPerformanceReply
    @available(iOS 13.0, *)
    func findCloudletPerformance(host: String, port: UInt16, request: DistributedMatchEngine_FindCloudletRequest) -> Promise<FindCloudletPerformanceReply> {
        let promise: Promise<FindCloudletPerformanceReply> = Promise<FindCloudletPerformanceReply>.pending()
        var aiReply: DistributedMatchEngine_AppInstListReply? = nil
        
        // Dummy bytes to send to "load" mobile network
        let bytes = Array(repeating: UInt8(1), count: 2048)
        let tags = ["buffer": String(bytes: bytes, encoding: .utf8) ?? ""]
        var appInstRequest: DistributedMatchEngine_AppInstListRequest
        
        // Create AppInstListRequest
        do {
            appInstRequest = try self.createGetAppInstListRequest(gpsLocation: request.gpsLocation, carrierName: request.carrierName, tags: tags)
        } catch {
            promise.reject(error)
            return promise
        }
        
        // Promise Chain:
        // 1. GetAppInstList
        // 2. NetTest
        // 3. Return Modified FindCloudletReply with closest cloudlet according to NetTest
        return self.getAppInstList(host: host, port: port, request: appInstRequest)
        .then { appInstListReply -> Promise<[MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site]> in
            aiReply = appInstListReply
            // Check for successful getAppInstList
            if appInstListReply.status != DistributedMatchEngine_AppInstListReply.AIStatus.aiSuccess || appInstListReply.cloudlets.count == 0 {
                let sitesPromise = Promise<[MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site]>.init(MatchingEngineError.getAppInstListFailed)
                return sitesPromise
            }
            // Initialize list of Sites from the given App instances
            let sites = self.createSitesFromAppInstReply(reply: appInstListReply)
            // Make sure sites is not empty
            if sites.count == 0 {
                let sitesPromise = Promise<[MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site]>.init(MatchingEngineError.unknownAppInsts)
                return sitesPromise
            }
            // Initialize and run NetTest 10 times per site
            let netTest = MobiledgeXiOSLibraryGrpc.PerformanceMetrics.NetTest(sites: sites, qos: .background)
            return netTest.runTest()
            }
            
        .then { orderedSites -> Promise<FindCloudletPerformanceReply> in
            
            // Log list of sites in order
            var idx = 0
            for site in orderedSites {
                os_log("Site %d is %@. Avg is %f. StdDev is %f", log: OSLog.default, type: .debug, idx, site.host ?? site.l7Path ?? "No url for site", site.avg, site.stdDev)
                idx += 1
            }
            // Create FindCloudletReply from actual FindCloudletReply and the best site from NetTest
            let findCloudletReply = self.createFindCloudletReplyFromBestSite(appInstListReply: aiReply!, site: orderedSites[0])
            let findCloudletPerformanceReply = FindCloudletPerformanceReply(reply: findCloudletReply, bestSite: orderedSites[0])
            promise.fulfill(findCloudletPerformanceReply)
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
    ///   - request: DistributedMatchEngine_FindCloudletRequest from createFindCloudletRequest.
    /// - Returns: DistributedMatchEngine_FindCloudletReply
    private func findCloudletProximity(host: String, port: UInt16, request: DistributedMatchEngine_FindCloudletRequest)
        -> Promise<DistributedMatchEngine_FindCloudletReply>
    {
        os_log("Finding nearest Cloudlet appInsts matching this MatchingEngine client.", log: OSLog.default, type: .debug)
        os_log("======================================================================", log: OSLog.default, type: .debug)
        
        return Promise<DistributedMatchEngine_FindCloudletReply>(on: self.state.executionQueue) { fulfill, reject in
            let client = MobiledgeXiOSLibraryGrpc.getGrpcClient(host: host, port: port, tlsEnabled: self.tlsEnabled)
            var reply = DistributedMatchEngine_FindCloudletReply.init()
            do {
                reply = try client.apiclient.findCloudlet(request).response.wait()
                fulfill(reply)
            } catch {
                reject(error)
            }
            MobiledgeXiOSLibraryGrpc.closeGrpcClient(client: client)
        }
    }
    
    /// Modify AppInstListReply to hold the AppPorts and fqdn from nearest Site
    @available(iOS 13.0, *)
    private func createFindCloudletReplyFromBestSite(appInstListReply: DistributedMatchEngine_AppInstListReply, site: MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site) -> DistributedMatchEngine_FindCloudletReply {
        let appInst = site.appInst
        
        var reply = DistributedMatchEngine_FindCloudletReply.init()
        reply.ver = appInstListReply.ver
        reply.status = DistributedMatchEngine_FindCloudletReply.FindStatus.findFound
        reply.edgeEventsCookie = appInst!.edgeEventsCookie
        reply.fqdn = appInst!.fqdn
        reply.ports = appInst!.ports
        reply.cloudletLocation = site.cloudletLocation ?? DistributedMatchEngine_Loc.init()
        reply.tags = appInstListReply.tags
        return reply
    }
    
    /// Create a Site object per appInstance per CloudletLocation returned from AppInstListReply
    /// This will be used as the array of Sites for NetTest
    @available(iOS 13.0, *)
    private func createSitesFromAppInstReply(reply: DistributedMatchEngine_AppInstListReply) -> [MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site] {
        var sites: [MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site] = []
        
        for cloudlet in reply.cloudlets {
            for appInstance in cloudlet.appinstances {
                var foundTcpPort = false
                for appPort in appInstance.ports {
                    // Look for a TCP port to do connect/disconnect latency test
                    if appPort.proto == DistributedMatchEngine_LProto.tcp {
                        foundTcpPort = true
                        var site: MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site?
                        site = initConnectSite(appPort: appPort, appInstance: appInstance, numSamples: 10)
                        site!.appInst = appInstance
                        site!.cloudletLocation = cloudlet.gpsLocation
                        sites.append(site!)
                        break
                    }
                }
                if !foundTcpPort {
                    // If no TCP ports, use PING
                    let site = initPingSite(appPort: appInstance.ports[0], appInstance: appInstance, numSamples: 10)
                    site.appInst = appInstance
                    site.cloudletLocation = cloudlet.gpsLocation
                    sites.append(site)
                }
            }
        }
        return sites
    }
    
    @available(iOS 13.0, *)
    private func initConnectSite(appPort: DistributedMatchEngine_AppPort, appInstance: DistributedMatchEngine_Appinstance, numSamples: Int) -> MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site {
        // initialize host, port, and testType
        let host = (appPort.fqdnPrefix ?? "") + appInstance.fqdn
        let port = appPort.publicPort
        let testType = MobiledgeXiOSLibraryGrpc.PerformanceMetrics.NetTest.TestType.CONNECT
        
        return MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site(network: "", host: host, port: UInt16(port), testType: testType, numSamples: numSamples)
    }
    
    @available(iOS 13.0, *)
    private func initPingSite(appPort: DistributedMatchEngine_AppPort, appInstance: DistributedMatchEngine_Appinstance, numSamples: Int) -> MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site {
        // initialize host, port, and testType
        let host = (appPort.fqdnPrefix ?? "") + appInstance.fqdn
        let port = appPort.publicPort
        let testType = MobiledgeXiOSLibraryGrpc.PerformanceMetrics.NetTest.TestType.PING
        
        return MobiledgeXiOSLibraryGrpc.PerformanceMetrics.Site(network: "", host: host, port: UInt16(port), testType: testType, numSamples: numSamples)
    }
}

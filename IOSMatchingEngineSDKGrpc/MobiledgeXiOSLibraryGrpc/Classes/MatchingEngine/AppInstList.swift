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
//  AppInstList.swift
//

import os.log
import Promises

extension MobiledgeXiOSLibraryGrpc.MatchingEngine {
    
    /// createGetAppInstListRequest
    /// Creates the AppInstListRequest object that will be used in GetAppInstList
    ///
    /// - Parameters:
    ///   - gpslocation: A DistributedMatchEngine_Loc with at least longitude and latitude key values.
    ///   - carrierName: Carrier name. This value can change depending on cell tower.
    ///   - cellID: Optional cellID
    ///   - tags: Optional dict
    ///
    /// - Returns: DistributedMatchEngine_AppInstListRequest
    public func createGetAppInstListRequest(gpsLocation: DistributedMatchEngine_Loc, carrierName: String? = nil,  cellID: uint? = nil, tags: [String: String]? = nil) throws -> DistributedMatchEngine_AppInstListRequest {
        
        var req = DistributedMatchEngine_AppInstListRequest.init()
        req.ver = 1
        req.sessionCookie = state.getSessionCookie() ?? ""
        req.carrierName = carrierName ?? getCarrierName()
        req.gpsLocation = gpsLocation
        req.cellID = cellID ?? 0
        req.tags = tags ?? [String: String]()
        
        try validateAppInstListRequest(request: req)
        return req
    }
    
    func validateAppInstListRequest(request: DistributedMatchEngine_AppInstListRequest) throws {
        if request.sessionCookie == "" {
            throw MatchingEngineError.missingSessionCookie
        }
        let _ = try validateGpsLocation(gpsLocation: request.gpsLocation)
    }
    
    /// API getAppInstList
    /// Returns a list of the developer's backend instances deployed on the specified carrier's network.
    /// If carrier was "", returns all backend instances regardless of carrier network.
    /// This is used internally in FindCloudlet Performance mode to grab the list of cloudlets to test.
    ///
    /// - Parameters:
    ///   - request: DistributedMatchEngine_AppInstListRequest from createGetAppInstListRequest
    ///
    /// - Returns: Promise<DistributedMatchEngine_AppInstListReply>
    public func getAppInstList(request: DistributedMatchEngine_AppInstListRequest) -> Promise<DistributedMatchEngine_AppInstListReply> {
        let promiseInputs: Promise<DistributedMatchEngine_AppInstListReply> = Promise<DistributedMatchEngine_AppInstListReply>.pending()
                
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeGrpcPort
        
        return getAppInstList(host: host, port: port, request: request)
    }
    
    /// GetAppInstList overload with hardcoded DME host and port. Only use for testing.
    public func getAppInstList(host: String, port: UInt16, request: DistributedMatchEngine_AppInstListRequest)
        -> Promise<DistributedMatchEngine_AppInstListReply> {
        os_log("Finding nearby appInsts matching this MatchingEngine client.", log: OSLog.default, type: .debug)
        os_log("============================================================", log: OSLog.default, type: .debug)
        
        return Promise<DistributedMatchEngine_AppInstListReply>(on: self.state.executionQueue) { fulfill, reject in
            let client = MobiledgeXiOSLibraryGrpc.MatchingEngine.getGrpcClient(host: host, port: port, tlsEnabled: self.tlsEnabled)
            var reply = DistributedMatchEngine_AppInstListReply.init()
            do {
                reply = try client.apiclient.getAppInstList(request).response.wait()
                fulfill(reply)
            } catch {
                reject(error)
            }
            MobiledgeXiOSLibraryGrpc.MatchingEngine.closeGrpcClient(client: client)
        }
    }
}

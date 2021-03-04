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
//  RegisterAndFindCloudlet.swift
//

import Promises

extension MobiledgeXiOSLibrary.MatchingEngine
{

    /// registerAndFIndCloudlet
    /// FindCloudlet returns information needed for the client app to connect to an application backend deployed through MobiledgeX.
    /// If there is an application backend instance found, FindCloudetReply will contain the fqdn of the application backend and an array of AppPorts (with information specific to each application
    /// backend endpoint)
    ///
    /// Takes a FindCloudlet request, and contacts the specified Distributed MatchingEngine host and port
    /// for the current carrier, if any.
    /// - Parameters:
    ///   - orgName: orgName
    ///   - appName: appName
    ///   - appVers: appVers
    ///   - gpsLocation: Loc
    ///   - carrierName: Optional carrierName
    ///   - authToken: Optional authToken
    ///   - cellID: Optional cellID
    ///   - tags: Optional dict
    ///   - mode: Optional FindCloudletMode (default to Proximity)
    /// - Returns: Promise<FindCloudletReply>
    @available(iOS 13.0, *)
    public func registerAndFindCloudlet(orgName: String, appName: String?, appVers: String?, gpsLocation: Loc, carrierName: String? = "", authToken: String? = nil, cellID: UInt32? = nil, tags: [String: String]? = nil, mode: FindCloudletMode = FindCloudletMode.PROXIMITY) -> Promise<FindCloudletReply> {
        
        let promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
        
        var host: String
        do {
            host = try generateDmeHostAddress()
        } catch {
            promiseInputs.reject(error)
            return promiseInputs
        }
        let port = DMEConstants.dmeRestPort
        
        return registerAndFindCloudlet(host: host, port: port, orgName: orgName, appName: appName, appVers: appVers, gpsLocation: gpsLocation,  carrierName: carrierName, authToken: authToken, cellID: cellID, tags: tags, mode: mode)
    }
    
    /// registerAndFindCloudlet overload with hardcoded DME host and port. Only use for testing. This API cannot be used for Non-Platform APPs.
    @available(iOS 13.0, *)
    public func registerAndFindCloudlet(host: String, port: UInt16, orgName: String, appName: String?, appVers: String?, gpsLocation: Loc,  carrierName: String? = "", authToken: String? = nil, cellID: UInt32? = nil, tags: [String: String]? = nil, mode: FindCloudletMode = FindCloudletMode.PROXIMITY) -> Promise<FindCloudletReply> {
        
        var promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
        
        let registerRequest = self.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, authToken: authToken, cellID: cellID, tags: tags)
        
        promiseInputs = self.registerClient(host: host, port: port, request: registerRequest)
        .then { registerClientReply -> Promise<FindCloudletReply> in
                
            let promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
                
            if registerClientReply.status != ReplyStatus.RS_SUCCESS {
                    promiseInputs.reject(MatchingEngineError.registerFailed)
                    return promiseInputs
            }
                
            let findCloudletRequest = try self.createFindCloudletRequest(gpsLocation: gpsLocation, carrierName: carrierName, cellID: cellID, tags: tags)
                
            return self.findCloudlet(host: host, port: port, request: findCloudletRequest, mode: mode)
        }.catch { error in
            promiseInputs.reject(error)
        }
        
        return promiseInputs
    }
}

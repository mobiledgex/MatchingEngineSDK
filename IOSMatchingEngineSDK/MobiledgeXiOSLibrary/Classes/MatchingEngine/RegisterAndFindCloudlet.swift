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

    @available(iOS 13.0, *)
    public func registerAndFindCloudlet(orgName: String, gpsLocation: Loc, appName: String? = nil, appVers: String? = nil, carrierName: String? = "",authToken: String? = nil, uniqueIDType: IDTypes? = nil, uniqueID: String? = nil, cellID: UInt32? = nil, tags: [Tag]? = nil) -> Promise<FindCloudletReply> {
                
        let registerRequest = self.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        return self.registerClient(request: registerRequest)
        .then { registerClientReply -> Promise<FindCloudletReply> in
            
            let promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
            
            if registerClientReply.status != ReplyStatus.RS_SUCCESS {
                promiseInputs.reject(MatchingEngineError.registerFailed)
                return promiseInputs
            }
            
            let findCloudletRequest = self.createFindCloudletRequest(gpsLocation: gpsLocation, carrierName: carrierName, cellID: cellID, tags: tags)
            
            return self.findCloudlet(request: findCloudletRequest)
        }
    }
    
    @available(iOS 13.0, *)
    public func registerAndFindCloudlet(host: String, port: UInt16, orgName: String, appName: String?, appVers: String?, gpsLocation: Loc, carrierName: String? = "", authToken: String? = nil, uniqueIDType: IDTypes? = nil, uniqueID: String? = nil, cellID: UInt32? = nil, tags: [Tag]? = nil) -> Promise<FindCloudletReply> {
        
        let registerRequest = self.createRegisterClientRequest(orgName: orgName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        return self.registerClient(host: host, port: port, request: registerRequest)
            .then { registerClientReply -> Promise<FindCloudletReply> in
                
                let promiseInputs: Promise<FindCloudletReply> = Promise<FindCloudletReply>.pending()
                
                if registerClientReply.status != ReplyStatus.RS_SUCCESS {
                    promiseInputs.reject(MatchingEngineError.registerFailed)
                    return promiseInputs
                }
                
                let findCloudletRequest = self.createFindCloudletRequest(gpsLocation: gpsLocation, carrierName: carrierName, cellID: cellID, tags: tags)
                
                return self.findCloudlet(host: host, port: port, request: findCloudletRequest)
        }
    }
}

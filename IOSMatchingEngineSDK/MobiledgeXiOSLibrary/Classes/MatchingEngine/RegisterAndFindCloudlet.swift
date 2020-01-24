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

    public func registerAndFindCloudlet(devName: String, appName: String?, appVers: String?, carrierName: String?, authToken: String?, gpsLocation: [String: Any], uniqueIDType: String?, uniqueID: String?, cellID: UInt32?, tags: [[String: String]]?) -> Promise<[String: AnyObject]> {
                
        let registerRequest = self.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken, uniqueIDType: uniqueIDType, uniqueID: uniqueID, cellID: cellID, tags: tags)
        
        return self.registerClient(request: registerRequest)
        .then { registerClientReply -> Promise<[String: AnyObject]> in
            
            let promiseInputs: Promise<[String: AnyObject]> = Promise<[String: AnyObject]>.pending()
            
            guard let status = registerClientReply[RegisterClientReply.status] as? String else {
                promiseInputs.reject(MatchingEngineError.registerFailed)
                return promiseInputs
            }
            if status != DMEConstants.registerClientSuccess {
                promiseInputs.reject(MatchingEngineError.registerFailed)
                return promiseInputs
            }
            
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName, gpsLocation: gpsLocation, devName: devName, appName: appName, appVers: appVers, cellID: cellID, tags: tags)
            
            return self.findCloudlet(request: findCloudletRequest)
        }
    }
}

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
//  RegisterAndFindCloudlet.swift
//

import Foundation
import NSLogger
import Promises

extension MatchingEngine
{

    public func registerAndFindCloudlet(devName: String?, appName: String?, appVers: String?, carrierName: String?, authToken: String?, gpsLocation: [String: Any]) -> Promise<[String: AnyObject]> {
                
        let registerRequest = self.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken)
        
        return self.registerClient(request: registerRequest)
        .then { registerClientReply -> Promise<[String: AnyObject]> in
            let findCloudletRequest = self.createFindCloudletRequest(carrierName: carrierName!, gpsLocation: gpsLocation, devName: devName!, appName: appName, appVers: appVers)
            return self.findCloudlet(request: findCloudletRequest)
        }
    }
}

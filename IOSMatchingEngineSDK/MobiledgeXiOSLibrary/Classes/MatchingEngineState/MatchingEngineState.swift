
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
//  MatchingEngineState.swift
//

import Foundation
import CoreTelephony
import os.log

extension MobiledgeXiOSLibrary {
    
    public class MatchingEngineState {
        
        var DEBUG: Bool = true
        
        // Used to look at subscriber and cellular data info (Developer should implement callbacks in case SIM card changes)
        public var networkInfo: CTTelephonyNetworkInfo
        public var carrierName: String?
        public var ctCarriers: [String: CTCarrier]?
        public var lastCarrier: CTCarrier?
        
        public var closestCloudlet = ""
        
        // Used to correlate port to Path Prefix from findCloudletReply
        var portToPathPrefixDict = [String: String]()
            
        // Just standard GCD Queues to dispatch promises into, user initiated priority.
        public var executionQueue = DispatchQueue.global(qos: .default)
        
        public var useWifiOnly: Bool = false
        
        init()
        {
            print(Bundle.main.object)
            networkInfo = CTTelephonyNetworkInfo()
        }
        
        public var appName: String
        {
            get
            {
                return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
            }
        }
        
        public var appVersion: String
        {
            get
            {
                return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            }
        }
        
        private var sessionCookie: String?
        private var tokenServerUri: String?
        private var tokenServerToken: String?
        
        var deviceGpsLocation: [String: AnyObject]?
        
        // Various known states (should create non-dictionary classes)
        var verifyLocationResult: [String: AnyObject]?
        var location = [String: Any]()
        
        public func setUseWifiOnly(enabled: Bool) {
            useWifiOnly = enabled
        }
        
        public func isUseWifiOnly() -> Bool {
            return useWifiOnly
        }
        
        func setSessionCookie(sessionCookie: String?)
        {
            self.sessionCookie = sessionCookie
        }
        
        func getSessionCookie() -> String?
        {
            return self.sessionCookie
        }
        
        func setTokenServerUri(tokenServerUri: String?)
        {
            self.tokenServerUri = tokenServerUri
        }
        
        func getTokenServerUri() -> String?
        {
            return self.tokenServerUri
        }
        
        func setTokenServerToken(tokenServerToken: String?)
        {
            self.tokenServerToken = tokenServerToken
        }
        
        func getTokenServerToken() -> String?
        {
            return self.tokenServerToken
        }
        
        // Returns Array with MCC in zeroth index and MNC in first index
        func getMCCMNC() throws -> [String]
        {
            if #available(iOS 12.0, *) {
                ctCarriers = networkInfo.serviceSubscriberCellularProviders
            } else {
                throw MobiledgeXiOSLibrary.DmeDnsError.outdatedIOS
                // Fallback on earlier versions
            }
            if #available(iOS 12.1, *) {
                networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = { (carrier) in
                    self.ctCarriers = self.networkInfo.serviceSubscriberCellularProviders
                    if self.ctCarriers !=  nil {
                        self.lastCarrier = self.ctCarriers![carrier]
                    }
                };
            }
              
            lastCarrier = networkInfo.subscriberCellularProvider
            if lastCarrier == nil {
                os_log("Cannot find Subscriber Cellular Provider Info", log: OSLog.default, type: .debug)
                throw MobiledgeXiOSLibrary.DmeDnsError.missingCellularProviderInfo
            }
            guard let mcc = lastCarrier!.mobileCountryCode else {
                os_log("Cannot get Mobile Country Code", log: OSLog.default, type: .debug)
                throw MobiledgeXiOSLibrary.DmeDnsError.missingMCC
            }
            guard let mnc = lastCarrier!.mobileNetworkCode else {
                os_log("Cannot get Mobile Network Code", log: OSLog.default, type: .debug)
                throw MobiledgeXiOSLibrary.DmeDnsError.missingMNC
            }
            
            return [mcc, mnc]
        }
    }
}

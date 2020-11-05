
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
//  MatchingEngineState.swift
//

import UIKit
import Foundation
import os.log
import AdSupport

extension MobiledgeXiOSLibrary {
    
    public class MatchingEngineState {
                
        // Information about state of device
        public var device: UIDevice
        
        public var closestCloudlet = ""
        
        // Used to correlate port to Path Prefix from findCloudletReply
        var portToPathPrefixDict = [UInt16: String]()
            
        // Just standard GCD Queues to dispatch promises into, user initiated priority.
        public var executionQueue = DispatchQueue.global(qos: .default)
        
        private var useWifiOnly: Bool = false
        
        public var deviceManufacturer = "Apple"
        
        init() {
            print(Bundle.main.object)
            device = UIDevice.init()
        }
        
        public var appName: String {
            get {
                return Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? ""
            }
        }
        
        public var appVersion: String {
            get {
                return Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
            }
        }
        
        // App specific UUID
        var uuid: String {
            get {
                let uuid = ASIdentifierManager.shared().advertisingIdentifier
                return uuid.uuidString.utf8.description
            }
        }
        
        var uniqueIDType: String {
            get {
                return "\(deviceManufacturer):\(device.model):HASHED_ID"
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
        
        func setSessionCookie(sessionCookie: String?) {
            self.sessionCookie = sessionCookie
        }
        
        func getSessionCookie() -> String? {
            return self.sessionCookie
        }
        
        func setTokenServerUri(tokenServerUri: String?) {
            self.tokenServerUri = tokenServerUri
        }
        
        func getTokenServerUri() -> String? {
            return self.tokenServerUri
        }
        
        func setTokenServerToken(tokenServerToken: String?) {
            self.tokenServerToken = tokenServerToken
        }
        
        func getTokenServerToken() -> String? {
            return self.tokenServerToken
        }
    }
}

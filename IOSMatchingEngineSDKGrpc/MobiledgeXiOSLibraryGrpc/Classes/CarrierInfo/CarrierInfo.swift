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
//  CarrierInfo.swift
//

import CoreTelephony
import os.log

extension MobiledgeXiOSLibraryGrpc {

    class CarrierInfo {
        
        public enum CarrierInfoError: Error {
            case missingMCC
            case missingMNC
            case missingISOCountryCode
            case missingCellularProviderInfo
            case missingCarrierName
        }
        
        // Used to look at subscriber and cellular data info (Developer should implement callbacks in case SIM card changes)
        static var networkInfo = CTTelephonyNetworkInfo()
        static var ctCarriers: [String: CTCarrier]?
        static var firstCarrier: CTCarrier?

        static func getISOCountryCode() throws -> String {
            let carrier = try getCarrier()
            guard let isoCountryCode = carrier.isoCountryCode else {
                os_log("Cannot get iso Country code", log: OSLog.default, type: .debug)
                throw CarrierInfoError.missingISOCountryCode
            }
            return isoCountryCode
        }
        
        static func getCarrierName() throws -> String {
            let carrier = try getCarrier()
            guard let carrierName = carrier.carrierName else {
                os_log("Cannot get iso Country code", log: OSLog.default, type: .debug)
                throw CarrierInfoError.missingCarrierName
            }
            return carrierName
        }

        // Returns Array with MCC in zeroth index and MNC in first index
        static func getMCCMNC() throws -> [String] {
            let carrier = try getCarrier()
            guard let mcc = carrier.mobileCountryCode else {
                os_log("Cannot get Mobile Country Code", log: OSLog.default, type: .debug)
                throw CarrierInfoError.missingMCC
            }
            guard let mnc = carrier.mobileNetworkCode else {
                os_log("Cannot get Mobile Network Code", log: OSLog.default, type: .debug)
                throw CarrierInfoError.missingMNC
            }
            
            return [mcc, mnc]
        }
        
        private static func getCarrier() throws -> CTCarrier {
            if #available(iOS 12.0, *) {
                ctCarriers = networkInfo.serviceSubscriberCellularProviders
            } else {
                os_log("IOS is outdated. Need 12.0+", log: OSLog.default, type: .debug)
                throw MobiledgeXError.outdatedIOS(requiredIOS: 12, action: "getCarrier")
                // Fallback on earlier versions
            }
            if #available(iOS 12.1, *) {
                networkInfo.serviceSubscriberCellularProvidersDidUpdateNotifier = { (carrier) in
                    self.ctCarriers = self.networkInfo.serviceSubscriberCellularProviders
                    if self.ctCarriers !=  nil {
                        self.firstCarrier = self.ctCarriers![carrier]
                    }
                };
            }
            
            firstCarrier = ctCarriers?.first?.value
            guard let carrier = firstCarrier else {
                os_log("Cannot find Subscriber Cellular Provider Info", log: OSLog.default, type: .debug)
                throw CarrierInfoError.missingCellularProviderInfo
            }
            return carrier
        }
        
        static func getDataNetworkType() -> String? {
            return networkInfo.serviceCurrentRadioAccessTechnology?.first?.value
        }
    }
}

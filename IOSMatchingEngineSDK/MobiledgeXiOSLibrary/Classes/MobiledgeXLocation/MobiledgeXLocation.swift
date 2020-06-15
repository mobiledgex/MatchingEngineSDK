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
//  MobiledgeXLocation.swift
//

import CoreLocation
import os.log
import Promises

extension MobiledgeXiOSLibrary {
    
    public class MobiledgeXLocation {
        
        public enum ServiceType {
            case Visits
            case SignificantChange
            case Standard
        }
        
        public enum MobiledgeXLocationError: Error {
            case unableToFindPlacemark
            case unableToFindCountry
        }

        static var mobiledgeXLocationManager = MobiledgeXLocationManager()
        static var currServiceType = ServiceType.Visits
        
        public static func startLocationServices(serviceType: ServiceType = ServiceType.Visits) {
            currServiceType = serviceType
            // Stop previous Location Manager
            mobiledgeXLocationManager.stopMonitoring()
            // Set specified location service type
            mobiledgeXLocationManager.setServiceType(serviceType: currServiceType)
            // Check permissions before calling
            if !checkPermissions() {
                os_log("Request location permissions before staring location services", log: OSLog.default, type: .debug)
                return
            }
            // Start monitoring for location
            mobiledgeXLocationManager.startMonitoring()
        }
        
        // Checks for Location Permissions (called before Location Services is started)
        public static func checkPermissions() -> Bool {
            if CLLocationManager.locationServicesEnabled() {
                let authStatus = CLLocationManager.authorizationStatus()
                switch authStatus {
                    case .notDetermined, .restricted, .denied:
                        os_log("No access: %@", log: OSLog.default, type: .debug, String(describing: authStatus))
                        return false
                    case .authorizedAlways, .authorizedWhenInUse:
                        os_log("Access: %@", log: OSLog.default, type: .debug, String(describing: authStatus.rawValue))
                        return true
                    @unknown default:
                        os_log("Unknown access: %@", log: OSLog.default, type: .debug, String(describing: authStatus))
                        return false
                }
            } else {
                os_log("Location services are not enabled", log: OSLog.default, type: .debug)
                return false
            }
        }
        
        // Returns the last location in the form of a MobiledgeXiOSLibrary.MatchingEngine.Loc object
        public static func getLastLocation() -> MobiledgeXiOSLibrary.MatchingEngine.Loc {
            return convertCLLocationToMobiledgeXLocation(location: mobiledgeXLocationManager.lastLocation!)
        }
        
        // Returns the ISO country code of the last location
        public static func getLastISOCountryCode() -> Promise<String> {
            return mobiledgeXLocationManager.getISOCountryCodeFromLocation(location: mobiledgeXLocationManager.lastLocation!)
        }
        
        // Helper function that converts CLLocation object to object that can be used in MatchingEngine calls
        private static func convertCLLocationToMobiledgeXLocation(location: CLLocation) -> MobiledgeXiOSLibrary.MatchingEngine.Loc {
            let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
            // loc.altitude = location.altitude.advanced(by: 0)
            // location.timestamp.
            return loc
        }
    }
}


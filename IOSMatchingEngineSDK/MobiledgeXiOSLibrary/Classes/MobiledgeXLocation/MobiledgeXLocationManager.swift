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
    
    class MobiledgeXLocationManager: NSObject, CLLocationManagerDelegate {
        
        var locationManager: CLLocationManager
        var serviceType: MobiledgeXLocation.ServiceType = MobiledgeXLocation.ServiceType.Visits
        var geocoder = CLGeocoder()

        
        var lastLocation: CLLocation? = nil
        
        override init() {
            locationManager = CLLocationManager()
            super.init()
            locationManager.delegate = self
        }
        
        func setServiceType(serviceType: MobiledgeXLocation.ServiceType) {
            self.serviceType = serviceType
        }
        
        // throw an error if not available
        func startMonitoring() {
            switch serviceType {
            case MobiledgeXLocation.ServiceType.Visits:
                locationManager.startMonitoringVisits()
            case MobiledgeXLocation.ServiceType.SignificantChange:
                if !CLLocationManager.significantLocationChangeMonitoringAvailable() {
                    // The device does not support this service.
                    // throw Error("")
                    return
                }
                locationManager.startMonitoringSignificantLocationChanges()
            case MobiledgeXLocation.ServiceType.Standard:
                locationManager.startUpdatingLocation()
            }
            
            lastLocation = locationManager.location
        }
        
        func stopMonitoring() {
            switch serviceType {
            case MobiledgeXLocation.ServiceType.Visits:
                locationManager.stopMonitoringVisits()
            case MobiledgeXLocation.ServiceType.SignificantChange:
                locationManager.stopMonitoringSignificantLocationChanges()
            case MobiledgeXLocation.ServiceType.Standard:
                locationManager.stopUpdatingLocation()
            }
        }
        
        // ServiceType.Visit delegate
        func locationManager(_ manager: CLLocationManager, didVisit visit: CLVisit) {
            lastLocation = manager.location
            os_log("Visited location was at Longitude: %@ and Latitude: %@. Time was %@", log: OSLog.default, type: .debug, visit.coordinate.longitude.description, visit.coordinate.latitude.description, visit.arrivalDate.description)
        }
        
        // ServiceType.SignificantChange and ServiceType.Standard delegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            lastLocation = locations.last!
            os_log("Last location was at Longitude: %@ and Latitude: %@. Time was %@", log: OSLog.default, type: .debug, lastLocation!.coordinate.latitude.description, lastLocation!.coordinate.latitude.description, lastLocation!.timestamp.description)
        }
        
        // Error delegate
        func locationManager(_ manager: CLLocationManager,  didFailWithError error: Error) {
           /*if error.code == .denied {
              // Location updates are not authorized.
              locationManager.stopMonitoringVisits()
              return
           }*/
            stopMonitoring()
           // Notify the user of any errors.
        }
        
        // Helper function to get Country from GPS Coordinates
        func getISOCountryCodeFromLocation(location: CLLocation) -> Promise<String> {
            let countryPromise: Promise<String> = Promise<String>.pending()
            // Look up the location and pass it to the completion handler
            CLGeocoder().reverseGeocodeLocation(location,
                        completionHandler: { (placemarks, error) in
                if error == nil {
                    let firstLocation = placemarks?[0]
                    guard let _ = firstLocation else {
                        countryPromise.reject(MobiledgeXLocation.MobiledgeXLocationError.unableToFindPlacemark)
                        return
                    }
                    guard let _ = firstLocation!.isoCountryCode else {
                    countryPromise.reject(MobiledgeXLocation.MobiledgeXLocationError.unableToFindCountry)
                        return
                    }
                    countryPromise.fulfill(firstLocation!.isoCountryCode!)
                }
                else {
                    // An error occurred during geocoding.
                    countryPromise.reject(error!)
                }
            })
            return countryPromise
        }
    }
}

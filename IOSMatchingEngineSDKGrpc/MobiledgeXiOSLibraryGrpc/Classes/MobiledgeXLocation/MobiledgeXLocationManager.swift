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

extension MobiledgeXiOSLibraryGrpc {
    
    class MobiledgeXLocationManager: NSObject, CLLocationManagerDelegate {
        
        var locationManager: CLLocationManager
        var serviceType: MobiledgeXLocation.ServiceType = MobiledgeXLocation.ServiceType.Visits
        var geocoder: CLGeocoder

        var lastLocation: CLLocation? = nil
        var isoCountryCode: String? = nil
        
        override init() {
            locationManager = CLLocationManager()
            geocoder = CLGeocoder()
            super.init()
            locationManager.delegate = self
        }
        
        func setServiceType(serviceType: MobiledgeXLocation.ServiceType) {
            self.serviceType = serviceType
        }
        
        func startMonitoring() -> Promise<Bool> {
            let startPromise: Promise<Bool> = Promise<Bool>.pending()
            // Start Monitoring Location based on Service Type
            switch serviceType {
            case MobiledgeXLocation.ServiceType.Visits:
                locationManager.startMonitoringVisits()
            case MobiledgeXLocation.ServiceType.SignificantChange:
                if !CLLocationManager.significantLocationChangeMonitoringAvailable() {
                    os_log("The device does not support Significant location change monitoring service.", log: OSLog.default, type: .error)
                    startPromise.fulfill(false)
                    return startPromise
                }
                locationManager.startMonitoringSignificantLocationChanges()
            case MobiledgeXLocation.ServiceType.Standard:
                locationManager.startUpdatingLocation()
            }
            // Initialize first lastLocation
            lastLocation = locationManager.location
            // Initialize first ISOCountryCode
            if lastLocation != nil {
                getISOCountryCodeFromLocation(location: lastLocation!, startPromise: startPromise)
            }
            return startPromise
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
            getISOCountryCodeFromLocation(location: lastLocation!)
            os_log("Visited location was at Longitude: %@ and Latitude: %@. Time was %@", log: OSLog.default, type: .debug, visit.coordinate.longitude.description, visit.coordinate.latitude.description, visit.arrivalDate.description)
        }
        
        // ServiceType.SignificantChange and ServiceType.Standard delegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            lastLocation = locations.last!
            getISOCountryCodeFromLocation(location: lastLocation!)
            os_log("Last location was at Longitude: %@ and Latitude: %@. Time was %@", log: OSLog.default, type: .debug, lastLocation!.coordinate.latitude.description, lastLocation!.coordinate.latitude.description, lastLocation!.timestamp.description)
        }
        
        // Error delegate
        func locationManager(_ manager: CLLocationManager,  didFailWithError error: Error) {
            os_log("LocationServices failed with %@", log: OSLog.default, type: .error, error.localizedDescription)
            stopMonitoring()
        }
        
        // Helper function to get Country from GPS Coordinates
        // Optional StartPromise parameters. This is so that ISOCountryCode is filled in before StartLocation returns
        func getISOCountryCodeFromLocation(location: CLLocation, startPromise: Promise<Bool>? = nil) {
            // Look up the location and pass it to the completion handler
            geocoder.reverseGeocodeLocation(lastLocation!,
                        completionHandler: { (placemarks, error) in
                if error == nil {
                    let firstLocation = placemarks?[0]
                    guard let _ = firstLocation else {
                        if let _ = startPromise {
                            startPromise!.reject(MobiledgeXLocation.MobiledgeXLocationError.unableToFindPlacemark)
                        }
                        os_log("Unable to reverse geocode location. %@", log: OSLog.default, type: .error, MobiledgeXLocation.MobiledgeXLocationError.unableToFindPlacemark.localizedDescription)
                        return
                    }
                    guard let _ = firstLocation!.isoCountryCode else {
                        if let _ = startPromise {
                            startPromise!.reject(MobiledgeXLocation.MobiledgeXLocationError.unableToFindCountry)
                        }
                        os_log("Unable to reverse geocode location. %@", log: OSLog.default, type: .error, MobiledgeXLocation.MobiledgeXLocationError.unableToFindCountry.localizedDescription)
                        return
                    }
                    self.isoCountryCode = firstLocation!.isoCountryCode
                    if let _ = startPromise {
                        startPromise!.fulfill(true)
                    }
                    return
                }
                else {
                    // An error occurred during geocoding.
                    if let _ = startPromise {
                        startPromise!.reject(error!)
                    }
                    os_log("Unable to reverse geocode location. %@", log: OSLog.default, type: .error, error!.localizedDescription)
                }
            })
        }
    }
}

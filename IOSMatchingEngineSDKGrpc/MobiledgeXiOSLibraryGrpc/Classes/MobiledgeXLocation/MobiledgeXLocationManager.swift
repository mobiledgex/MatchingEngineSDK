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
//  MobiledgeXLocationManager.swift
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
        
        let getLocationQueue = DispatchQueue(label: "getLocationQueue") // used to sync lastLocation across threads
        
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
            // Initialize first location
            let firstLocation = locationManager.location
            return updateLastLocation(location: firstLocation)
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
            let newLocation = manager.location
            updateLastLocation(location: newLocation).then { success in
                if success {
                    os_log("Visited location was at Longitude: %@ and Latitude: %@. Time was %@", log: OSLog.default, type: .debug, visit.coordinate.longitude.description, visit.coordinate.latitude.description, visit.arrivalDate.description)
                } else {
                    os_log("Could not update last visited location", log: OSLog.default, type: .debug)
                }
            }.catch { error in
                os_log("Could not update last visited location. Error is %@", log: OSLog.default, type: .debug, error.localizedDescription)
            }
        }
        
        // ServiceType.SignificantChange and ServiceType.Standard delegate
        func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
            let newLocation = locations.last
            updateLastLocation(location: newLocation).then { success in
                if success {
                    os_log("Last location was at Longitude: %@ and Latitude: %@. Time was %@", log: OSLog.default, type: .debug, newLocation!.coordinate.latitude.description, newLocation!.coordinate.latitude.description, newLocation!.timestamp.description)
                } else {
                    os_log("Could not update last location", log: OSLog.default, type: .debug)
                }
            }.catch { error in
                os_log("Could not update last location. Error is %@", log: OSLog.default, type: .debug, error.localizedDescription)
            }
        }
        
        // Error delegate
        func locationManager(_ manager: CLLocationManager,  didFailWithError error: Error) {
            os_log("LocationServices failed with %@", log: OSLog.default, type: .error, error.localizedDescription)
            stopMonitoring()
        }
        
        // Helper function to get Country from GPS Coordinates
        // Optional StartPromise parameters. This is so that ISOCountryCode is filled in before StartLocation returns
        // Should only be called by updateLastLocation so that self.isoCountryCode is stored safely
        func getISOCountryCodeFromLocation(location: CLLocation) -> Promise<String> {
            let promise: Promise<String> = Promise<String>.pending()
            // Look up the location and pass it to the completion handler
            geocoder.reverseGeocodeLocation(location,
                        completionHandler: { (placemarks, error) in
                if error == nil {
                    let firstLocation = placemarks?[0]
                    guard let location = firstLocation else {
                        promise.reject(MobiledgeXLocation.MobiledgeXLocationError.unableToFindPlacemark)
                        os_log("Unable to reverse geocode location. %@", log: OSLog.default, type: .error, MobiledgeXLocation.MobiledgeXLocationError.unableToFindPlacemark.localizedDescription)
                        return
                    }
                    guard let isoCountryCode = location.isoCountryCode else {
                        promise.reject(MobiledgeXLocation.MobiledgeXLocationError.unableToFindCountry)
                        os_log("Unable to reverse geocode location. %@", log: OSLog.default, type: .error, MobiledgeXLocation.MobiledgeXLocationError.unableToFindCountry.localizedDescription)
                        return
                    }
                    promise.fulfill(isoCountryCode)
                    return
                }
                else {
                    // An error occurred during geocoding.
                    promise.reject(error!)
                    os_log("Unable to reverse geocode location. %@", log: OSLog.default, type: .error, error!.localizedDescription)
                }
            })
            return promise
        }
        
        // Helper function to safely sync lastLocation and isoCountryCode across threads
        func updateLastLocation(location: CLLocation?) -> Promise<Bool> {
            return Promise<Bool>(on: getLocationQueue) { fulfill, reject in
                if location == nil {
                    reject(MobiledgeXLocation.MobiledgeXLocationError.nilLocation)
                    return
                }
                self.lastLocation = location
                self.getISOCountryCodeFromLocation(location: location!).then { isoCountryCode in
                    os_log("Successfully updated last location", log: OSLog.default, type: .error)
                    self.isoCountryCode = isoCountryCode
                    fulfill(true)
                    return
                }.catch { error in
                    os_log("Successfully updated last location, but unable to store isoCountryCode. Error is %@", log: OSLog.default, type: .error, error.localizedDescription)
                    fulfill(true)
                }
            }
        }
        
        // Helper function to safely get lastLocation across threads
        func getLastLocation() -> Promise<CLLocation?> {
            return Promise<CLLocation?>(on: getLocationQueue) { fulfill, reject in
                var location: CLLocation?
                location = self.lastLocation
                fulfill(location)
            }
        }
    }
}

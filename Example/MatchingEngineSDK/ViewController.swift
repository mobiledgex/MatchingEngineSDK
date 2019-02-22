//
//  ViewController.swift
//  MatchingEngineSDK Example
//
//  Created by Jean Tantra, Metatheory.com
//
// Copyright 2019 MobiledgeX
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit

import GoogleMaps

import MatchingEngineSDK    // SDK

// quick and dirty global scope

var theMap: GMSMapView?     //   used by sample.client
var userMarker: GMSMarker?   // set by RegisterClient , was: mUserLocationMarker.

class ViewController: UIViewController, GMSMapViewDelegate, UIAdaptivePresentationControllerDelegate
{
    #warning ("Action item: you need to replace appName/devName. Our demo passes appName and devName to RegisterClient() API")
//    #error ("Action item: you need to replace appName/devName. our demo passes appName and devName to RegisterClient() API")
    
    var appName =  "MobiledgeX SDK Demo"    //   replace this with your appName
    var devName =  "MobiledgeX SDK Demo"    //   replace this with your devName
    var appVers =  "1.0"    //   replace this with your appVers

    @IBOutlet var viewMap: GMSMapView!

    let rightBarDropDown = DropDown()   // menu

    private var locationVerified: Bool = false //  todo where to set this true?
    private var locationVerificationAttempted: Bool = false

    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Swift.print("\(#function)")

        title = "MatchingEngineSDK Demo"

        // -----
        // Google maps

        theMap = viewMap //   publish
        theMap!.delegate = self //  for taps
     //   theMap!.isMyLocationEnabled = true //   blue dot

        let camera: GMSCameraPosition = GMSCameraPosition.camera(withLatitude: 48.857165, longitude: 2.354613, zoom: 8.0)

        viewMap.camera = camera
        
        // -----
        // UI top left, top right
        
        let leftButton: UIButton = UIButton(type: UIButton.ButtonType.custom) as UIButton
        leftButton.frame = CGRect(x: 0, y: 0, width: 40, height: 40)
        leftButton.setImage(UIImage(named: "menu-512"), for: UIControl.State.normal)
        leftButton.addTarget(self, action: #selector(menuButtonAction), for: UIControl.Event.touchUpInside)
        
        let leftBarButtonItem: UIBarButtonItem = UIBarButtonItem(customView: leftButton)
        
        navigationItem.leftBarButtonItem = leftBarButtonItem
        
        setupRightBarDropDown() // top right menu

        // -----

        defaultUninitializedSettings()

        observers()

        // -----
        getInitialLatencies()
   
        let firstTimeUsagePermission = UserDefaults.standard.bool(forKey: "firstTimeUsagePermission")
        if firstTimeUsagePermission == true
        {
             getLocaltionUpdates()
            theMap!.isMyLocationEnabled = true //   blue dot
        }
        
        //////////////////
       // use registerClient API
        //
        MexRegisterClient.shared.registerClientNow( appName: appName,
                                                   devName:  devName,
                                                   appVers: "1.0")
    }
    
    func getInitialLatencies()
    {
        // Swift.print("\(#function)")

        DispatchQueue.main.async {
            getNetworkLatencyCloud()    //   "latencyCloud"
        }
        DispatchQueue.main.async {
            getNetworkLatencyEdge() //   "latencyEdge"
        }
    }
    
    func observers()
    {
        // Swift.print("\(#function)")

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Client registered"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            // let v = notification.object as! String
            
            SKToast.show(withMessage: "Client registered")
            
            let loc = retrieveLocation()
            MexGetAppInst.shared.getAppInstNow(gpslocation:loc)    // "Get App Instances"
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "processAppInstList"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            let d = notification.object as! [String : Any]
            
            SKToast.show(withMessage: "processAppInstList")
            
            processAppInstList(d)
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Verifylocation success"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            let d = notification.object as! [String : Any]
            
            SKToast.show(withMessage: "Verifylocation success: \(d)")
            
            let image =  makeUserMakerImage(MexRegisterClient.COLOR_VERIFIED)
            userMarker!.icon = image
            
            self!.locationVerified = true

        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Verifylocation failure"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            let d = notification.object as! [String : Any]
            
            SKToast.show(withMessage: "Verifylocation failure: \(d)")
            
            let image =  makeUserMakerImage(MexRegisterClient.COLOR_FAILURE)
            userMarker!.icon = image
        }
        
        
        // latency
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "latencyCloud"), object: nil, queue: nil) // updateNetworkLatencies
        { [weak self] notification in
            guard let _ = self else { return }
            
            let v = notification.object as! String
            UserDefaults.standard.set( v, forKey: "latencyCloud")
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "latencyEdge"), object: nil, queue: nil) // updateNetworkLatencies
        { [weak self] notification in
            guard let _ = self else { return }
            
            let v = notification.object as! String
            UserDefaults.standard.set( v, forKey: "latencyEdge")
        }
        
        // ----
        let firstTimeUsagePermission = UserDefaults.standard.bool(forKey: "firstTimeUsagePermission")
        if firstTimeUsagePermission == false
        {
            askPermission()
        }
        
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "processFindCloudletResult"), object: nil, queue: nil) // updateNetworkLatencies
        { [weak self] notification in
            guard let _ = self else { return }
            
            let d = notification.object as! [String:Any]
            
            processFindCloudletResult(d)
        }
        
        
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "permissionGrantedGetLocaltionUpdates"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
          //  let d = notification.object as! [String:Any]
            
            self!.getLocaltionUpdates()
            theMap!.isMyLocationEnabled = true //   blue dot
        }
        
    } // end observers()

    // MARK: -
    
    func getLocaltionUpdates()
    {
        Swift.print("\(#function)")
        
        resetUserLocation(true)
    }
    
    func defaultUninitializedSettings()
    {
        // Swift.print("\(#function)")
        
        UserDefaults.standard.set("0", forKey: "Latency Avg:")

        if UserDefaults.standard.string(forKey: "Latency Test Packets") == nil
        {
            UserDefaults.standard.set("5", forKey: "Latency Test Packets")
        }
        
        if UserDefaults.standard.string(forKey: "Download Size") == nil
        {
            UserDefaults.standard.set("1 MB", forKey: "Download Size")
        }
        
        if UserDefaults.standard.string(forKey: "LatencyTestMethod") == nil
        {
            UserDefaults.standard.set("Ping", forKey: "LatencyTestMethod")
        }
        
        //        if UserDefaults.standard.bool(forKey: "Latency Test Auto-Start") == nil
        //        {
        //            UserDefaults.standard.set("Ping", forKey: "Latency Test Auto-Start")
        //        }
        
        UserDefaults.standard.set("0", forKey: "Latency Avg:")
        
    }
    
    
    
    func askPermission()
    {
        // Swift.print("\(#function)")

        let storyboard = UIStoryboard(name: "Permissions", bundle: nil)
        
        let vc =  storyboard.instantiateViewController(withIdentifier: "PermissionViewController")
        
        navigationController!.pushViewController(vc, animated: true)
    }
 
 

    // MARK: - GMUMapViewDelegate

    // show more place info when info marker is tapped
    func mapView(_: GMSMapView, didTapInfoWindowOf marker: GMSMarker)
    {
        // Swift.print("\(#function)")

        if marker.userData == nil
        {
            return
        }

        let cloudletName = marker.userData as! String

        let lets = CloudletListHolder.getSingleton().getCloudletList()

        if lets[cloudletName] != nil
        {
            let cl = lets[cloudletName]
            Swift.print("\(cloudletName)")
            Swift.print("\(cl)")

            Swift.print("didTapInfoWindowOf \(cloudletName)")

            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            let vc = storyboard.instantiateViewController(withIdentifier: "CloudletDetailsViewController") as! CloudletDetailsViewController
            
            // pass in data - decoupled
            UserDefaults.standard.set(cl!.getCloudletName() + " : " + cl!.getUri(), forKey: "Cloudlet Name:")
            UserDefaults.standard.set(cl!.getAppName(), forKey: "App Name:")
            UserDefaults.standard.set(cl!.getCarrierName(), forKey: "Carrier:")

            UserDefaults.standard.set(cl!.getLatitude(), forKey: "Latitude:")
            UserDefaults.standard.set(cl!.getLongitude(), forKey: "Longitude:")
            UserDefaults.standard.set(cl!.getDistance(), forKey: "Distance:")

            UserDefaults.standard.set(cl!.getLatencyMin(), forKey: "Latency Min:")
            UserDefaults.standard.set(cl!.getLatencyAvg(), forKey: "Latency Avg:")
            UserDefaults.standard.set(cl!.getLatencyMax(), forKey: "Latency Max:")
            UserDefaults.standard.set(cl!.getLatencyStddev(), forKey: "Latency Stddev:")
            // UserDefaults.standard.set( cl , forKey: "currentDetailsCloudlet")

            navigationController!.pushViewController(vc, animated: true)
            
            vc.cloudlet = cl!
        }
    }

    // hide info or search when map is tapped
    func mapView(_: GMSMapView, didTapAt coordinate: CLLocationCoordinate2D)
    {
        Swift.print("didTapAt \(coordinate)")
    }

    func mapView(_: GMSMapView, didLongPressAt coordinate: CLLocationCoordinate2D)
    {
        Swift.print("onMapLongClick(\(coordinate))")
        showSpoofGpsDialog(coordinate)
    }

    
    // Mark: -

    
    func setupRightBarDropDown()
    {
        let image = UIImage(named: "dot-menu@3x")?.withRenderingMode(.alwaysOriginal)
        let barButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(ViewController.openMenu(sender:)))
        
        navigationItem.rightBarButtonItem = barButtonItem
        
        rightBarDropDown.anchorView = barButtonItem
        
        rightBarDropDown.dataSource = [ // these first two are automatically done on launch
            "Register Client",
            "Get App Instances",
            "Verify Location",
            "Find Closet Cloudlet",
            "Reset Location",
        ]
    }

    
    @objc public func openMenu(sender _: UIBarButtonItem)
    {
        Swift.print("openMenu") // Log

        rightBarDropDown.show()

        // Action triggered on selection
        rightBarDropDown.selectionAction = { [weak self] index, item in
            Swift.print("selectionAction \(index) \(item) ")

//            "Register Client",
//            "Get App Instances",
//            "Verify Location",
//            "Find Closest Cloudlet",
//            "Reset Location",
            
            switch index
            {
            case 0:
                //  "Register Client",
                MexRegisterClient.shared.registerClientNow( appName:   self!.appName,
                                                           devName:  self!.devName,
                                                           appVers: self!.appVers)
            case 1:
                let loc = retrieveLocation()
                MexGetAppInst.shared.getAppInstNow(gpslocation:loc)    // "Get App Instances"

            case 2:
                Swift.print("Verify Location")

                let vl = UserDefaults.standard.bool(forKey: "VerifyLocation")
                
                if vl
                {
                    self!.locationVerificationAttempted = true

                    let loc = retrieveLocation()

                    MexVerifyLocation.shared.doVerifyLocation(gpslocation:loc)     // "Verify Location"
                }
                else
                {
                    //alert
                    self?.askPermissionToVerifyLocation()
                }
                
            case 3:
                Swift.print("Find Closest Cloudlet")
                 let loc = retrieveLocation()
                MexFindNearestCloudlet.shared.findNearestCloudlet(gpslocation:loc)     //  "Find Closest Cloudlet"
                
            case 4:
                Swift.print("Reset Location")

                resetUserLocation(false) // "Reset Location" Note: Locator.currentPositionnot working

            default:
                break
            }
        }
    }

    @objc func menuButtonAction()
    {
        print("menuButtonAction")

        if presentingViewController == nil
        {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)

            let vc = storyboard.instantiateViewController(withIdentifier: "SideMenuViewController") // left side menu

            navigationController!.pushViewController(vc, animated: true)
        }
        else
        {
            dismiss(animated: true, completion: nil)
        }
    }

  
    // MARK: -

    private func showSpoofGpsDialog(_ spoofLatLng: CLLocationCoordinate2D) // LatLng)
    {
        // Swift.print("\(#function)")

        if userMarker == nil
        {
            return
        }
        let oldLatLng = userMarker!.position

        userMarker!.position = spoofLatLng //   mUserLocationMarker
        let choices: [String] = ["Spoof GPS at this location", "Update location in GPS database"]

        let alert = UIAlertController(title: " ", message: "Choose", preferredStyle: .alert) // .actionSheet)

        alert.addAction(UIAlertAction(title: choices[0], style: .default, handler: { _ in
            // execute some code when this option is selected

            SKToast.show(withMessage: "GPS spoof enabled.")

            self.locationVerificationAttempted = false
            self.locationVerified = false

            let distance =
                oldLatLng.distance(from: spoofLatLng) / 1000

            userMarker!.snippet = "Spoofed \(String(format: "%.2f", distance)) km from actual location"
            
            let resized =  makeUserMakerImage(MexRegisterClient.COLOR_NEUTRAL)
            
            userMarker!.icon = resized

        }))
        alert.addAction(UIAlertAction(title: choices[1], style: .default, handler: { _ in

            updateLocSimLocation(userMarker!.position.latitude, userMarker!.position.longitude)
            
            let resized =  makeUserMakerImage(MexRegisterClient.COLOR_NEUTRAL)
            
            userMarker!.icon = resized

        }))

        present(alert, animated: true, completion: nil)
    }
    
    func askPermissionToVerifyLocation()
    {
        // Swift.print("\(#function)")

        let alert = UIAlertController(title: "Alert", message: "Choose", preferredStyle: .alert) // .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Request permission To Verify Location", style: .default, handler: { _ in

            UserDefaults.standard.set( true, forKey: "VerifyLocation")
            let loc = retrieveLocation()
            
            MexVerifyLocation.shared.doVerifyLocation(gpslocation:loc)     // "Verify Location"
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
            
         Swift.print("VerifyLocation Cancel")   // Log
            
        }))
        
        present(alert, animated: true, completion: nil)
    }
}

extension CLLocationCoordinate2D
{
    // distance in meters, as explained in CLLoactionDistance definition
    func distance(from: CLLocationCoordinate2D) -> CLLocationDistance
    {
        let destination = CLLocation(latitude: from.latitude, longitude: from.longitude)
        return CLLocation(latitude: latitude, longitude: longitude).distance(from: destination)
    }
}

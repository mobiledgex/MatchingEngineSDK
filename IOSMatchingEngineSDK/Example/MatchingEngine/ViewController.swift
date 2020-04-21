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
//  ViewController.swift
//  MatchingEngine SDK Example
//

import UIKit

import GoogleMaps
import Promises
import os.log

import DropDown
import MobiledgeXiOSLibrary
// quick and dirty global scope

var theMap: GMSMapView?     //   used by sample.client
var userMarker: GMSMarker?   // set by RegisterClient , was: mUserLocationMarker.

class ViewController: UIViewController, GMSMapViewDelegate, UIAdaptivePresentationControllerDelegate
{
    var matchingEngine: MobiledgeXiOSLibrary.MatchingEngine!
    
    var host = ""
    var port: UInt16 = 38001
    var demoHost = "sdkdemo.dme.mobiledgex.net"
    
    var demo = true; // If true, use DEMO values as opposed to discoverable properties.
    
    var carrierName = ""
    var appName = ""
    var orgName = ""
    var appVers = ""
    var authToken: String? = nil
    var uniqueID: String?
    var uniqueIDType: MobiledgeXiOSLibrary.MatchingEngine.IDTypes?
    var cellID: UInt32?
    var tags: [MobiledgeXiOSLibrary.MatchingEngine.Tag]?
    
    // For the overriding me.getCarrierName() for contacting the DME host
    var overrideDmeCarrierName: String? = "sdkdemo"

    @IBOutlet var viewMap: GMSMapView!

    let rightBarDropDown = DropDown()   // menu
    
    // Menu triggered network states will be tracked here, since the user controls usage of the futures:
    var registerPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.RegisterClientReply>?
    var findCloudletPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.FindCloudletReply>?
    var verifyLocationPromise: Promise<MobiledgeXiOSLibrary.MatchingEngine.VerifyLocationReply>?

    private var locationVerified: Bool = false //  todo where to set this true?
    private var locationVerificationAttempted: Bool = false

    private func updateAppDetails() {
         #warning ("Action item: These values are a key value lookup for the Distributed Matching Engine backend to locate the matching edge cloudlet for your app")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        matchingEngine = appDelegate.matchingEngine

        if demo
        {
            host = demoHost
            port = MobiledgeXiOSLibrary.MatchingEngine.DMEConstants.dmeRestPort
            appName =  "MobiledgeX SDK Demo"
            appVers = "1.0"
            orgName =  "MobiledgeX"
            carrierName = "gddt"
            authToken = nil
            uniqueID = matchingEngine.getUniqueID()
            uniqueIDType = nil
            cellID = nil
            tags = nil
        }
        else
        {
            appName =  matchingEngine.getAppName()
            //appName = "MobiledgeX SDK Demo"   //Use when testing and app is not registered previously
            appVers =  matchingEngine.getAppVersion()
            orgName =  "MobiledgeX"             //   replace this with your orgName
            carrierName = matchingEngine.getCarrierName() ?? ""  // This value can change, and is observed by the MatchingEngine.
            authToken = nil // opaque developer specific String? value.
            uniqueID = matchingEngine.getUniqueID()
            uniqueIDType = nil
            cellID = nil
            tags = nil
        }
    }
    
    override func viewDidLoad()
    {
        super.viewDidLoad()
        
        updateAppDetails();

        // Swift.print("\(#function)")

        title = "MatchingEngine SDK Demo"

        // -----
        // Google maps

        theMap = viewMap //   publish
        theMap!.delegate = self //  for taps
        // theMap!.isMyLocationEnabled = true //   blue dot

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
        var carrierName: String? = nil
        if let cname = overrideDmeCarrierName {
            carrierName = cname
        } else {
            carrierName = matchingEngine.getCarrierName()
        }
        guard let _ = carrierName else {
            os_log("Register Client needs a valid carrierName!", log: OSLog.default, type: .debug)
            return;
        }
        
        let registerClientRequest = matchingEngine.createRegisterClientRequest(orgName: orgName,
                                                                   appName: appName,
                                                                   appVers: appVers)
        matchingEngine.registerClient(host: host,
                          port: port,
                          request: registerClientRequest)
        .then { registerReply in
            // Update UI. The MatchingEngine SDK keeps track of details for next calls.
            os_log("RegisterReply: %@", log: OSLog.default, type: .debug, String(describing: registerReply))
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: "Client Registered"), object: nil)
        }.catch { error in
            os_log("RegisterReply Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
        }
    }
    
    func getInitialLatencies()
    {
        // Swift.print("\(#function)")

        DispatchQueue.main.async {
            getNetworkLatencyCloud() //   "latencyCloud"
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
            let request = self!.matchingEngine.createGetAppInstListRequest(gpsLocation: loc, carrierName: self!.carrierName)
            self!.matchingEngine.getAppInstList(host: self!.host, port: self!.port, request: request)
                .then { appInstList in
                    // Ick. Refactor, to just "Toast" the SDK usage status in UI at each promises chain stage:
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "processAppInstList"), object: appInstList)
                }
                .catch { error in
                    os_log("Error getting appInstList: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                }
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
            
            let image =  makeUserMakerImage(LocationColorCode.VERIFIED)
            userMarker!.icon = image
            
            self!.locationVerified = true

        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "Verifylocation failure"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            let d = notification.object as! [String : Any]
            
            SKToast.show(withMessage: "Verifylocation failure: \(d)")
            
            let image =  makeUserMakerImage(LocationColorCode.FAILURE)
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
            Swift.print("\(String(describing: cl))")

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
            "Get QoS Position",
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
//            "Get QoS Position",
//            "Reset Location",
            
            switch index
            {
            case 0:
                //  "Register Client", should use dynamic values if not Demo:
                let registerClientRequest = self!.matchingEngine.createRegisterClientRequest(orgName: self!.orgName,
                                                                                 appName: self!.appName,
                                                                                 appVers: self!.appVers)
                if (self!.demo) {  //used for demo purposes
                    self!.registerPromise = self!.matchingEngine.registerClient(
                        host: self!.demoHost, port: self!.port, request: registerClientRequest)
                    .then { registerClientReply in
                        os_log("RegisterClientReply: %@", log: OSLog.default, type: .debug, String(describing: registerClientReply))
                        SKToast.show(withMessage: "RegisterClientReply: \(registerClientReply)")
                    }
                    .catch { error in
                        os_log("RegisterClient Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        SKToast.show(withMessage: "RegisterClient Error: \(error)")
                    }
                } else {
                    self!.registerPromise = self!.matchingEngine.registerClient(
                        request: registerClientRequest)
                    .then { registerClientReply in
                        os_log("RegisterClientReply: %@", log: OSLog.default, type: .debug, String(describing: registerClientReply))
                        SKToast.show(withMessage: "RegisterClientReply: \(registerClientReply)")
                    }
                    .catch { error in
                        os_log("RegisterClient Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        SKToast.show(withMessage: "RegisterClient Error: \(error)")
                    }
                }
                
            case 1:
                let loc = retrieveLocation()
                
                let appInstListRequest = self!.matchingEngine.createGetAppInstListRequest(gpsLocation: loc, carrierName: self!.carrierName)
                if (self!.demo) {
                    self!.matchingEngine.getAppInstList(host: self!.demoHost, port: self!.port, request: appInstListRequest)
                    .then { appInstListReply in
                        os_log("appInstList Reply: %@", log: OSLog.default, type: .debug, String(describing: appInstListReply))
                        SKToast.show(withMessage: "appInstList Reply: \(appInstListReply)")
                        // TODO: observers
                    }
                    .catch { error in
                        os_log("appInstList Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        SKToast.show(withMessage: "appInstList error: \(error)")
                    }
                } else {
                    self!.matchingEngine.getAppInstList(request: appInstListRequest)
                    .then { appInstListReply in
                        os_log("appInstList Reply: %@", log: OSLog.default, type: .debug, String(describing: appInstListReply))
                        SKToast.show(withMessage: "appInstList Reply: \(appInstListReply)")
                    }
                    .catch { error in
                        os_log("appInstList Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        SKToast.show(withMessage: "appInstList error: \(error)")
                    }
                }

            case 2:
                Swift.print("Verify Location")

                let vl = UserDefaults.standard.bool(forKey: "VerifyLocation")
                
                if vl
                {
                    self!.locationVerificationAttempted = true

                    let loc = retrieveLocation()
                    
                    let verifyLocRequest = self!.matchingEngine.createVerifyLocationRequest(
                        gpsLocation: loc, carrierName: self!.carrierName)
                    if (self!.demo) {
                        self!.verifyLocationPromise = self!.matchingEngine.verifyLocation(host: self!.demoHost, port: self!.port, request: verifyLocRequest)
                        .then { verifyLocationReply in
                            os_log("verifyLocationReply: %@", log: OSLog.default, type: .debug, String(describing: verifyLocationReply))
                            SKToast.show(withMessage: "VerfiyLocation reply: \(verifyLocationReply)")
                                // TODO: observers
                        }
                        .catch { error in
                            os_log("verifyLocation Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                            SKToast.show(withMessage: "VerfiyLocation error: \(error)")
                        }
                    } else {
                        self!.verifyLocationPromise = self!.matchingEngine.verifyLocation(request: verifyLocRequest)
                        .then { verifyLocationReply in
                            os_log("verifyLocationReply: %@", log: OSLog.default, type: .debug, String(describing: verifyLocationReply))
                            SKToast.show(withMessage: "VerfiyLocation reply: \(verifyLocationReply)")
                        }
                        .catch { error in
                            os_log("verifyLocation Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                            SKToast.show(withMessage: "VerfiyLocation error: \(error)")
                        }
                    }
                }
                else
                {
                    // alert
                    self?.askPermissionToVerifyLocation()
                }
                
            case 3:
                Swift.print("Find Closest Cloudlet")
                let loc = retrieveLocation()
                // FIXME: register client is a promise.

                let findCloudletRequest = self!.matchingEngine.createFindCloudletRequest(gpsLocation: loc, carrierName: self!.carrierName)
                if (self!.demo) {
                    if #available(iOS 13.0, *) {
                        self!.matchingEngine.findCloudlet(host: self!.demoHost, port: self!.port, request: findCloudletRequest)
                            .then { findCloudletReply in
                                os_log("findCloudlet Reply: %@", log: OSLog.default, type: .debug, String(describing: findCloudletReply))
                                SKToast.show(withMessage: "findCloudlet Reply: \(findCloudletReply)")
                        }
                        .catch { error in
                            os_log("findCloudlet Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                            SKToast.show(withMessage: "findCloudlet error: \(error)")
                        }
                    } else {
                        // Fallback on earlier versions
                    }
                } else {
                    if #available(iOS 13.0, *) {
                        self!.matchingEngine.findCloudlet(request: findCloudletRequest)
                            .then { findCloudletReply in
                                os_log("findCloudlet Reply: %@", log: OSLog.default, type: .debug, String(describing: findCloudletReply))
                                SKToast.show(withMessage: "findCloudlet Reply: \(findCloudletReply)")
                        }
                        .catch { error in
                            os_log("findCloudlet Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                            SKToast.show(withMessage: "findCloudlet error: \(error)")
                        }
                    } else {
                            // Fallback on earlier versions
                    }
                }
                
            case 4:
                Swift.print("Get QoS Position")
                let loc = retrieveLocation()
                let positions = self!.createQoSPositionList(loc: loc,
                                                      directionDegrees: 45,
                                                      totalDistanceKm: 200,
                                                      increment: 1)
                
                let getQoSPositionRequest = self!.matchingEngine.createQosKPIRequest(requests: positions)
                if (self!.demo) {
                    self!.matchingEngine.getQosKPIPosition(host: self!.demoHost, port: self!.port, request: getQoSPositionRequest)
                    .then { getQoSPositionReply in
                        os_log("getQoSPosition Reply: %@", log: OSLog.default, type: .debug, String(describing: getQoSPositionReply))
                        SKToast.show(withMessage: "getQoSPosition Reply: \(getQoSPositionReply)")
                    }
                    .catch { error in
                        os_log("getQoSPosition Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        SKToast.show(withMessage: "getQoSPosition error: \(error)")
                    }
                } else {
                    self!.matchingEngine.getQosKPIPosition(request: getQoSPositionRequest)
                    .then { getQoSPositionReply in
                        os_log("getQoSPosition Reply: %@", log: OSLog.default, type: .debug, String(describing: getQoSPositionReply))
                        SKToast.show(withMessage: "getQoSPosition Reply: \(getQoSPositionReply)")
                    }
                    .catch { error in
                        os_log("getQoSPosition Error: %@", log: OSLog.default, type: .debug, error.localizedDescription)
                        SKToast.show(withMessage: "getQoSPosition error: \(error)")
                    }
                }
                
            case 5:
                SKToast.show(withMessage: "Reset Location")
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
  
    func createQoSPositionList(loc: MobiledgeXiOSLibrary.MatchingEngine.Loc, directionDegrees: Double, totalDistanceKm: Double, increment: Double) -> [MobiledgeXiOSLibrary.MatchingEngine.QosPosition]
    {
        var qosPositionList = [MobiledgeXiOSLibrary.MatchingEngine.QosPosition]()
        let kmPerDegreeLong = 111.32 //at Equator
        let kmPerDegreeLat = 110.57 //at Equator
        let addLongitude = (cos(directionDegrees * (.pi/180)) * increment) / kmPerDegreeLong
        let addLatitude = (sin(directionDegrees * (.pi/180)) * increment) / kmPerDegreeLat
        var i = 0.0
        var idx: Int64 = 0
        var longitude = loc.longitude ?? 0
        var latitude = loc.latitude ?? 0
        
        while i < totalDistanceKm {
            let loc = MobiledgeXiOSLibrary.MatchingEngine.Loc(latitude: latitude, longitude: longitude)
            let qosPosition = MobiledgeXiOSLibrary.MatchingEngine.QosPosition(positionId: idx, gpsLocation: loc)
            
            qosPositionList.append(qosPosition)
            
            longitude = longitude + addLongitude
            latitude = latitude + addLatitude
            i += increment
            idx += 1
        }
        
        return qosPositionList
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
            
            let resized =  makeUserMakerImage(LocationColorCode.NEUTRAL)
            
            userMarker!.icon = resized

        }))
        alert.addAction(UIAlertAction(title: choices[1], style: .default, handler: { _ in
            // For demo purposes, we're going to use the carrierName override.
            let cn = self.overrideDmeCarrierName ?? self.matchingEngine.getCarrierName() ?? "sdkdemo"
            
            var hostName: String!
            do {
                hostName = try self.matchingEngine.generateDmeHost(carrierName: cn).replacingOccurrences(of: "dme", with: "locsim")
            } catch {
                Swift.print("Error: \(error.localizedDescription)")
            }
            updateLocSimLocation(hostName: hostName,
                                 latitude: userMarker!.position.latitude,
                                 longitude: userMarker!.position.longitude)
            
            let resized =  makeUserMakerImage(LocationColorCode.NEUTRAL)
            
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
            
            // ZORK MexVerifyLocation.shared.doVerifyLocation(gpslocation:loc) // "Verify Location"
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .default, handler: { _ in
            
         Swift.print("VerifyLocation Cancel") // Log
            
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

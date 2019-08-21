//
//  ViewController.swift
//  SkeletonApp
//
// Copyright 2019 MobiledgeX, Inc.
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
import Promises
import NSLogger

import DropDown

import MatchingEngine

// quick and dirty global scope

var theMap: GMSMapView?     //   used by sample.client
var userMarker: GMSMarker?   // set by RegisterClient , was: mUserLocationMarker.

class ViewController: UIViewController, GMSMapViewDelegate, UIAdaptivePresentationControllerDelegate
{
    var matchingEngine: MatchingEngine!
    
    var host = ""
    var port: UInt = 38001
    
    var demo = true; // If true, use DEMO values as opposed to discoverable properties.
    
    var carrierName = ""
    var appName = ""
    var devName = ""
    var appVers = ""
    var authToken: String? = nil
    
    // For the overriding me.getCarrierName() for contacting the DME host
    var overrideDmeCarrierName: String? = "mexdemo"

    @IBOutlet var viewMap: GMSMapView!

    let rightBarDropDown = DropDown()   // menu
    
    // Menu triggered network states will be tracked here, since the user controls usage of the futures:
    var registerPromise: Promise<[String: AnyObject]>? // AnyObject --> RegisterClientReply
    var findCloudletPromise: Promise<[String: AnyObject]>? // AnyObject --> FindCloudletReply
    var verifyLocationPromise: Promise<[String: AnyObject]>?

    private var locationVerified: Bool = false //  todo where to set this true?
    private var locationVerificationAttempted: Bool = false

    private func updateAppDetails() {
         #warning ("Action item: These values are a key value lookup for the Distributed Matching Engine backend to locate the matching edge cloudlet for your app")
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        matchingEngine = appDelegate.matchingEngine

        if demo
        {
            host = MexUtil.shared.generateDmeHost(carrierName: "mexdemo")
            port = matchingEngine.getDefaultDmePort()
            appName =  "MobiledgeX SDK Demo"
            appVers = "1.0"
            devName =  "MobiledgeX"
            carrierName = "tdg"
            authToken = nil
        }
        else
        {
            appName =  matchingEngine.getAppName()
            appVers =  matchingEngine.getAppVersion()
            devName =  "MobiledgeX"             //   replace this with your devName
            carrierName = matchingEngine.getCarrierName() ?? ""  // This value can change, and is observed by the MatchingEngine.
            authToken = nil // opaque developer specific String? value.
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
            if let cname = matchingEngine.getCarrierName()
            {
                carrierName = cname
            }
            else
            {
                carrierName = "tdg"
            }
        }
        guard let _ = carrierName else {
            Logger.shared.log(.network, .debug, "Register Client needs a valid carrierName!")
            return;
        }
        Swift.print("RegisterClient not implemented yet. Copy and Paste initial call to RegisterClient")
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
            let request = self!.matchingEngine.createGetAppInstListRequest(carrierName: self!.carrierName, gpsLocation: loc)
            self!.matchingEngine.getAppInstList(host: self!.host, port: self!.port, request: request)
                .then { appInstList in
                    // Ick. Refactor, to just "Toast" the SDK usage status in UI at each promises chain stage:
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "processAppInstList"), object: appInstList)
                }
                .catch { error in
                    Logger.shared.log(.network, .info, "Error getting appInstList: \(error)")
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
                Swift.print("RegisterClient not implemented yet") 
            case 1:
                Swift.print("GetAppInst not implemented yet")
            case 2:
                Swift.print("VerifyLocation not implemented yet")
            case 3:
                Swift.print("FindClosestCloudlet not implemented yet")
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
            
            let resized =  makeUserMakerImage(LocationColorCode.NEUTRAL)
            
            userMarker!.icon = resized

        }))
        alert.addAction(UIAlertAction(title: choices[1], style: .default, handler: { _ in
            // For demo purposes, we're going to use the carrierName override.
            let cn = self.overrideDmeCarrierName ?? self.matchingEngine.getCarrierName() ?? "mexdemo"
            
            let hostName: String = MexUtil.shared.generateDmeHost(carrierName: cn).replacingOccurrences(of: "dme", with: "locsim")
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

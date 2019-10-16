//
//  LoginViewController.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/4/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import UIKit
import MatchingEngine
import Promises

class LoginViewController: UIViewController {
    
    @IBOutlet weak var gameIDLabel: UILabel!
    @IBOutlet weak var gameIDField: UITextField!
    @IBOutlet weak var userNameLable: UILabel!
    @IBOutlet weak var userNameField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    
    var userName: String?
    var gameID: String?
    
    // MatchingEngine variables
    var matchingEngine: MatchingEngine!
    var appName: String?
    var appVers: String?
    var devName: String?
    var carrierName: String?
    var authToken: String?
    var host: String?
    var port: UInt = 38001
    var location: [String: Any]?
    var demo = true
    
    // MatchingEngine API return objects
    var registerPromise: Promise<[String: AnyObject]>? // AnyObject --> RegisterClientReply
    var findCloudletPromise: Promise<[String: AnyObject]>?
    var verifyLocationPromise: Promise<[String: AnyObject]>?
    var appInstListPromise: Promise<[String: AnyObject]>?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        userNameField.delegate = self
        gameIDField.delegate = self
        
        setUpMatchingEngineConnection()
        DispatchQueue.main.async {
            self.callMatchingEngineAPIs()
        }
    }
    
    func setUpMatchingEngineConnection() {
        matchingEngine = MatchingEngine()
        if demo {
            host = "sdkdemo.dme.mobiledgex.net"
            port = 38001
            appName = "MobiledgeX SDK Demo"
            appVers = "1.0"
            devName = "MobiledgeX"
            carrierName = "tdg"
            authToken = nil
            location = ["longitude": -122.149349, "latitude": 37.459609]  // Get actual location and ask user for permission
        } else {
            appName = matchingEngine.getAppName()
            appVers = matchingEngine.getAppVersion()
            devName = "MobiledgeX" // Replace with your Developer Name
            carrierName = matchingEngine.getCarrierName() ?? ""
            location = ["longitude": -122.149349, "latitude": 37.459609]  // Get actual location and ask user for permission
        }
    } 
    
    func callMatchingEngineAPIs() {
        let registerClientRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken)
        do {
            // Register user to begin using edge cloudlet
            registerPromise = try matchingEngine.registerClient(request: registerClientRequest)
            .then { registerClientReply in
                SKToast.show(withMessage: "RegisterClientReply: \(registerClientReply)")
                // Find closest edge cloudlet
                self.findCloudletPromise = try self.matchingEngine.findCloudlet(request:        self.matchingEngine.createFindCloudletRequest(
                    carrierName: self.carrierName!,
                    gpsLocation: self.location!,
                    devName: self.devName!,
                    appName: self.appName!,
                    appVers: self.appVers!))
                .then { findCloudletReply in
                    SKToast.show(withMessage: "FindCloudletReply is \(findCloudletReply)")
                    self.host = findCloudletReply["fqdn"] as? String
                }
                //Verify location of user
                /*self.verifyLocationPromise = try self.matchingEngine.verifyLocation(request: self.matchingEngine.createVerifyLocationRequest(
                                                        carrierName: self.carrierName,                    gpsLocation: self.location!))
                .then { verifyLocationReply in
                    SKToast.show(withMessage: "VerifyLocationReply is \(verifyLocationReply)")
                }*/
                // List of App installations
                self.appInstListPromise = try self.matchingEngine.getAppInstList(request: self.matchingEngine.createGetAppInstListRequest(
                    carrierName: self.carrierName!,
                    gpsLocation: self.location!))
                .then { appInstListReply in
                    SKToast.show(withMessage: "AppInstListReply is \(appInstListReply)")
                }
            }
        } catch let error as DmeDnsError {
            SKToast.show(withMessage: "DmeHost Error: \(error.errorDescription)")
        } catch {
            SKToast.show(withMessage: "Error: \(error.localizedDescription)")
        }
    }
    
    private func moveToGameViewController(gameViewController: GameViewController) {
        // switch to GameViewController
        addChild(gameViewController)
        view.addSubview(gameViewController.view)
        gameViewController.didMove(toParent: self)
    }
    
    @IBAction func pressSubmit(_ sender: UIButton) {
        let gameViewController = self.storyboard?.instantiateViewController(withIdentifier: "game") as! GameViewController
        // Pass on gameID and userName to GameViewController
        guard let _  = gameID else {
            return
        }
        guard let _ = userName else {
            return
        }
        gameViewController.gameID = gameID
        gameViewController.userName = userName
        gameViewController.peers[userName!] = 0
        gameViewController.host = host
        moveToGameViewController(gameViewController: gameViewController)
    }
}

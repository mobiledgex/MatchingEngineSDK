//
//  LoginViewController.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/4/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import UIKit
// import MatchingEngine
import IOSMatchingEngine
import Promises
import SocketIO

class LoginViewController: UIViewController {
    
    @IBOutlet weak var gameIDField: UITextField!
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
    var port: Int?
    var location: [String: Any]?
    var demo = false
    
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
            host = "arshootereucluster.berlin-main.tdg.mobiledgex.net"
            port = 1337
            appName = "ARShooter"  // ARShooter
            appVers = "1.1"
            devName = "MobiledgeX"
            carrierName = "TDG"
            authToken = nil
            location = ["longitude": -122.149349, "latitude": 37.459609]  // Get actual location and ask user for permission
        } else {
            appName = matchingEngine.getAppName()
            appVers = matchingEngine.getAppVersion()
            devName = "franklin-mobiledgex" // franklin-mobiledgex
            carrierName = "TDG"
            //carrierName = matchingEngine.getCarrierName() ?? "TDG"
            //location = ["longitude": -122.149349, "latitude": 37.459609]  // Get actual location and ask user for permission
            location = ["latitude": 53.112, "longitude": 13.4223] // Get actual location and ask user for permission
        }
    } 
    
    func callMatchingEngineAPIs() {
        let registerClientRequest = matchingEngine.createRegisterClientRequest(devName: devName, appName: appName, appVers: appVers, carrierName: carrierName, authToken: authToken)
        do {
            // Register user to begin using edge cloudlet
            registerPromise = try matchingEngine.registerClient(request: registerClientRequest)
            .then { registerClientReply in
                SKToast.show(withMessage: "RegisterClientReply: \(registerClientReply)")
                print("RegisterClientReply: \(registerClientReply)")
                // Find closest edge cloudlet
                self.findCloudletPromise = try self.matchingEngine.findCloudlet(request:        self.matchingEngine.createFindCloudletRequest(
                    carrierName: self.carrierName!,
                    gpsLocation: self.location!,
                    devName: self.devName!,
                    appName: self.appName!,
                    appVers: self.appVers!))
                .then { findCloudletReply in
                    SKToast.show(withMessage: "FindCloudletReply is \(findCloudletReply)")
                    print("FindCloudletReply is \(findCloudletReply)")
                    self.host = findCloudletReply["fqdn"] as? String
                    guard let ports = findCloudletReply["ports"] as? [String: Any] else {
                        return
                    }
                    self.port = ports["public_port"] as! Int
                }
                // List of App instances
                self.appInstListPromise = try self.matchingEngine.getAppInstList(request: self.matchingEngine.createGetAppInstListRequest(
                    carrierName: self.carrierName!,
                    gpsLocation: self.location!))
                .then { appInstListReply in
                    SKToast.show(withMessage: "AppInstListReply is \(appInstListReply)")
                    print("AppInstListReply is \(appInstListReply)")
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
        // Make sure gameID and userName are not nil
        if gameID == nil {
            if gameIDField.text == "" {
                return
            }
        }
        if userName == nil {
            if userNameField.text == "" {
                return
            }
        }
        userNameField.isEnabled = false
        gameIDField.isEnabled = false
        
        if host == nil {
            host = "arshootereucluster.berlin-main.tdg.mobiledgex.net"
        }
        if port == nil {
            port = 1337
        }
        let url = "wss://\(host!):\(String(port!))/"
        //let url = "wss://frankfurt-main.tdg.mobiledgex.net:1337/"
        let manager = SocketManager(socketURL: URL(string: url)!)
        // Set variables for next GameViewController
        gameViewController.gameID = gameID
        gameViewController.userName = userName
        gameViewController.peers[userName!] = 0
        gameViewController.host = host
        gameViewController.port = port
        gameViewController.manager = manager
        moveToGameViewController(gameViewController: gameViewController)
    }
}

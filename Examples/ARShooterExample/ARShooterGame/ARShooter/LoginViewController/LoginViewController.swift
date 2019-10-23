// Copyright 2019 MobiledgeX, Inc. All rights and licenses reserved.
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
//  LoginViewController.swift
//  ARShooter

import UIKit
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
            devName = "franklin-mobiledgex"
            carrierName = "TDG"
            //carrierName = matchingEngine.getCarrierName() ?? "TDG"
            //location = ["longitude": -122.149349, "latitude": 37.459609]  // Get actual location and ask user for permission
            location = ["latitude": 53.112, "longitude": 13.4223] // Get actual location and ask user for permission
        }
    }
    
    func callMatchingEngineAPIs() {
        let registerClientRequest = matchingEngine.createRegisterClientRequest(
                                                devName: devName,
                                                appName: appName,
                                                appVers: appVers,
                                                carrierName: carrierName,
                                                authToken: authToken)
        do {
            try matchingEngine.registerClient(request: registerClientRequest)
            .then { registerClientReply in
                let findCloudletRequest = self.matchingEngine.createFindCloudletRequest(
                                                carrierName: self.carrierName!,
                                                gpsLocation: self.location!,
                                                devName: self.devName!,
                                                appName: self.appName!,
                                                appVers: self.appVers!)
                self.findCloudletPromise = try self.matchingEngine.findCloudlet(request: findCloudletRequest)
              
                let verifyLocationRequest = self.matchingEngine.createVerifyLocationRequest(
                                                carrierName: self.carrierName!,
                                                gpsLocation: self.location!)
                
                self.verifyLocationPromise = try self.matchingEngine.verifyLocation(request: verifyLocationRequest)
                
                all([self.findCloudletPromise!, self.verifyLocationPromise!])
                .then { value in
                    // Handle findCloudlet reply
                    let findCloudletReply = value[0]
                    SKToast.show(withMessage: "FindCloudletReply is \(findCloudletReply)")
                    print("FindCloudletReply is \(findCloudletReply)")
                    self.host = findCloudletReply["fqdn"] as? String
                    // ports is mapped to an _NSSingleObjectArrayI with a map inside (can have multiple ports)
                    guard let arr = findCloudletReply["ports"] as? [[String: Any]] else {
                        return
                    }
                    let ports = arr[0] as [String: Any]
                    self.port = ports["public_port"] as? Int
                    
                    // Handle verifyLocation reply
                    let verifyLocationReply = value[1]
                    SKToast.show(withMessage: "VerifyLocationReply is \(verifyLocationReply)")
                    print("VerifyLocationReply is \(verifyLocationReply)")
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

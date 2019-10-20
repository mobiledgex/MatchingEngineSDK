//
//  LoginViewController.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/4/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import UIKit
import Promises
import SocketIO

class LoginViewController: UIViewController {
    
    @IBOutlet weak var gameIDField: UITextField!
    @IBOutlet weak var userNameField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    
    var userName: String?
    var gameID: String?
    
    // MatchingEngine variables
    var appName: String?
    var appVers: String?
    var devName: String?
    var carrierName: String?
    var authToken: String?
    var host: String?
    var port: Int?
    var location: [String: Any]?
    
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
        SKToast.show(withMessage: "MatchingEngine not setup yet")
    } 
    
    func callMatchingEngineAPIs() {
        SKToast.show(withMessage: "RegisterClient not implemented yet")
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
            host = "arshootereucluster.berlin-main.tdg.mobiledgex.net" // frankfurt-main.tdg.mobiledgex.net
        }
        if port == nil {
            port = 1337
        }
        SKToast.show(withMessage: "Pass MatchingEngine and GameState variables to GameViewController")
        moveToGameViewController(gameViewController: gameViewController)
    }
}
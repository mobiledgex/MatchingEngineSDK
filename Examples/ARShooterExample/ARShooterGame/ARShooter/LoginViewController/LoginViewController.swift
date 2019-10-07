//
//  LoginViewController.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/4/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import UIKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var gameIDLabel: UILabel!
    @IBOutlet weak var gameIDField: UITextField!
    @IBOutlet weak var userNameLable: UILabel!
    @IBOutlet weak var userNameField: UITextField!
    @IBOutlet weak var submitButton: UIButton!
    
    var userName: String?
    var gameID: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        userNameField.delegate = self
        gameIDField.delegate = self
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
        moveToGameViewController(gameViewController: gameViewController)
    }
}

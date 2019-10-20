//
//  SocketIOManager.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/11/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import Foundation
import SocketIO
import ARKit

// Handles Socket.io callbacks and functions related to sending data to the server
extension GameViewController {
    
    func setUpSocketCallbacks() {
        
        socket.on(clientEvent: .connect) { data, ack in
            SKToast.show(withMessage: "Socket connected")
            self.socket.emit("login", self.gameID!, self.userName!)
        }
        
        socket.on("repeatUsername") { [weak self] data, ack in
            // Return to loginViewController because of repeated username
            let loginViewController = self?.storyboard?.instantiateViewController(withIdentifier: "login") as! LoginViewController
            self?.addChild(loginViewController)
            self?.view.addSubview(loginViewController.view)
            loginViewController.didMove(toParent: self)
            SKToast.show(withMessage: "That username is already being used")
            return
        }
        
        socket.on("bullet") { [weak self] data, ack in
            guard let bulletData = data[0] as? Data else { return }
            do {
                if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: bulletData) {
                    // add anchor to the session, ARSCNView delegate adds visible content
                    self?.sceneView.session.add(anchor: anchor)
                }
            } catch {
                print("Could not get bullet")
            }
        }
                
        socket.on("worldMap") { [weak self] data , ack in
            SKToast.show(withMessage: "Received World Map")
            guard let worldData = data[0] as? Data else { return }
            do {
                if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldData) {
                    SKToast.show(withMessage: "Successfully added world config")
                    // Run the session with the received world map
                    let configuration = ARWorldTrackingConfiguration()
                    configuration.planeDetection = .horizontal
                    configuration.initialWorldMap = worldMap
                    self?.sceneView.session.run(configuration)
                    self?.addTargets(worldMap) // sends the eggs to the other device
                    self?.worldMapConfigured = true
                }
            } catch {
                SKToast.show(withMessage: "Could not parse world map")
            }
        }
        
        socket.on("otherUsers") { [weak self] data, ack in
            guard let otherUsers = data[0] as? NSDictionary else { return }
            self?.peers = otherUsers as! [String : Int]
            self?.scoreTextView.text = self?.peers.description
        }
    }
}

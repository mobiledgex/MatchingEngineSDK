//
//  WebSocketDelegate.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/2/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import Foundation
import ARKit
import Starscream

extension GameViewController : WebSocketDelegate {
    
    func websocketDidConnect(socket: WebSocketClient) {
        print("Connected")
        ws.write(string: userName!)
    }
    
    func websocketDidDisconnect(socket: WebSocketClient, error: Error?) {
        print("Disconnected")
    }
    
    func websocketDidReceiveMessage(socket: WebSocketClient, text: String) {
        print("Received string")
        if (text == "Username already in use") {
            // Return to loginViewController
            let loginViewController = self.storyboard?.instantiateViewController(withIdentifier: "login") as! LoginViewController
            addChild(loginViewController)
            view.addSubview(loginViewController.view)
            loginViewController.didMove(toParent: self)
            return
        }
        peers[text] = 0
    }
    
    func websocketDidReceiveData(socket: WebSocketClient, data: Data) {
        print("Received data")
        do {
            if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) {
                Swift.print("successfully added world config")
                // Run the session with the received world map
                let configuration = ARWorldTrackingConfiguration()
                configuration.planeDetection = .horizontal
                configuration.initialWorldMap = worldMap
                sceneView.session.run(configuration)
                addTargets(worldMap)// sends the eggs to the other device
            }
        } catch {
            do {
                if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: data) {
                    // add anchor to the session, ARSCNView delegate adds visible content
                    sceneView.session.add(anchor: anchor)
                    Swift.print("successfully added bullet anchor")
                }
            } catch {
                print("anchor is nil")
            }
        }
    }
}

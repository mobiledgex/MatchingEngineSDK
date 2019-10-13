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
            print("socket connected")
            self.socket.emit("login", self.gameID!, self.userName!)
        }
        
        socket.on("repeatUsername") { [weak self] data, ack in
            // Return to loginViewController because of repeated username
            let loginViewController = self?.storyboard?.instantiateViewController(withIdentifier: "login") as! LoginViewController
            self?.addChild(loginViewController)
            self?.view.addSubview(loginViewController.view)
            loginViewController.didMove(toParent: self)
            return
        }
        
        socket.on("bullet") { [weak self] data, ack in
            print("received bullet")
            guard let bulletData = data[0] as? Data else { return }
            do {
                if let anchor = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARAnchor.self, from: bulletData) {
                    // add anchor to the session, ARSCNView delegate adds visible content
                    self?.sceneView.session.add(anchor: anchor)
                    Swift.print("successfully added bullet anchor")
                }
            } catch {
                print("could not get bullet")
            }
        }
        
        socket.on("worldMap") { [weak self] data , ack in
            print("receivedWorldMap")
            guard let worldData = data[0] as? Data else { return }
            do {
                if let worldMap = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: worldData) {
                    Swift.print("successfully added world config")
                    // Run the session with the received world map
                    let configuration = ARWorldTrackingConfiguration()
                    configuration.planeDetection = .horizontal
                    configuration.initialWorldMap = worldMap
                    self?.sceneView.session.run(configuration)
                    self?.addTargets(worldMap)// sends the eggs to the other device
                }
            } catch {
                print("could not get worldMap")
            }
        }
        
        socket.on("username") { [weak self] data, ack in
            print("received new player \(data)")
            guard let newUser = data[0] as? String else { return }
            self?.peers[newUser] = 0
        }
        
        socket.on("otherUsers") { [weak self] data, ack in
            print("received otherUsers \(data)")
            guard let otherUsers = data[0] as? NSDictionary else { return }
            /*for (user, score) in otherUsers {
                self.peers[user] = score
            }*/
            self?.peers = otherUsers as! [String : Int]
            print("peers is \(self?.peers)")
        }
    }

    func sendWorldMapData(data: Data) {
        DispatchQueue.main.async {
            data.withUnsafeBytes{ (u8Ptr: UnsafePointer<UInt8>) in
                let mutRawPointer = UnsafeMutableRawPointer(mutating: u8Ptr)
                //let uploadChunkSize = 4096
                let uploadChunkSize = 4096
                let totalSize = data.count
                Swift.print("data size is \(totalSize)")
                var offset = 0
                var index = totalSize % uploadChunkSize == 0 ? totalSize / uploadChunkSize : (totalSize / uploadChunkSize) + 1
                print("index is \(index)")
                while offset < totalSize {
                    let chunkSize = offset + uploadChunkSize > totalSize ? totalSize - offset : uploadChunkSize
                    let chunk = Data(bytes: mutRawPointer + offset, count: chunkSize)
                    self.socket!.emit("worldMap", self.gameID!, index, chunk)
                    index -= 1
                    offset += chunkSize
                }
            }
        }
    }
}

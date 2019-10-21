//
//  SCNPhysicsContactDelegate.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/2/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import Foundation
import SceneKit

extension GameViewController: SCNPhysicsContactDelegate {
    
    // Called when some contact happens (Case: Bullet hits another bullet) (TODO: Bitwise & instead of ==)
    func physicsWorld(_ world: SCNPhysicsWorld, didEnd contact: SCNPhysicsContact) {
        DispatchQueue.main.async { // Run on background thread
            let nodeA = contact.nodeA
            let nodeB = contact.nodeB
            if nodeA.physicsBody?.categoryBitMask == BitMaskCategory.bullet.rawValue {  // if node A has the bitmask category of a bullet
                self.Target = nodeB
                if nodeA.name != nil {
                    self.peers[nodeA.name!]! += 1
                }
            } else if nodeB.physicsBody?.categoryBitMask == BitMaskCategory.bullet.rawValue {
                self.Target = nodeA
                if nodeB.name != nil {
                    self.peers[nodeB.name!]! += 1
                }
            }
            self.scoreTextView.text = self.peers.description
        }
        let confetti = SCNParticleSystem(named: "Media.scnassets/Confetti.scnp", inDirectory: nil) // gets the confetti scene particle from the Media.scnassets file
        confetti?.loops = false
        confetti?.particleLifeSpan = 4 // Lifespan of animation in seconds
        confetti?.emitterShape = Target?.geometry
        let confettiNode = SCNNode()
        confettiNode.addParticleSystem(confetti!)
        confettiNode.position = contact.contactPoint // places confetti exactly where the collision occured
        self.sceneView.scene.rootNode.addChildNode(confettiNode)
        Target?.removeFromParentNode() // makes the box (egg) disappear
    }
}

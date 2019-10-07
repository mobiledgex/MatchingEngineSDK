//
//  ARSCNViewDelegate.swift
//  ARShooter
//
//  Created by Franlin Huang on 10/2/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import Foundation
import ARKit

extension GameViewController: ARSCNViewDelegate {
    
    // Part of ARSCNView Delegate class
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        // Renders other player's bullets when receive data from server
        let bullet = renderBullet(transform: SCNMatrix4.init(anchor.transform))
        bullet.geometry?.firstMaterial?.diffuse.contents = UIColor.blue
        bullet.name = anchor.name
        bullet.runAction(SCNAction.sequence([SCNAction.wait(duration: 2.0), SCNAction.removeFromParentNode()])) // makes it as soon as the bullet is shot, it is removed after 2 seconds
        node.addChildNode(bullet)
    }
}

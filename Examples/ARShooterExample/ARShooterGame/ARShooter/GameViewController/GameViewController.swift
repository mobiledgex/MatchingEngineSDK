//
//  ViewController.swift
//  ARShooter
//
//  Created by Daniel Kim on 7/30/19.
//  Copyright © 2019 Daniel Kim. All rights reserved.
//

import ARKit
import Starscream

enum BitMaskCategory: Int {
    case bullet = 1
    case target = 2
}

class GameViewController: UIViewController {
    
    @IBOutlet weak var scoreTextView: UITextView!
    @IBOutlet weak var sceneView: ARSCNView!
    @IBOutlet weak var infoLabel: UILabel!
    @IBOutlet weak var mappingStatusLabel: UILabel!
    @IBOutlet weak var sendMapButton: UIButton!
    
    let configuration = ARWorldTrackingConfiguration()
    var power: Float = 50
    var number: Int = 0
    var peerNumber: Int = 0
    var Target: SCNNode?
    
    var userName: String? // Passed from LoginViewController
    var gameID: String? // Passed from LoginViewController
    var peers = [String: Int]() // Passed from LoginViewController
    var host: String? // Host from findCloudlet (MatchingEngine). Passed from LoginViewController
    var ws = WebSocket(url: URL(string: "ws://10.227.67.65:1337/")!, protocols: ["arshooter"]) // Initialize websocket connection
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view
        ws.delegate = self
        ws.connect()
    }
    
    deinit {
        ws.disconnect(forceTimeout: 0)
        ws.delegate = nil
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configuration.planeDetection = .horizontal
        self.sceneView.session.run(configuration)
        sceneView.session.delegate = self // set a delegate to track the number of plane anchors for providing UI feedback
        sceneView.delegate = self
        
        self.sceneView.autoenablesDefaultLighting = true

        self.sceneView.scene.physicsWorld.contactDelegate = self // executes the physics world function
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints]
        UIApplication.shared.isIdleTimerDisabled = true // disable the screen from getting dimmed, as the user will be taking some time to scan the world
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func renderBullet(transform: SCNMatrix4) -> SCNNode {
        let orientation = SCNVector3(-transform.m31,-transform.m32,-transform.m33) // orientation is encoded in the third column matrix. -Z axis points from camera out
        let location = SCNVector3(transform.m41,transform.m42,transform.m43) // position of the camera/user. Translation vector is encoded in the fourth column matrix
        let position = location
        let bullet = SCNNode(geometry: SCNSphere(radius: 0.1))
        bullet.position = position
        let body = SCNPhysicsBody(type: .dynamic, shape: SCNPhysicsShape(node: bullet, options: nil)) // needs the physics body in order to shoot the bullet, dynamic in order for our bullet to be affected by forces , shape of a bullet
        body.isAffectedByGravity = false // doesn't experience any gravity
        bullet.physicsBody = body
    bullet.physicsBody?.applyForce(SCNVector3(orientation.x*power,orientation.y*power,orientation.z*power), asImpulse: true) // makes the sphere shoot like a bullet
        bullet.physicsBody?.categoryBitMask = BitMaskCategory.bullet.rawValue // gives the value of bullet to two
        bullet.physicsBody?.contactTestBitMask = BitMaskCategory.target.rawValue // tells the physicsworld to watch out for any collision between the bullet and the raw value (egg)
        return bullet
    }
    
    
    // sends bullet when user taps on the screen
    @IBAction func sendBullets(_ sender: UITapGestureRecognizer) {
        guard let sceneView = sender.view as? ARSCNView else{return} // makes sure that the view you tapped on is the scene view
        guard let pointOfView = sceneView.pointOfView else{return} // receives the point of view of the sceneView
        let transform = pointOfView.transform // gets the transform matrix from point of view (4x4 matrix)
        let bullet = renderBullet(transform: transform)
        bullet.name = userName!
        bullet.geometry?.firstMaterial?.diffuse.contents = UIColor.red
        bullet.runAction(SCNAction.sequence([SCNAction.wait(duration: 2.0), SCNAction.removeFromParentNode()])) // makes it as soon as the bullet is shot, it is removed after 2 seconds
        let anchor = ARAnchor(name: userName!, transform: simd_float4x4(transform))
        
        self.sceneView.scene.rootNode.addChildNode(bullet)
        guard let data = try? NSKeyedArchiver.archivedData(withRootObject: anchor, requiringSecureCoding: true) else{fatalError("can't encode anchor")}

        ws.write(data: data)
    }
    
    // sends the world map and the eggs to be displayed on the screen
    @IBAction func addTargets(_ sender: Any) { // eggs are added to the AR World
        self.addegg(x: 1, y: 0, z: -1.5)
        self.addegg(x: 0, y: 0, z: -1.5)
        self.addegg(x: -1, y: 0, z: -1.5)
        self.addegg(x: -2,y: 0, z: -1.5)
        self.addegg(x: 2, y: 0, z: -1.5)
    }
    
    // creates the eggnode and displays the egg image into ARSCNView
    func addegg(x: Float, y: Float, z: Float){ // creates a node that includes the image of the egg and sends the information to the other user
        let eggScene = SCNScene(named: "Media.scnassets/egg.scn")
        let eggNode = (eggScene?.rootNode.childNode(withName: "egg", recursively: false))! // creates the egg node and
        eggNode.position = SCNVector3(x,y,z)
        eggNode.physicsBody = SCNPhysicsBody(type: .static, shape: SCNPhysicsShape(node: eggNode, options: nil)) // makes it so that the objecgt is in the form of a egg
        eggNode.physicsBody?.categoryBitMask = BitMaskCategory.target.rawValue // gave the category of the target value
        eggNode.physicsBody?.contactTestBitMask = BitMaskCategory.bullet.rawValue // watch for any collisions between egg and bullet
        self.sceneView.scene.rootNode.addChildNode(eggNode)
    }
    
    // shares the AR World Map between peer devices ,
    @IBAction func shareSession(_ sender: UIButton) { // shares the AR World map with server, which will forward to other devices
        sceneView.session.getCurrentWorldMap { worldMap, error in
            guard let map = worldMap
                else { print("Error: \(error!.localizedDescription)"); return }
            guard let data = try? NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                else { fatalError("can't encode map") }
            Swift.print("sending world map")
            self.ws.write(data: data)
        }
    }
}

func +(left: SCNVector3, right: SCNVector3) -> SCNVector3{ // method to add SCNVectors together
    return SCNVector3Make(left.x + right.x, left.y + right.y, left.z + right.z)}

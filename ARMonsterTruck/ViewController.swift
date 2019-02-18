/**
 * Copyright (c) 2018 Razeware LLC
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
 * distribute, sublicense, create a derivative work, and/or sell copies of the
 * Software in any work that is designed, intended, or marketed for pedagogical or
 * instructional purposes related to programming, coding, application development,
 * or information technology.  Permission for such use, copying, modification,
 * merger, publication, distribution, sublicensing, creation of derivative works,
 * or sale is expressly withheld.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

import UIKit
import SceneKit
import ARKit

// MARK: - Game State
enum GameState: Int16 {
  case detectSurface
  case hitStartToPlay
  case playGame
}

class ViewController: UIViewController {
  
  // MARK: - Properties
  var trackingStatus: String = ""
  var statusMessage: String = ""
  var gameState: GameState = .detectSurface
  var focusPoint:CGPoint!
  var focusNode: SCNNode!
    var truckNode: SCNNode!
    var wheelFLNode: SCNNode!
    var wheelFRNode: SCNNode!
    var wheelRLNode: SCNNode!
    var wheelRRNode: SCNNode!
    
    let wheelRadius: CGFloat = 0.04
    let wheelFrictionSlip: CGFloat = 0.9
    let suspensionMaxTravel: CGFloat = 4.0
    let suspensionMaxForce: CGFloat = 100
    let suspensionRestLength: CGFloat = 0.08
    let suspensionDamping: CGFloat = 2.0
    let suspensionStiffness: CGFloat = 2.0
    let suspensionCompression: CGFloat = 4.0
    
    var physicsVehicle:SCNPhysicsVehicle!
  
  // MARK: Outlets
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet var statusLabel: UILabel!
  @IBOutlet var startButton: UIButton!
  @IBOutlet var resetButton: UIButton!
  
  // MARK: Actions
  @IBAction func startButtonPressed(_ sender: Any) {
    self.startGame()
  }
  
  @IBAction func resetButtonPressed(_ sender: Any) {
    self.resetGame()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    self.initSceneView()
    self.initScene()
    self.initARSession()
    self.loadModels()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    print("*** ViewWillAppear()")
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    print("*** ViewWillDisappear()")
  }
  
  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    print("*** DidReceiveMemoryWarning()")
  }
  
  override var prefersStatusBarHidden: Bool {
    return true
  }
  
  override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
    return .landscapeRight
  }
  
  // MARK: Init Functions
  
  func initSceneView() {
    sceneView.delegate = self
    sceneView.automaticallyUpdatesLighting = false
    //sceneView.showsStatistics = true
    //sceneView.preferredFramesPerSecond = 60
    //sceneView.antialiasingMode = .multisampling2X
    sceneView.debugOptions = [
      //ARSCNDebugOptions.showFeaturePoints,
      //ARSCNDebugOptions.showWorldOrigin,
      //SCNDebugOptions.showPhysicsShapes,
      //SCNDebugOptions.showBoundingBoxes
    ]
    
    focusPoint = CGPoint(x: view.center.x, y: view.center.y + view.center.y * 0.25)
  }
  
  func initScene() {
    let scene = SCNScene()
    scene.lightingEnvironment.contents = "MonsterTruck.scnassets/Textures/Environment_CUBE.jpg"
    scene.lightingEnvironment.intensity = 4
    scene.physicsWorld.speed = 1
    //scene.physicsWorld.timeStep = 1.0 / 60.0 // Physics Precision
    scene.isPaused = false
    sceneView.scene = scene
  }
  
  func initARSession() {
    
    guard ARWorldTrackingConfiguration.isSupported else {
      print("*** ARConfig: AR World Tracking Not Supported")
      return
    }
    
    let config = ARWorldTrackingConfiguration()
    config.isLightEstimationEnabled = true
    config.planeDetection = .horizontal
    config.worldAlignment = .gravity
    config.providesAudioData = false
    sceneView.session.run(config)
  }
  
  func resetARSession() {
    let config = sceneView.session.configuration as! ARWorldTrackingConfiguration
    config.planeDetection = .horizontal
    sceneView.session.run(config,
                          options: [.resetTracking,
                                    .removeExistingAnchors])
  }
  
  func suspendARPlaneDetection() {
    let config = sceneView.session.configuration as! ARWorldTrackingConfiguration
    config.planeDetection = []
    sceneView.session.run(config)
  }
  
  
  // MARK: Helper Functions
    
    func createPhysicsVehicleWheel(wheelNode: SCNNode,
                                   position: SCNVector3) -> SCNPhysicsVehicleWheel {
        let wheel = SCNPhysicsVehicleWheel(node: wheelNode)
        wheel.connectionPosition = position
        wheel.axle = SCNVector3(x: -1.0, y: 0, z: 0)
        wheel.maximumSuspensionTravel = suspensionMaxTravel
        wheel.maximumSuspensionForce = suspensionMaxForce
        wheel.suspensionRestLength = suspensionRestLength
        wheel.suspensionDamping = suspensionDamping
        wheel.suspensionStiffness = suspensionStiffness
        wheel.suspensionCompression = suspensionCompression
        wheel.radius = wheelRadius
        wheel.frictionSlip = wheelFrictionSlip
        return wheel
    }
    
    func createVehiclePhysics() {
        // 1
        if physicsVehicle != nil {
            sceneView.scene.physicsWorld.removeBehavior(physicsVehicle)
        }
        //2
        let wheelFL = createPhysicsVehicleWheel(
            wheelNode: wheelFLNode!,
            position: SCNVector3(x: -0.07, y: 0.04, z: 0.06))
        let wheelFR = createPhysicsVehicleWheel(
            wheelNode: wheelFRNode!,
            position: SCNVector3(x: 0.07, y: 0.04, z: 0.06))
        let wheelRL = createPhysicsVehicleWheel(
            wheelNode: wheelRLNode!,
            position: SCNVector3(x: -0.07, y: 0.04, z: -0.06))
        let wheelRR = createPhysicsVehicleWheel(
            wheelNode: wheelRRNode!,
            position: SCNVector3(x: 0.07, y: 0.04, z: -0.06))
        // 3
        physicsVehicle = SCNPhysicsVehicle(
            chassisBody: truckNode.physicsBody!,
            wheels: [wheelFL, wheelFR, wheelRL, wheelRR])
        // 4
        sceneView.scene.physicsWorld.addBehavior(physicsVehicle)
    }
  
  func createARPlaneNode(planeAnchor: ARPlaneAnchor, color: UIColor) -> SCNNode {
    
    // 1 - Create plane geometry using anchor extents
    let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                 height: CGFloat(planeAnchor.extent.z))
    
    // 2 - Create meterial with just a diffuse color
    let planeMaterial = SCNMaterial()
    planeMaterial.diffuse.contents = color
    planeGeometry.materials = [planeMaterial]
    
    // 3 - Create plane node
    let planeNode = SCNNode(geometry: planeGeometry)
    planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
    planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
    
    return planeNode
  }
  
  func updateARPlaneNode(planeNode: SCNNode, planeAchor: ARPlaneAnchor) {
    
    // 1 - Update plane geometry with planeAnchor details
    let planeGeometry = planeNode.geometry as! SCNPlane
    planeGeometry.width = CGFloat(planeAchor.extent.x)
    planeGeometry.height = CGFloat(planeAchor.extent.z)
    
    // 2 - Update plane position
    planeNode.position = SCNVector3Make(planeAchor.center.x, 0, planeAchor.center.z)
  }
  
  func removeARPlaneNode(node: SCNNode) {
    for childNode in node.childNodes {
      childNode.removeFromParentNode()
    }
  }
  
  // MARK: Update Functions
    
    func updatePositions() {
        // 1
        self.truckNode.position = self.focusNode.position
        self.truckNode.position.y += 0.20
        // 2
        self.truckNode.physicsBody?.velocity = SCNVector3Zero
        self.truckNode.physicsBody?.angularVelocity = SCNVector4Zero
        // 3
        self.truckNode.physicsBody?.resetTransform()
    }
  
  func updateStatus() {
    switch gameState {
    case .detectSurface: statusMessage = "Detecting surfaces..."
    case .hitStartToPlay: statusMessage = "Hit START to play!"
    case .playGame: statusMessage = "Touch to Throttle, Tilt to Steer!"
    }
    
    self.statusLabel.text = trackingStatus != "" ?
      "\(trackingStatus)" : "\(statusMessage)"
  }
  
  func updateFocusNode() {
    
    // Hide Focus Node
    if gameState == .playGame {
      self.focusNode.isHidden = true
      return
    }
    
    // Show Focus Node
    self.focusNode.isHidden = false
    
    let results = self.sceneView.hitTest(self.focusPoint, types: [.existingPlaneUsingExtent])
    
    if results.count >= 1 {
      if let match = results.first {
        let t = match.worldTransform
        self.focusNode.position = SCNVector3(x: t.columns.3.x, y: t.columns.3.y, z: t.columns.3.z)
        self.gameState = .hitStartToPlay
      }
    } else {
      self.gameState = .detectSurface
    }
  }
  
  // MARK: Game Management
  
  func startGame() {
    
  }
  
  func resetGame(){
    
  }
  
  func loadModels() {
    
    // Load Focus Node
    let focusScene = SCNScene(named: "MonsterTruck.scnassets/Models/Focus.scn")!
    focusNode = focusScene.rootNode.childNode(withName: "Focus", recursively: false)
    focusNode.isHidden = true
    sceneView.scene.rootNode.addChildNode(focusNode)
    
    // 1
    let truckScene = SCNScene(
        named: "MonsterTruck.scnassets/Models/MonsterTruck.scn")!
    truckNode = truckScene.rootNode.childNode(
        withName: "Truck", recursively: true)
    wheelFLNode = truckScene.rootNode.childNode(
        withName: "Wheel_FL", recursively: true)
    wheelFRNode = truckScene.rootNode.childNode(
        withName: "Wheel_FR", recursively: true)
    wheelRLNode = truckScene.rootNode.childNode(
        withName: "Wheel_RL", recursively: true)
    wheelRRNode = truckScene.rootNode.childNode(
        withName: "Wheel_RR", recursively: true)
    // 2
    truckNode.addChildNode(wheelFLNode!)
    truckNode.addChildNode(wheelFRNode!)
    truckNode.addChildNode(wheelRLNode!)
    truckNode.addChildNode(wheelRRNode!)
    // 3
    truckNode.isHidden = true
    sceneView.scene.rootNode.addChildNode(truckNode)
  }
}




extension ViewController : ARSCNViewDelegate {
  
  // MARK: - SceneKit Management
  
  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    DispatchQueue.main.async {
      self.updateStatus()
      self.updateFocusNode()
    }
  }
  
  // MARK: - AR Session State Management
  
  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    switch camera.trackingState {
    case .notAvailable:
      self.trackingStatus = "Tacking:  Not available!"
      break
    case .normal:
      self.trackingStatus = "" // Tracking Normal
      break
    case .limited(let reason):
      switch reason {
      case .excessiveMotion:
        self.trackingStatus = "Tracking: Limited due to excessive motion!"
        break
      case .insufficientFeatures:
        self.trackingStatus = "Tracking: Limited due to insufficient features!"
        break
      case .relocalizing:
        self.trackingStatus = "Tracking: Resuming..."
        break
      case .initializing:
        self.trackingStatus = "Tracking: Initializing..."
        break
      }
    }
  }
  
  // MARK: - AR Session Error Managent
  
  func session(_ session: ARSession, didFailWithError error: Error) {
    // Present an error message to the user
    self.trackingStatus = "AR Session Failure: \(error)"
  }
  
  func sessionWasInterrupted(_ session: ARSession) {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    self.trackingStatus = "AR Session Was Interrupted!"
  }
  
  func sessionInterruptionEnded(_ session: ARSession) {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    self.trackingStatus = "AR Session Interruption Ended"
    self.resetGame()
  }
  
  // MARK: - Plane Management
  
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
    DispatchQueue.main.async {
      let planeNode = self.createARPlaneNode(
        planeAnchor: planeAnchor,
        color: UIColor.blue.withAlphaComponent(0))
      node.addChildNode(planeNode)
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let planeAnchor = anchor as? ARPlaneAnchor else { return }
    DispatchQueue.main.async {
      self.updateARPlaneNode(
        planeNode: node.childNodes[0],
        planeAchor: planeAnchor)
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
    guard anchor is ARPlaneAnchor else { return }
    DispatchQueue.main.async {
      self.removeARPlaneNode(node: node)
    }
  }
}

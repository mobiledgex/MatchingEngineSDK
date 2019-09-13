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
//  FaceDetectionViewController.swift
//  VisionDetection
//
//  Created by Wei Chieh Tseng on 09/06/2017.
//  Copyright © 2017 Willjay. All rights reserved.
//

import AVFoundation
import UIKit
import Vision

import NSLogger
import Promises
import MatchingEngine

//var doAFaceDetection = true
var faceDetectCount:OSAtomicInt32 = OSAtomicInt32(0)
var pendingCount:OSAtomicInt32 = OSAtomicInt32(0)

// Note: we build array of images with service (image,service)
var doAFaceRecognition = false


enum MexKind: Int
{
    case mexCloud
    case mexEdge
}

//let faceDetectionEdge = MexFaceRecognition()
//let faceDetectionCloud = MexFaceRecognition()

let faceDetectionRecognition = MexFaceRecognition()


class FaceDetectionViewController: UIViewController
{
    // VNRequest: Either Retangles or Landmarks
    var faceDetectionRequest: VNRequest!

    var sentImageSize = CGSize(width: 0, height: 0)
    @IBOutlet var latencyCloudLabel: UILabel! // left green
    @IBOutlet var latencyEdgeLabel: UILabel! // right orange

    @IBOutlet var faceRecognitionLatencyCloudLabel: UILabel!
    @IBOutlet var faceRecognitionLatencyEdgeLabel: UILabel!

    @IBOutlet var networkLatencyCloudLabel: UILabel! //
    @IBOutlet var networkLatencyEdgeLabel: UILabel! //

    // @IBOutlet weak var faceRecognitonNameLabel: UILabel! // todo remove
    @IBOutlet var faceRecognitonNameCloudLabel: UILabel! //
    @IBOutlet var faceRecognitonNameEdgeLabel: UILabel! //

    @IBOutlet var stddevCloudLabel: UILabel!
    @IBOutlet var stddevEdgeLabel: UILabel!  

    var futureEdge: Promise<[String: AnyObject]>? // async result (captured by async?)
    var futureCloud: Promise<[String: AnyObject]>? // async result (captured by async?)

    var faceDetectionEdgePromise: Promise<[String: AnyObject]>?
    var faceDetectionCloudPromise: Promise<[String: AnyObject]>?

     var calcRollingAverageCloud = MovingAverage()
    var rollingAverageCloud = 0.0

    var calcRollingAverageEdge = MovingAverage()
    var rollingAverageEdge = 0.0

    var usingFrontCamera = false

    override func viewDidLoad()
    {
        super.viewDidLoad()

        // Set up the video preview view.
        previewView.session = session

        // Set up Vision Request
        faceDetectionRequest = VNDetectFaceRectanglesRequest(completionHandler: handleFaces) // Default
        setupVision()

        /*
         Check video authorization status. Video access is required and audio
         access is optional. If audio access is denied, audio is not recorded
         during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break

        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. We suspend the session queue to delay session
             setup until the access request has completed.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [unowned self] granted in
                if !granted
                {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })

        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }

        /*
         Setup the capture session.
         In general it is not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.

         Why not do all of this on the main queue?
         Because AVCaptureSession.startRunning() is a blocking call which can
         take a long time. We dispatch session setup to the sessionQueue so
         that the main queue isn't blocked, which keeps the UI responsive.
         */

        sessionQueue.async
        { [unowned self] in
            self.configureSession()
        }

        /// --- t

        let barButtonItem = UIBarButtonItem(title: "X-cameras", style: .plain, target: self, action: #selector(FaceDetectionViewController.switchButtonAction(sender:)))


        navigationItem.rightBarButtonItem = barButtonItem

        // ---

        let tv = UserDefaults.standard.bool(forKey: "doFaceRecognition") //

        title = tv ? "Face Recognition" : "Face Dectection"

        // ---

        let latencyCloud = UserDefaults.standard.string(forKey: "latencyCloud")
       networkLatencyCloudLabel.text = latencyCloud != nil ? "latencyCloud: \(latencyCloud!) ms" : "Cloud: None ms"
        
        let latencyEdge = UserDefaults.standard.string(forKey: "latencyEdge")

        networkLatencyEdgeLabel.text = latencyEdge != nil ? "Edge: \(latencyEdge!) ms" : "Edge: None ms"

        // ---

        let localProcessing = UserDefaults.standard.bool(forKey: "Show full process latency")
        if localProcessing == true
        {
            latencyCloudLabel.isHidden = false
            latencyEdgeLabel.isHidden = false
        }

        if true
        {
            faceRecognitionLatencyCloudLabel.isHidden = false
            faceRecognitionLatencyCloudLabel.isHidden = false
        }

        let showNetworkLantency = UserDefaults.standard.bool(forKey: "Show network latency")

        if showNetworkLantency
        {
            networkLatencyCloudLabel.isHidden = false
            networkLatencyEdgeLabel.isHidden = false
        }
        else
        {
            networkLatencyCloudLabel.isHidden = true
            networkLatencyEdgeLabel.isHidden = true
        }
        
        let showStddev = UserDefaults.standard.bool(forKey: "Show Stddev")

        if showStddev
        {
            stddevCloudLabel.isHidden = false
            stddevEdgeLabel.isHidden = false
        }
        else
        {
            stddevCloudLabel.isHidden = true
            stddevEdgeLabel.isHidden = true
        }
        
     }
    
    

    
    @objc public func stopIt(sender _: UIBarButtonItem)
    {
        Swift.print("stop")     // Log
        session.stopRunning()    
    }

    override func viewWillAppear(_ animated: Bool)
    {
        super.viewWillAppear(animated)

        sessionQueue.async
        { [unowned self] in
            switch self.setupResult
            {
            case .success:
                // Only setup observers and start the session running if setup succeeded.
                self.addObservers()
                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning

            case .notAuthorized:
                DispatchQueue.main.async
                { [unowned self] in
                    let message = NSLocalizedString("AVCamBarcode doesn't have permission to use the camera, please change privacy settings",
                                                    comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AppleFaceDetection", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"), style: .default, handler: { _ in
                        UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
                    }))

                    self.present(alertController, animated: true, completion: nil)
                }

            case .configurationFailed:
                DispatchQueue.main.async
                { [unowned self] in
                    let message = NSLocalizedString("Unable to capture media", comment: "Alert message when something goes wrong during capture session configuration")
                    let alertController = UIAlertController(title: "AppleFaceDetection", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))

                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        sessionQueue.async
        { [unowned self] in
            if self.setupResult == .success
            {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
                self.removeObservers()
            }
        }

        super.viewWillDisappear(animated)
        
        
        if true
        {
            Logger.shared.log(.network, .info, "CLOUD \n" )
            Logger.shared.log(.network, .info, "latency: \(latencyCloudLabel.text)) " )
            Logger.shared.log(.network, .info, "latency rec:\(faceRecognitionLatencyCloudLabel.text)) " )
           Logger.shared.log(.network, .info, "latency network \(networkLatencyCloudLabel.text)) " )
            Logger.shared.log(.network, .info, " stddev\(stddevCloudLabel.text)) " )
            Logger.shared.log(.network, .info, "name: \(faceRecognitonNameCloudLabel.text)) " )

        }
        if true
        {
            Logger.shared.log(.network, .info, "EDGE \n" )
            Logger.shared.log(.network, .info, "latency detect \(latencyEdgeLabel.text)) " )
            Logger.shared.log(.network, .info, "latency rec \(faceRecognitionLatencyEdgeLabel.text)) " )
            Logger.shared.log(.network, .info, "network latency \(networkLatencyEdgeLabel.text)) " )
            Logger.shared.log(.network, .info, "name \(faceRecognitonNameEdgeLabel.text)) " )
            Logger.shared.log(.network, .info, "stddev: \(stddevEdgeLabel.text)) " )
            
        }
        
        UserDefaults.standard.set( "", forKey: "latencyCloud")
        UserDefaults.standard.set( "", forKey: "latencyEdge")
        
        let latencyEdge = UserDefaults.standard.string(forKey: "latencyEdge")

    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
    {
        super.viewWillTransition(to: size, with: coordinator)

        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection
        {
            let deviceOrientation = UIDevice.current.orientation
            guard let newVideoOrientation = deviceOrientation.videoOrientation, deviceOrientation.isPortrait || deviceOrientation.isLandscape else
            {
                return
            }

            videoPreviewLayerConnection.videoOrientation = newVideoOrientation
        }
    }

    @IBAction func UpdateDetectionType(_ sender: UISegmentedControl)
    {
        // use segmentedControl to switch over VNRequest
        faceDetectionRequest = sender.selectedSegmentIndex == 0 ? VNDetectFaceRectanglesRequest(completionHandler: handleFaces) : VNDetectFaceLandmarksRequest(completionHandler: handleFaceLandmarks)

        setupVision()
    }

    @IBOutlet var previewView: PreviewView!

    // MARK: Session Management

    private enum SessionSetupResult
    {
        case success
        case notAuthorized
        case configurationFailed
    }

    private var devicePosition: AVCaptureDevice.Position = .back

    private let session = AVCaptureSession()
    private var isSessionRunning = false

    private let sessionQueue = DispatchQueue(label: "session queue", attributes: [], target: nil) // Communicate with the session and other session objects on this queue.

    private var setupResult: SessionSetupResult = .success

    private var videoDeviceInput: AVCaptureDeviceInput!

    private var videoDataOutput: AVCaptureVideoDataOutput!
    private var videoDataOutputQueue = DispatchQueue(label: "VideoDataOutputQueue")

    private var requests = [VNRequest]()

    private func configureSession()
    {
        if setupResult != .success
        {
            return
        }

        for i : AVCaptureDeviceInput in (session.inputs as! [AVCaptureDeviceInput])
        {
            self.session.removeInput(i)
        }
        
        session.beginConfiguration()
        session.sessionPreset = .high

        // Add video input.
        do
        {
            var defaultVideoDevice: AVCaptureDevice?

            // Choose the back dual camera if available, otherwise default to a wide angle camera.
            if let dualCameraDevice = AVCaptureDevice.default(.builtInDualCamera, for: AVMediaType.video, position: .back)
            {
                defaultVideoDevice = dualCameraDevice
            }

            else if let backCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back)
            {
                defaultVideoDevice = backCameraDevice
            }

            else if let frontCameraDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .front)
            {
                defaultVideoDevice = frontCameraDevice
            }

            defaultVideoDevice = (usingFrontCamera ? getFrontCamera() : getBackCamera())

            guard let _ = defaultVideoDevice else {
                Logger.shared.log(.network, .info, "There is no available video capture device!")
                setupResult = .configurationFailed
                return
            }
            
            let videoDeviceInput = try AVCaptureDeviceInput(device: defaultVideoDevice!)
            
            
            for i : AVCaptureDeviceInput in (session.inputs as! [AVCaptureDeviceInput])
            {
                self.session.removeInput(i)
            }
            
            
            if session.canAddInput(videoDeviceInput)
            {
                session.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                DispatchQueue.main.async
                {
                    /*
                     Why are we dispatching this to the main queue?
                     Because AVCaptureVideoPreviewLayer is the backing layer for PreviewView and UIView
                     can only be manipulated on the main thread.
                     Note: As an exception to the above rule, it is not necessary to serialize video orientation changes
                     on the AVCaptureVideoPreviewLayer’s connection with other session manipulation.

                     Use the status bar orientation as the initial video orientation. Subsequent orientation changes are
                     handled by CameraViewController.viewWillTransition(to:with:).
                     */
                    let statusBarOrientation = UIApplication.shared.statusBarOrientation
                    var initialVideoOrientation: AVCaptureVideoOrientation = .portrait
                    if statusBarOrientation != .unknown
                    {
                        if let videoOrientation = statusBarOrientation.videoOrientation
                        {
                            initialVideoOrientation = videoOrientation
                        }
                    }
                    self.previewView.videoPreviewLayer.connection!.videoOrientation = initialVideoOrientation
                }
            }

            else
            {
                print("Could not add video device input to the session")
                setupResult = .configurationFailed
                session.commitConfiguration()
                return
            }
        }
        catch
        {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // add output
        videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [(kCVPixelBufferPixelFormatTypeKey as String): Int(kCVPixelFormatType_32BGRA)]

        if session.canAddOutput(videoDataOutput)
        {
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
            session.addOutput(videoDataOutput)
        }
        else
        {
            print("Could not add metadata output to the session")
       //     setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        session.commitConfiguration()
    }

    private func availableSessionPresets() -> [String]
    {
        let allSessionPresets = [AVCaptureSession.Preset.photo,
                                 AVCaptureSession.Preset.low,
                                 AVCaptureSession.Preset.medium,
                                 AVCaptureSession.Preset.high,
                                 AVCaptureSession.Preset.cif352x288,
                                 AVCaptureSession.Preset.vga640x480,
                                 AVCaptureSession.Preset.hd1280x720,
                                 AVCaptureSession.Preset.iFrame960x540,
                                 AVCaptureSession.Preset.iFrame1280x720,
                                 AVCaptureSession.Preset.hd1920x1080,
                                 AVCaptureSession.Preset.hd4K3840x2160]

        var availableSessionPresets = [String]()
        for sessionPreset in allSessionPresets
        {
            if session.canSetSessionPreset(sessionPreset)
            {
                availableSessionPresets.append(sessionPreset.rawValue)
            }
        }

        return availableSessionPresets
    }

    func exifOrientationFromDeviceOrientation() -> UInt32
    {
        enum DeviceOrientation: UInt32
        {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        var exifOrientation: DeviceOrientation

        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = devicePosition == .front ? .bottom0ColRight : .top0ColLeft
        case .landscapeRight:
            exifOrientation = devicePosition == .front ? .top0ColLeft : .bottom0ColRight
        default:
            exifOrientation = .right0ColTop
        }
        return exifOrientation.rawValue
    }
}

extension FaceDetectionViewController
{
    private func addObservers()
    {
        /*
         Observe the previewView's regionOfInterest to update the AVCaptureMetadataOutput's
         rectOfInterest when the user finishes resizing the region of interest.
         */
        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: Notification.Name("AVCaptureSessionRuntimeErrorNotification"), object: session)

        /*
         A session can only run when the app is full screen. It will be interrupted
         in a multi-app layout, introduced in iOS 9, see also the documentation of
         AVCaptureSessionInterruptionReason. Add observers to handle these session
         interruptions and show a preview is paused message. See the documentation
         of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
         */
        NotificationCenter.default.addObserver(self, selector: #selector(sessionWasInterrupted), name: Notification.Name("AVCaptureSessionWasInterruptedNotification"), object: session)
        NotificationCenter.default.addObserver(self, selector: #selector(sessionInterruptionEnded), name: Notification.Name("AVCaptureSessionInterruptionEndedNotification"), object: session)

        if true
        {
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "FaceDetectionCloud"), object: nil, queue: nil)
            { notification in
                 Swift.print("FaceDetectionCloud \(notification)")
                
                let d = notification.object as! [[Int]]
                
                // SKToast.show(withMessage: "FaceDetection raw result\(d)")
                
                // Swift.print("FaceDetection\n\(d)")
                
                let a = d[0] // get face rect

            }
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "FaceDetectionEdge"), object: nil, queue: nil)
            { notification in
                // Swift.print("FaceDetectionEdge \(notification)")
                
                let d = notification.object as! [[Int]]
                
                // SKToast.show(withMessage: "FaceDetection raw result\(d)")
                
                // Swift.print("FaceDetection\n\(d)")
                
                let a = d[0] // get face rect
                
            }
            
            
            NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "FaceDetection"), object: nil, queue: nil)
            { notification in
                // Swift.print("RegisterClient \(notification)")

                let d = notification.object as! [[Int]]

                // SKToast.show(withMessage: "FaceDetection raw result\(d)")

                // Swift.print("FaceDetection\n\(d)")

                let a = d[0] // get face rect

                // let r = CGRect(CGFloat(a[0]), CGFloat(a[1]), CGFloat(a[2] - a[0]), CGFloat(a[3] - a[1])) // face rect
                let r = convertPointsToRect(a)

                self.previewView.drawFaceboundingBox2(rect: r, hint: self.sentImageSize)

              //  Swift.print("face r= \(r)")
                SKToast.show(withMessage: "FaceDetection result: \(r)")

   //             Swift.print("--------- do next doAFaceDetection")
                print(".", terminator:"")
            }
        }

        NotificationCenter.default.addObserver(self, selector: #selector(FaceDetectionLatencyCloud), name: Notification.Name("FaceDetectionLatencyCloud"), object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(FaceDetectionLatencyEdge), name: Notification.Name("FaceDetectionLatencyEdge"), object: nil)

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "faceRecognitionLatencyEdge"), object: nil, queue: nil) // updateNetworkLatencies
        { [weak self] notification in
            guard let _ = self else { return }

            let v = notification.object as! String

          //  Swift.print("updateNetworkLatenciesEdge: \(v)")

            DispatchQueue.main.async
            {
                self!.faceRecognitionLatencyEdgeLabel.text = "Edge: \(v) ms"
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "faceRecognitionLatencyCloud"), object: nil, queue: nil) // updateNetworkLatencies
        { [weak self] notification in
            guard let _ = self else { return }

            let v = notification.object as! String

    //        Swift.print("faceRecognitionLatencyCloud: \(v)")

            DispatchQueue.main.async
            {
                self!.faceRecognitionLatencyCloudLabel.text = "cloud: \(v) ms"

            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "updateNetworkLatenciesCloud"), object: nil, queue: nil) // updateNetworkLatencies
        { [weak self] notification in
            guard let _ = self else { return } // canceled

            let v = notification.object as! String

          //  Swift.print("updateNetworkLatenciesCloud")
            //Swift.print("cloud: \(v)")

            DispatchQueue.main.async
            {
                self!.networkLatencyCloudLabel.text = "Cloud: \(v) ms"
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "updateNetworkLatenciesEdge"), object: nil, queue: nil) // updateNetworkLatencies
        { [weak self] notification in
            guard let _ = self else { return }

            let v = notification.object as! String

        //    Swift.print("updateNetworkLatenciesEdge")
         //   Swift.print("edge: \(v)")

            DispatchQueue.main.async
            {
                self!.networkLatencyEdgeLabel.text = "Edge: \(v) ms"
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "faceRecognizedCloud"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }

            let d = notification.object as! [String: Any]

       //     Swift.print("faceRecognizedCloud: \(d)")

            let name = d["subject"] as! String
            let a = d["rect"] as! [Int]

            // let r = CGRect(CGFloat(a[0]), CGFloat(a[1]), CGFloat(a[2] - a[0]), CGFloat(a[3] - a[1])) // face rect
            let r = convertPointsToRect(a)


            DispatchQueue.main.async
            {
                let _ = self!.previewView.drawFaceboundingBoxCloud(rect: r, hint: self!.sentImageSize)

                self!.faceRecognitonNameCloudLabel.text = name
                self!.faceRecognitonNameCloudLabel.isHidden = false

                self!.faceRecognitonNameCloudLabel.center = CGPoint(x: r.midX, y: r.origin.y - 20) // above
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "faceRecognizedEdge"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }

            let d = notification.object as! [String: Any] // Dictionary/json

            self!.previewView.removeMaskLayerMexEdge()

            if d["success"] as! String == "true"
            {
                let subject = d["subject"] as! String

               // Swift.print("\(notification.name): \(d)")

                // SKToast.show(withMessage: "FaceDetection raw result\(d)")

                // Swift.print("FaceDetection\n\(d)")

                //   let r = CGRect(CGFloat(a[0]), CGFloat(a[1]), CGFloat(a[2] - a[0]), CGFloat(a[3] - a[1])) // face rect
                // let r = convertPointsToRect(a)


                let a = d["rect"] as! [Int]
                let r = convertPointsToRect(a)


                DispatchQueue.main.async
                {
                    let r2 = self!.previewView.drawFaceboundingBoxEdge(rect: r, hint: self!.sentImageSize)

                    // Swift.print("subject \(subject)")
                    self!.faceRecognitonNameEdgeLabel.text = subject
                    self!.faceRecognitonNameEdgeLabel.isHidden = false

                    self!.faceRecognitonNameEdgeLabel.center = CGPoint(x: r2.midX, y: r2.origin.y + r2.size.height + 20) // below
                    // Swift.print("\(r)")
                }
            }
            else
            {
                self!.faceRecognitonNameEdgeLabel.text = ""
            }
        }

        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "faceDetectedCloud"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            let d = notification.object as! [String: Any] // Dictionary/json
            
            DispatchQueue.main.async
            {
                    self!.previewView.removeMaskLayerMexCloud()
                    
                    if d["success"] as! String == "true"
                    {
                        let aa = d["rects"] as! [[Int]]
                        for a in aa
                        {
                            let r = convertPointsToRect(a)
                            
                            let _ = self!.previewView.drawFaceboundingBoxCloud(rect: r, hint: self!.sentImageSize)
                            
                            let multiface = UserDefaults.standard.bool(forKey: "Multi-face")
                            if multiface == false
                            {
                                break
                            }
                        }
                    }
                    else
                    {}
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "faceDetectedEdge"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            let d = notification.object as! [String: Any] // Dictionary/json
            
            DispatchQueue.main.async
                {
                    self!.previewView.removeMaskLayerMexEdge()
                    
                    //      if  d["success"] as! Bool == true
                    if d["success"] as! String == "true"
                    {
                        let aa = d["rects"] as! [[Int]]
                        for a in aa
                        {
                            let r = convertPointsToRect(a)
                            
                            
                            let _ = self!.previewView.drawFaceboundingBoxEdge(rect: r, hint: self!.sentImageSize)
                            
                            let multiface = UserDefaults.standard.bool(forKey: "Multi-face")
                            if multiface == false
                            {
                                break
                            }
                        }
                    }
                    else
                    {}
            }
        }
        
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "removeMaskLayerMexEdge"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            DispatchQueue.main.async
            {
                self!.previewView.removeMaskLayerMexEdge() //   erase old
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "removeMaskLayerMexCloud"), object: nil, queue: nil)
        { [weak self] notification in
            guard let _ = self else { return }
            
            DispatchQueue.main.async
                {
                    self!.previewView.removeMaskLayerMexCloud() //   erase old
            }
        }
    }
    

    @objc func FaceDetectionLatencyEdge(_ notification: Notification)  
    {
        let v = notification.object
       // Swift.print("edge: [\(v!)]")

        let vv = Double(v as! String)

        DispatchQueue.main.async
        {
            self.latencyEdgeLabel.text = "Edge: \(v!) ms"
            
            self.rollingAverageEdge = self.calcRollingAverageEdge.addSample(value: vv!)
            let useRollingAverage = UserDefaults.standard.bool(forKey: "Use Rolling Average")
            
             if useRollingAverage
            {
                let a = String( format: "avg: %4.3f", self.rollingAverageEdge)
                
                self.latencyEdgeLabel.text = "Edge: \(a) ms"
            }
            
            let showStddev = UserDefaults.standard.bool(forKey: "Show Stddev")
            let stddev = standardDeviation(arr: self.calcRollingAverageEdge.samples)
            let stdevStr = "Stddev: " + String( format: "%4.3f", stddev)    //

            if showStddev
            {
                self.stddevEdgeLabel.text = "\(stdevStr)"
            }
            else
            {
                self.stddevEdgeLabel.isHidden = true
            }
            
        }
    }

    @objc func FaceDetectionLatencyCloud(_ notification: Notification)
    {
        let v = notification.object
        Swift.print("FaceDetectionLatencyCloud: [\(v!)]")

        DispatchQueue.main.async
        {
            self.latencyCloudLabel.text = "Cloud: \(v!) ms"

            let vv = Double(v as! String)
            self.rollingAverageCloud = self.calcRollingAverageCloud.addSample(value: vv!)
            let useRollingAverage = UserDefaults.standard.bool(forKey: "Use Rolling Average")
            
            
            if useRollingAverage
            {
                let a = String( format: "%4.3f", self.rollingAverageCloud)
                
                self.latencyCloudLabel.text = "Cloud: \(a) ms"
            }

            let showStddev = UserDefaults.standard.bool(forKey: "Show Stddev")
            let stddev = standardDeviation(arr: self.calcRollingAverageCloud.samples)
            let stdevStr = "Stddev: " + String( format: "%4.3f", stddev)

            
            if showStddev
            {
                self.stddevCloudLabel.text = "\(stdevStr)"
            }
            else
            {
                self.stddevCloudLabel.isHidden = true    //
            }
          }
    }

    @objc func networkLatencyEdge(_ notification: Notification)
    {
        let v = notification.object
      //  Swift.print("networkLatency edge: \(v!)")
    }

    @objc func networkLatencyCloud(_ notification: Notification)
    {
        let v = notification.object
     //   Swift.print("networkLatency Cloud: \(v!)")
    }

    // MARK: -

    private func removeObservers()
    {
        NotificationCenter.default.removeObserver(self)
    }

    @objc func sessionRuntimeError(_ notification: Notification)
    {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else { return }

        let error = AVError(_nsError: errorValue)
        print("Capture session runtime error: \(error)")

        /*
         Automatically try to restart the session running if media services were
         reset and the last start running succeeded. Otherwise, enable the user
         to try to resume the session running.
         */
        if error.code == .mediaServicesWereReset
        {
            sessionQueue.async
            { [unowned self] in
                if self.isSessionRunning
                {
                    self.session.startRunning()
                    self.isSessionRunning = self.session.isRunning
                }
            }
        }
    }

    @objc func sessionWasInterrupted(_ notification: Notification)
    {
        /*
         In some scenarios we want to enable the user to resume the session running.
         For example, if music playback is initiated via control center while
         using AVCamBarcode, then the user can let AVCamBarcode resume
         the session running, which will stop music playback. Note that stopping
         music playback in control center will not automatically resume the session
         running. Also note that it is not always possible to resume, see `resumeInterruptedSession(_:)`.
         */
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?, let reasonIntegerValue = userInfoValue.integerValue, let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue)
        {
            print("Capture session was interrupted with reason \(reason)")
        }
    }

    @objc func sessionInterruptionEnded(_: Notification)
    {
        print("Capture session interruption ended")
    }
}

extension FaceDetectionViewController
{
    func setupVision()
    {
        requests = [faceDetectionRequest]
    }

    func handleFaces(request: VNRequest, error _: Error?)
    {
        DispatchQueue.main.async
        {
            // perform all the UI updates on the main queue
            guard let results = request.results as? [VNFaceObservation] else { return }
            self.previewView.removeMask()
            for face in results
            {
                self.previewView.drawFaceboundingBox(face: face)
            }
        }
    }

    func handleFaceLandmarks(request: VNRequest, error _: Error?)
    {
        DispatchQueue.main.async
        {
            // perform all the UI updates on the main queue
            guard let results = request.results as? [VNFaceObservation] else { return }
            self.previewView.removeMask()
            for face in results
            {
                self.previewView.drawFaceWithLandmarks(face: face)
            }
        }
    }
}


extension FaceDetectionViewController
{
    
    @IBAction func switchButtonAction(sender _: UIBarButtonItem)    //_ sender: Any)
    {
        usingFrontCamera = !usingFrontCamera
        
        Swift.print("usingFrontCamera: \(usingFrontCamera)")
        sessionQueue.async
            { [unowned self] in
                self.configureSession()
        }
    }
    
    func getFrontCamera() -> AVCaptureDevice?
    {
        let videoDevices = AVCaptureDevice.devices(for: AVMediaType.video)  // prefered: AVCaptureDeviceDiscoverySession
        
        for device in videoDevices
        {
            let device = device
            if device.position == AVCaptureDevice.Position.front
            {
                return device
            }
        }
        return nil
    }
    
    func getBackCamera() -> AVCaptureDevice?
    {
        if let avcapdev = AVCaptureDevice.default(for: AVMediaType.video)
        {
            return avcapdev
        }
        else
        {
            return nil
        }
    }
    
}


extension FaceDetectionViewController: AVCaptureVideoDataOutputSampleBufferDelegate
{
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from _: AVCaptureConnection)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
            let exifOrientation = CGImagePropertyOrientation(rawValue: exifOrientationFromDeviceOrientation()) else { return }
        var requestOptions: [VNImageOption: Any] = [:]

        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
                                                     attachmentModeOut: nil)
        {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }

        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: exifOrientation, options: requestOptions)

        let nn = faceDetectCount.add(0)
        let p = pendingCount.add(0)
       // if         doAFaceDetection //   we get here for every frame

        if  nn == 3  || (nn >= 1 && p == 0)
        {
            faceDetectCount = OSAtomicInt32(2)

           pendingCount = OSAtomicInt32(0)

            let image = sampleBuffer.uiImage

            self.doFaceDetections( image: image)
        }

        do
        {
            try imageRequestHandler.perform(requests)
        }
        catch
        {
            print(error)
        }
    }
    
    func doFaceDetections( image: UIImage?)
    {
        let size = image!.size
        let fudge: CGFloat = 16.0
        let newSize = CGSize(width: size.width / fudge, height: size.height / fudge)
        let smaller: UIImage? = image?.imageResize(sizeChange: newSize)
        
        let rotateImage = smaller!.rotate(radians: .pi / 2.0)
        //   Swift.print("\(rotateImage!.size)")  // Log
        
        sentImageSize = rotateImage!.size

        faceDetectionEdgePromise = faceDetectionRecognition.FaceDetection(rotateImage, "Edge") // edge async
        faceDetectionCloudPromise = faceDetectionRecognition.FaceDetection(rotateImage, "Cloud") // cloud
        
        faceDetectionEdgePromise!.then { reply in
            let service = "Edge"
            let postName = "faceDetected" + service
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: postName ) , object: reply) //  draw blue rect around
            
            SKToast.show(withMessage: "FaceDetection \(service)")
            
            let doFaceRec = UserDefaults.standard.bool(forKey: "doFaceRecognition") // false means just detect
            if doFaceRec && faceRecognitionImages2.count == 0 //doAFaceRecognition
            {
                //   doAFaceRecognition = false // wait for que to empty
                if service == "Cloud"
                {
                    faceRecognitionImages2.removeAll()
                    
                    faceRecognitionImages2.append((image!, "Edge")) // )    // tupple   use whole image
                    faceRecognitionImages2.append((image!, "Cloud") )    //   use whole image  //
                    
                    Swift.print("")
                    //          faceDetectionCloud.doNextFaceRecognition()    // process q
                    faceDetectionRecognition.doNextFaceRecognition()
                    
                    // NotificationCenter.default.post(name: NSNotification.Name(rawValue: "doNextFaceRecognition" ) , object: nil)
                }
            }
            
            Swift.print("completion edge")
            
            if faceDetectCount.decrement() == 0
            {
                setFlagToProcessNextFrame()
                // Swift.print("-E- \(faceDetectCount.add(0))")  // JT
            }
            //Swift.print("-- \(faceDetectCount.add(0))")  // JT
            
            // Log.logger.name = "FaceDetection"
            // logw("\FaceDetection result: \(registerClientReply)")
        }
        .catch { error in
            Logger.shared.log(.network, .info, "Error encoutered for face detection on Edge: \(error)")
        }
        .always {
            Swift.print("completion edge")
            
            if faceDetectCount.decrement() == 0
            {
                setFlagToProcessNextFrame()
                // Swift.print("-E- \(faceDetectCount.add(0))")  // JT
            }
        }
        
        faceDetectionCloudPromise!.then { reply in
                let service = "Cloud"
                let postName = "faceDetected" + service
                NotificationCenter.default.post(name: NSNotification.Name(rawValue: postName ) , object: reply) //  draw blue rect around
                
                SKToast.show(withMessage: "FaceDetection \(service)")
                
                let doFaceRec = UserDefaults.standard.bool(forKey: "doFaceRecognition") // false means just detect
                
                if doFaceRec && faceRecognitionImages2.count == 0 //doAFaceRecognition
                {
                    //   doAFaceRecognition = false // wait for que to empty
                    
                    if service == "Cloud"
                    {
                        faceRecognitionImages2.removeAll()
                        
                        faceRecognitionImages2.append((image!, "Edge")) // )    // tupple   use whole image
                        faceRecognitionImages2.append((image!, "Cloud") )    //   use whole image  //
                        
                        Swift.print("")
            //          faceDetectionCloud.doNextFaceRecognition()    // process q
                        faceDetectionRecognition.doNextFaceRecognition()

                       // NotificationCenter.default.post(name: NSNotification.Name(rawValue: "doNextFaceRecognition" ) , object: nil)

                    }
                }
                
               // Swift.print("-X- \(faceDetectCount.add(0))")  // JT
                
                // Log.logger.name = "FaceDetection"
                // logw("\FaceDetection result: \(registerClientReply)")
        }
        .catch { error in
            Logger.shared.log(.network, .info, "FaceDetection failed with error: \(error)")
        }
        .always {
            Swift.print("completion Cloud")
            let n = faceDetectCount.decrement()
            if n == 0
            {
                setFlagToProcessNextFrame()
                Swift.print("-C- \(faceDetectCount.add(0))")  // JT
            }
                
       }
    
    }
}

func setFlagToProcessNextFrame()
{
    faceDetectCount = OSAtomicInt32(3)

}

extension UIDeviceOrientation
{
    var videoOrientation: AVCaptureVideoOrientation?
    {
        switch self {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft

        default: return nil
        }
    }
}

extension UIInterfaceOrientation
{
    var videoOrientation: AVCaptureVideoOrientation?
    {
        switch self
        {
        case .portrait: return .portrait
        case .portraitUpsideDown: return .portraitUpsideDown
        case .landscapeLeft: return .landscapeLeft
        case .landscapeRight: return .landscapeRight

        default: return nil
        }
    }
}

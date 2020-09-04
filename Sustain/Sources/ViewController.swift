//
//  HomeViewController.swift
//  Sustain
//
//  Created by Sean Nordquist on 8/22/20.
//  Copyright © 2020 Sean Nordquist. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import Vision

class ViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - UI Objects
    @IBOutlet var tableView: UITableView!
    @IBOutlet weak var previewView: PreviewView!
    @IBOutlet weak var cutoutView: UIView!
    @IBOutlet weak var detectedTipsView: CameraTipsView!
    @IBOutlet weak var undetectedTipsView: CameraTipsView!
    @IBOutlet weak var isNoneTipsView: CameraTipsView!
    @IBOutlet weak var IngredientsFoundTitle: UILabel!
    @IBOutlet weak var IngredientsFoundSubtitle: UILabel!
    @IBOutlet weak var backButton: UIButton!
    
    var maskLayer = CAShapeLayer()
    // Device orientation. Updated whenever the orientation changes to a
    // different supported orientation.
    var currentOrientation = UIDeviceOrientation.portrait
    
    // MARK: - Capture related objects

    private let captureSession = AVCaptureSession()
    let captureSessionQueue = DispatchQueue(label: "com.example.apple-samplecode.CaptureSessionQueue")
    
    var captureDevice: AVCaptureDevice?
    
    var videoDataOutput = AVCaptureVideoDataOutput()
    let videoDataOutputQueue = DispatchQueue(label: "com.example.apple-samplecode.VideoDataOutputQueue")
    
    // MARK: - Region of interest (ROI) and text orientation
    // Region of video data output buffer that recognition should be run on.
    // Gets recalculated once the bounds of the preview layer are known.
    var regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    // Orientation of text to search for in the region of interest.
    var textOrientation = CGImagePropertyOrientation.up
    
    // MARK: - Coordinate transforms
    var bufferAspectRatio: Double!
    // Transform from UI orientation to buffer orientation.
    var uiRotationTransform = CGAffineTransform.identity
    // Transform bottom-left coordinates to top-left.
    var bottomToTopTransform = CGAffineTransform(scaleX: 1, y: -1).translatedBy(x: 0, y: -1)
    // Transform coordinates in ROI to global coordinates (still normalized).
    var roiToGlobalTransform = CGAffineTransform.identity
   
    // Vision -> AVF coordinate transform.
    var visionToAVFTransform = CGAffineTransform.identity
    
    // MARK: - State related variables
    var isDetecting = false // when the user points the camera at an ingredients label
    var hasDetected = false // when ingredients begin to be parsed
    var isNone = false
    var hasSetDeadline = false
    var ingredientCount = 0
    var detectedIngredients = [Ingredient]() // list of ingredients parsed for tableView
    var detectedIngredientsSet = Set<String>() // set for speeding up detecting duplicate detections
    var ingredientSet = IngredientSet(path: "data")
    
    override func loadView() {
        super.loadView()

        // configure animations
        detectedTipsView.setup(type: "detected")
        detectedTipsView.isHidden = true
        undetectedTipsView.setup(type: "!detected")
        isNoneTipsView.setup(type: "isnone")
        isNoneTipsView.isHidden = true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print(ingredientSet.getIngredientRegex())
                
        let blur = UIVisualEffectView(effect: UIBlurEffect(style:
                    UIBlurEffect.Style.light))
        blur.frame = backButton.bounds
        blur.isUserInteractionEnabled = false //This allows touches to forward to the button.
        blur.layer.cornerRadius = backButton.frame.height / 3
        blur.clipsToBounds = true
        backButton.layer.cornerRadius = backButton.frame.height / 3
        backButton.insertSubview(blur, at: 1)
        if let imageView = backButton.imageView {
            backButton.bringSubviewToFront(imageView)
        }
        backButton.isHidden = true
        
        // set delegate and datasource, and hide
        tableView.delegate = self
        tableView.dataSource = self
        let nib = UINib(nibName: "IngredientTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "IngredientTableViewCell")
        IngredientsFoundTitle.isHidden = true
        IngredientsFoundSubtitle.isHidden = true
        
        previewView.session = captureSession
        
        cutoutView.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        maskLayer.backgroundColor = UIColor.clear.cgColor
        maskLayer.fillRule = .evenOdd
        cutoutView.layer.mask = maskLayer
        
        // adding blur effect, only if the user hasn't disabled transparency effects
        if !UIAccessibility.isReduceTransparencyEnabled {
            let blurEffect = UIBlurEffect(style: .light)
            let blurEffectView = UIVisualEffectView(effect: blurEffect)
            //always fill the view
            blurEffectView.frame = cutoutView.bounds
            blurEffectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

            cutoutView.addSubview(blurEffectView) //if you have more UIViews, use an insertSubview API to place it where needed
        } else {
            cutoutView.backgroundColor = .black
        }
                
       // Starting the capture session is a blocking call. Perform setup using
       // a dedicated serial dispatch queue to prevent blocking the main thread.
       captureSessionQueue.async {
           self.setupCamera()
           
           // Calculate region of interest now that the camera is setup.
           DispatchQueue.main.async {
               // Figure out initial ROI.
                self.calculateRegionOfInterest()
           }
       }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // Only change the current orientation if the new one is landscape or
        // portrait. You can't really do anything about flat or unknown.
        let deviceOrientation = UIDevice.current.orientation
        if deviceOrientation.isPortrait || deviceOrientation.isLandscape {
            currentOrientation = deviceOrientation
        }
        
        // Handle device orientation in the preview layer.
        if let videoPreviewLayerConnection = previewView.videoPreviewLayer.connection {
            if let newVideoOrientation = AVCaptureVideoOrientation(rawValue: deviceOrientation.rawValue) {
                videoPreviewLayerConnection.videoOrientation = newVideoOrientation
            }
        }
        
        // Orientation changed: figure out new region of interest (ROI).
        calculateRegionOfInterest()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCutout()
    }
    
    // MARK: - Setup
    
    func calculateRegionOfInterest() {
        // In landscape orientation the desired ROI is specified as the ratio of
        // buffer width to height. When the UI is rotated to portrait, keep the
        // vertical size the same (in buffer pixels). Also try to keep the
        // horizontal size the same up to a maximum ratio.
        let desiredHeightRatio = 0.6
        let desiredWidthRatio = 1.0
        let maxPortraitWidth = 1.0
        
        // Figure out size of ROI.
        let size: CGSize
        if currentOrientation.isPortrait || currentOrientation == .unknown {
            size = CGSize(width: min(desiredWidthRatio * bufferAspectRatio, maxPortraitWidth), height: desiredHeightRatio / bufferAspectRatio)
        } else {
            size = CGSize(width: desiredWidthRatio, height: desiredHeightRatio)
        }
        // Make it centered.
        regionOfInterest.origin = CGPoint(x: 1-size.width, y: 1-size.height)
        regionOfInterest.size = size
        
        // ROI changed, update transform.
        setupOrientationAndTransform()
        
        // Update the cutout to match the new ROI.
        DispatchQueue.main.async {
            // Wait for the next run cycle before updating the cutout. This
            // ensures that the preview layer already has its new orientation.
            self.updateCutout()
        }
    }
    
    func updateCutout() {
        // Figure out where the cutout ends up in layer coordinates.
        let roiRectTransform = bottomToTopTransform.concatenating(uiRotationTransform)
        let cutout = previewView.videoPreviewLayer.layerRectConverted(fromMetadataOutputRect: regionOfInterest.applying(roiRectTransform))
        
        // Create the mask.
        let path = UIBezierPath(rect: cutoutView.frame)
        path.append(UIBezierPath(rect: cutout))
        maskLayer.path = path.cgPath
    }
    
    func setupOrientationAndTransform() {
        // Recalculate the affine transform between Vision coordinates and AVF coordinates.
        
        // Compensate for region of interest.
        let roi = regionOfInterest
        roiToGlobalTransform = CGAffineTransform(translationX: roi.origin.x, y: roi.origin.y).scaledBy(x: roi.width, y: roi.height)
        
        // Compensate for orientation (buffers always come in the same orientation).
        switch currentOrientation {
        case .landscapeLeft:
            textOrientation = CGImagePropertyOrientation.up
            uiRotationTransform = CGAffineTransform.identity
        case .landscapeRight:
            textOrientation = CGImagePropertyOrientation.down
            uiRotationTransform = CGAffineTransform(translationX: 1, y: 1).rotated(by: CGFloat.pi)
        case .portraitUpsideDown:
            textOrientation = CGImagePropertyOrientation.left
            uiRotationTransform = CGAffineTransform(translationX: 1, y: 0).rotated(by: CGFloat.pi / 2)
        default: // We default everything else to .portraitUp
            textOrientation = CGImagePropertyOrientation.right
            uiRotationTransform = CGAffineTransform(translationX: 0, y: 1).rotated(by: -CGFloat.pi / 2)
        }
        
        // Full Vision ROI to AVF transform.
        visionToAVFTransform = roiToGlobalTransform.concatenating(bottomToTopTransform).concatenating(uiRotationTransform)
    }
    
    func setupCamera() {
        guard let captureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: AVMediaType.video, position: .back) else {
            print("Could not create capture device.")
            return
        }
        self.captureDevice = captureDevice
        
        // NOTE:
        // Requesting 4k buffers allows recognition of smaller text but will
        // consume more power. Use the smallest buffer size necessary to keep
        // down battery usage.
        if captureDevice.supportsSessionPreset(.hd4K3840x2160) {
            captureSession.sessionPreset = AVCaptureSession.Preset.hd4K3840x2160
            bufferAspectRatio = 3840.0 / 2160.0
        } else {
            captureSession.sessionPreset = AVCaptureSession.Preset.hd1920x1080
            bufferAspectRatio = 1920.0 / 1080.0
        }
        
        guard let deviceInput = try? AVCaptureDeviceInput(device: captureDevice) else {
            print("Could not create device input.")
            return
        }
        if captureSession.canAddInput(deviceInput) {
            captureSession.addInput(deviceInput)
        }
        
        // Configure video data output.
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: videoDataOutputQueue)
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            // NOTE:
            // There is a trade-off to be made here. Enabling stabilization will
            // give temporally more stable results and should help the recognizer
            // converge. But if it's enabled the VideoDataOutput buffers don't
            // match what's displayed on screen, which makes drawing bounding
            // boxes very hard. Disable it in this app to allow drawing detected
            // bounding boxes on screen.
            videoDataOutput.connection(with: AVMediaType.video)?.preferredVideoStabilizationMode = .off
        } else {
            print("Could not add VDO output")
            return
        }
        
        // Set zoom and autofocus to help focus on very small text.
        do {
            try captureDevice.lockForConfiguration()
            captureDevice.videoZoomFactor = 2
            captureDevice.autoFocusRangeRestriction = .near
            captureDevice.unlockForConfiguration()
        } catch {
            print("Could not set zoom level due to error: \(error)")
            return
        }
        
        captureSession.startRunning()
    }
    
    
    // MARK: - State transitions
    
    @IBAction func handleResetAction(_ sender: Any) {
        DispatchQueue.main.async {
            self.dispatch(type: "RESET")
        }
        
    }
    
    func dispatch(type: String) {
        switch type {
        case "DETECTING": do {
            if !self.isNone {
                // update tool tips
                self.setViewHidden(view: self.detectedTipsView, hidden: false)
                self.setViewHidden(view: self.undetectedTipsView, hidden: true)
                            }
            }
        case "NONE": do {
            if !self.hasDetected {
                self.setViewHidden(view: self.isNoneTipsView, hidden: false)
               self.setViewHidden(view: self.detectedTipsView, hidden: true)
               self.setViewHidden(view: self.undetectedTipsView, hidden: true)
               backButton.isHidden = false
                self.isNone = true
            }
            
            }
        case "DETECTED": do {
            if true {
                // update tool tips
                print("detected")
                self.setViewHidden(view: self.undetectedTipsView, hidden: true)
                self.setViewHidden(view: self.detectedTipsView, hidden: true)
                IngredientsFoundSubtitle.isHidden = false
                IngredientsFoundTitle.text = self.detectedIngredients.count == 1 ? "Unsustainable Ingredient Found" : "Unsustainable Ingredients Found"
                IngredientsFoundTitle.isHidden = false
                backButton.isHidden = false
                self.tableView.reloadData()
            }
            
            }
        case "RESET": do {
            print("reset")
            self.setViewHidden(view: self.undetectedTipsView, hidden: false)
            self.setViewHidden(view: self.detectedTipsView, hidden: true)
            self.setViewHidden(view: self.isNoneTipsView, hidden: true)
            self.detectedIngredients = []
            self.detectedIngredientsSet.removeAll()
            backButton.isHidden = true
            self.tableView.reloadData()
            self.isDetecting = false
            self.hasDetected = false
            self.isNone = false
            self.hasSetDeadline = false
            self.ingredientCount = 0
            IngredientsFoundSubtitle.isHidden = true
            IngredientsFoundTitle.isHidden = true
            }
        default: do {
            return
            }
        }
    }
    
    func setViewHidden(view: UIView, hidden: Bool) {
        UIView.transition(with: view, duration: 1, options: .transitionCrossDissolve, animations: {
            view.isHidden = hidden
        })
    }
    
    // MARK: - Segue preparation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "HomeToDetail" {
            let destVC = segue.destination as! IngredientDetailViewController
            let ingredient = sender as? Ingredient
            destVC.ingredientDescription = ingredient?.description
            destVC.ingredientName = ingredient?.name
        }
    }
    
    // MARK: - TableView
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.detectedIngredients.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "IngredientTableViewCell", for: indexPath) as! IngredientTableViewCell
        cell.ingredient?.text = self.detectedIngredients[indexPath.row].name
        cell.selectionStyle = .none
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        DispatchQueue.main.async {
            self.tableView.deselectRow(at: indexPath, animated: false)
            let ingredient = self.detectedIngredients[indexPath.row]
            self.performSegue(withIdentifier: "HomeToDetail", sender: ingredient)
        }
    }

}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // This is implemented in VisionViewController.
    }
}

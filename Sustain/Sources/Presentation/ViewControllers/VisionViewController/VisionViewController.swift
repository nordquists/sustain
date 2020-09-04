/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Vision view controller.
            Recognizes text using a Vision VNRecognizeTextRequest request handler in pixel buffers from an AVCaptureOutput.
            Displays bounding boxes around recognized text results in real time.
*/

import Foundation
import UIKit
import AVFoundation
import Vision

class VisionViewController: ViewController { // This is a subclass of our view controller
    var request: VNRecognizeTextRequest!
    // Temporal string tracker
    let numberTracker = StringTracker()
    
    override func viewDidLoad() {
        // Set up vision request before letting ViewController set up the camera
        // so that it exists when the first buffer is received.
        request = VNRecognizeTextRequest(completionHandler: recognizeTextHandler)

        super.viewDidLoad()
    }
    
    // MARK: - Text recognition
    
    // Vision recognition handler.
    func recognizeTextHandler(request: VNRequest, error: Error?) {
        var numbers = [String]()
        var greenBoxes = [CGRect]() // Shows words that might be serials
        
        guard let results = request.results as? [VNRecognizedTextObservation] else {
            return
        }
        
        let maximumCandidates = 1
        
        
        for visionResult in results {
            guard let candidate = visionResult.topCandidates(maximumCandidates).first else { continue }
            
          
            // Draw red boxes around any detected text, and green boxes around
            // any detected phone numbers. The phone number may be a substring
            // of the visionResult. If a substring, draw a green box around the
            // number and a red box around the full string. If the number covers
            // the full result only draw the green box.
            if let results = candidate.string.extractIngredients(regexPattern: self.ingredientSet.getIngredientRegex()) {
                for result in results {
                    let (range, number) = result
                    // Ingredient may not cover full visionResult. Extract bounding box
                    // of substring.
                    if let box = try? candidate.boundingBox(for: range)?.boundingBox {
                        numbers.append(number)
                        greenBoxes.append(box)
                    }
                }
            }
            
            if let result = candidate.string.extractIngredientLabel() {
                let (range, _) = result
                if (try? candidate.boundingBox(for: range)?.boundingBox) != nil {
                    self.isDetecting = true
                    self.ingredientCount += 1
                }
            }
        }
        
        numberTracker.logFrame(strings: numbers)
        show(boxGroups: [(color: UIColor.orange.cgColor, boxes: greenBoxes)])
        
        // Check if we have stable ingredients seen
        if let ingredient = numberTracker.getStableString() {
            if !self.detectedIngredientsSet.contains(ingredient.uppercased()) {
                self.hasDetected = true
                print(ingredient)
                detectedIngredients.append(self.ingredientSet.getIngredientDictionary()[ingredient.uppercased()]!)
                self.detectedIngredientsSet.insert(ingredient.uppercased())
            }
            
            numberTracker.reset(string: ingredient)
        }
        
        print(self.detectedIngredientsSet)
        
        DispatchQueue.main.async {
            self.dispatch(type: self.ingredientCount >= 200 ? "NONE" : "")
            self.dispatch(type: self.isDetecting ? "DETECTING" : "")
            self.dispatch(type: self.hasDetected ? "DETECTED" : "")
        }
    }
    
    override func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            // Configure for running in real-time.
            request.recognitionLevel = .fast
            // Language correction won't help recognizing phone numbers. It also
            // makes recognition slower.
            request.usesLanguageCorrection = true
            // Only run on the region of interest for maximum speed.
            request.regionOfInterest = regionOfInterest
            
            let requestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: textOrientation, options: [:])
            do {
                try requestHandler.perform([request])
            } catch {
                print(error)
            }
        }
    }
    
    // MARK: - Bounding box drawing
    
    // Draw a box on screen. Must be called from main queue.
    var boxLayer = [CALayer]()
    func draw(rect: CGRect, color: CGColor) {
        let layer = CALayer()
        layer.bounds = rect
        layer.position = CGPoint(x: rect.midX, y: rect.midY)
        layer.backgroundColor = color
        layer.opacity = 0.5
        layer.cornerRadius = 7
        boxLayer.append(layer)
        previewView.videoPreviewLayer.insertSublayer(layer, at: 1)
    }
    
    // Remove all drawn boxes. Must be called on main queue.
    func removeBoxes() {
        for layer in boxLayer {
            layer.removeFromSuperlayer()
        }
        boxLayer.removeAll()
    }
    
    typealias ColoredBoxGroup = (color: CGColor, boxes: [CGRect])
    
    // Draws groups of colored boxes.
    func show(boxGroups: [ColoredBoxGroup]) {
        DispatchQueue.main.async {
            let layer = self.previewView.videoPreviewLayer
            self.removeBoxes()
            for boxGroup in boxGroups {
                let color = boxGroup.color
                for box in boxGroup.boxes {
                    let rect = layer.layerRectConverted(fromMetadataOutputRect: box.applying(self.visionToAVFTransform))
                    self.draw(rect: rect, color: color)
                }
            }
        }
    }
}

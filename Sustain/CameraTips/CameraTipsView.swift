//
//  CameraTipsView.swift
//  Sustain
//
//  Created by Sean Nordquist on 8/22/20.
//  Copyright © 2020 Sean Nordquist. All rights reserved.
//

import UIKit

@IBDesignable
class CameraTipsView: UIView, NibLoadable {

    /*
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
    }
    */
    
    @IBOutlet weak var iconImage: UIImageView!
    @IBOutlet weak var label: UILabel!
    
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setupFromNib()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupFromNib()
    }
    
    func setup(type: String) {
        if type == "detected" {
            label.text = "Move the label around in front of the camera"
            iconImage.image = UIImage(systemName: "viewfinder")
            configAnimations(type: "detected")
        } else if type == "!detected" {
            label.text = "Point the camera at the label"
            iconImage.image = UIImage(systemName: "arrow.up")
            configAnimations(type: "!detected")
        } else {
            label.text = "No unsustainable ingredients detected"
            iconImage.image = UIImage(systemName: "checkmark.circle")
            configAnimations(type: "none")
        }
        
    }
    
    func configAnimations(type: String) {
        if type == "detected" {
            let circlePath = UIBezierPath(arcCenter: iconImage.frame.origin, radius: 10, startAngle: 0, endAngle: .pi*2, clockwise: true)

            let animation = CAKeyframeAnimation(keyPath: #keyPath(CALayer.position))
            animation.duration = 4
            animation.repeatCount = MAXFLOAT
            animation.path = circlePath.cgPath
            iconImage.layer.add(animation, forKey: nil)
        } else if type == "!detected" {
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x:iconImage.frame.origin.x, y:iconImage.frame.origin.y))
            linePath.addLine(to: CGPoint(x:iconImage.frame.origin.x, y:iconImage.frame.origin.y + 10))
            linePath.close()
            let animation = CAKeyframeAnimation(keyPath: #keyPath(CALayer.position))
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.duration = 2
            animation.repeatCount = MAXFLOAT
            animation.path = linePath.cgPath
            iconImage.layer.add(animation, forKey: nil)
        } else {
            let linePath = UIBezierPath()
            linePath.move(to: CGPoint(x:iconImage.frame.origin.x, y:iconImage.frame.origin.y))
            linePath.close()
            let animation = CAKeyframeAnimation(keyPath: #keyPath(CALayer.position))
            animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
            animation.duration = 2
            animation.repeatCount = MAXFLOAT
            animation.path = linePath.cgPath
            iconImage.layer.add(animation, forKey: nil)
        }
    }
    
}

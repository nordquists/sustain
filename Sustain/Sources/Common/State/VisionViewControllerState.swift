//
//  VisionViewControllerState.swift
//  Sustain
//
//  Created by Sean Nordquist on 9/3/20.
//  Copyright © 2020 Sean Nordquist. All rights reserved.
//

import UIKit

enum State: Int {
    case hasStartedScanning // Sustain is searching for an ingredient label
    case hasStartedDetecting // Sustain has detected it is looking at an ingredient label
    case hasDetected // Sustain has found ingredients to display
    case noCamera // User had denied camera access
    case error // Unexpected error
}

class VisionViewControllerState: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}

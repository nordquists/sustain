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
    case hasTimedOutDetecting // Sustain has started detecting, bu
    case hasDetected // Sustain has found ingredients to display
    case noCamera // User had denied camera access
    case error // Unexpected error
}

class MainViewControllerState: UIViewController {
    var currentState: State?
    var initialState: State? = .hasStartedScanning
}

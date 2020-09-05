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

class MainViewControllerState: UIViewController, StateChanger {
    
    private let stateProvider: StateProvider
    private var currentState: State?
    
    init(stateProvider: StateProvider) {
        self.stateProvider = stateProvider
        
        super.init(nibName: nil, bundle: nil)
        
        self.stateProvider.stateChanger = self
        self.title = self.stateProvider.title
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        changeTo(state: stateProvider.initialState)
    }
    
    // MARK: - Changing State
    func changeTo(state: State) {
        guard currentState != state else {
            return
        }
        
        currentState = state
        
        switch state {
        case .content:
            removePreviousChildAndAdd(viewController: stateProvider.contentViewController())
        case .error:
            removePreviousChildAndAdd(viewController: stateProvider.errorViewController())
        case .empty:
            removePreviousChildAndAdd(viewController: stateProvider.emptyViewController())
        }
    }
}

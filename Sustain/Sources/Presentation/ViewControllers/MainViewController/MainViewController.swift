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

protocol MainViewControllerDelegate: AnyObject {
    // Go to the MainViewControllerState for descriptions
    func didStartScanning()
    func didStartDetecting()
    func didTimeOutDetecting()
    func didDetect()
    func didDisableCamera()
}

class MainViewController: MainViewControllerState, UITableViewDelegate, UITableViewDataSource {
    
    // MARK: - UI Objects
    @IBOutlet weak var backButton: UIButton!
    
    // Detected Ingredients Table
    @IBOutlet weak var IngredientsFoundTitle: UILabel!
    @IBOutlet weak var IngredientsFoundSubtitle: UILabel!
    @IBOutlet var tableView: UITableView!
    
    // Tool Tips Views
    @IBOutlet weak var detectedTipsView: CameraTipsView!
    @IBOutlet weak var undetectedTipsView: CameraTipsView!
    @IBOutlet weak var isNoneTipsView: CameraTipsView!
    
    // MARK: - State Related Variables
    var detectedIngredients = [Ingredient]() // list of ingredients parsed for tableView
    var detectedIngredientsSet = Set<String>() // set for speeding up detecting duplicate detections
    weak var stateChanger: StateChanger?
    weak var delegate: MainViewControllerDelegate?
    
    // MARK: - Ingredient Search Set Loading
    var ingredientSet = IngredientSet(path: "data")
    
    // MARK: - ViewDidLoad
    override func viewDidLoad() {
        super.viewDidLoad()
        
        stateChanger = self
        delegate = self
        
        self.delegate?.didStartScanning()
        
        // configure animations
        detectedTipsView.setup(type: "detected")
        detectedTipsView.isHidden = true
        undetectedTipsView.setup(type: "!detected")
        isNoneTipsView.setup(type: "isnone")
        isNoneTipsView.isHidden = true
        
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
        
        // set table delegate and datasource, and hide
        tableView.delegate = self
        tableView.dataSource = self
        let nib = UINib(nibName: "IngredientTableViewCell", bundle: nil)
        tableView.register(nib, forCellReuseIdentifier: "IngredientTableViewCell")
        IngredientsFoundTitle.isHidden = true
        IngredientsFoundSubtitle.isHidden = true
    }
    
    // MARK: - State Transitions
    @IBAction func handleResetAction(_ sender: Any) {
        DispatchQueue.main.async {
            self.delegate?.didStartScanning()
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

// MARK: - State Changer Function
extension MainViewController: StateChanger {
    func changeTo(state: State) {
        guard currentState != state else {
            return
        }
        
        currentState = state
        
        switch state {
        case .hasStartedScanning:
            self.setViewHidden(view: self.undetectedTipsView, hidden: false)
            self.setViewHidden(view: self.detectedTipsView, hidden: true)
            self.setViewHidden(view: self.isNoneTipsView, hidden: true)
            detectedIngredients = [Ingredient]()
            detectedIngredientsSet = Set<String>()
            IngredientsFoundSubtitle.isHidden = true
            IngredientsFoundTitle.isHidden = true
            backButton.isHidden = true
            tableView.isHidden = true
            
        case .hasStartedDetecting:
            self.setViewHidden(view: self.detectedTipsView, hidden: false)
            self.setViewHidden(view: self.undetectedTipsView, hidden: true)
    
        case .hasTimedOutDetecting:
            self.setViewHidden(view: self.isNoneTipsView, hidden: false)
            self.setViewHidden(view: self.detectedTipsView, hidden: true)
            self.setViewHidden(view: self.undetectedTipsView, hidden: true)
            backButton.isHidden = false
            
        case .hasDetected:
            self.setViewHidden(view: self.undetectedTipsView, hidden: true)
            self.setViewHidden(view: self.detectedTipsView, hidden: true)
            IngredientsFoundSubtitle.isHidden = false
            IngredientsFoundTitle.text = self.detectedIngredients.count == 1 ? "Unsustainable Ingredient Found" : "Unsustainable Ingredients Found"
            IngredientsFoundTitle.isHidden = false
            backButton.isHidden = false
            tableView.isHidden = false
            tableView.reloadData() // needs to be called somewhere else otherwise table won't refresh
            
        case .noCamera:
            break
            
        case .error:
            // Perhaps we will have a separate view controller for handling errors, for
            // which we will make a different delegate
            break
        }
    }
}

// MARK: - State Delegate Functions
extension MainViewController: MainViewControllerDelegate {
    func didStartScanning() {
        stateChanger?.changeTo(state: .hasStartedScanning)
    }
    
    func didStartDetecting() {
        stateChanger?.changeTo(state: .hasStartedDetecting)
    }
    
    func didTimeOutDetecting() {
        stateChanger?.changeTo(state: .hasTimedOutDetecting)
    }
    
    func didDetect() {
        stateChanger?.changeTo(state: .hasDetected)
    }
    
    func didDisableCamera() {
        stateChanger?.changeTo(state: .noCamera)
    }
}

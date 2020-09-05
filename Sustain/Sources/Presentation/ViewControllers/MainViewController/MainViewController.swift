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
    var isDetecting = false // when the user points the camera at an ingredients label
    var hasDetected = false // when ingredients begin to be parsed
    var isNone = false
    var hasSetDeadline = false
    var ingredientCount = 0
    var detectedIngredients = [Ingredient]() // list of ingredients parsed for tableView
    var detectedIngredientsSet = Set<String>() // set for speeding up detecting duplicate detections
    var ingredientSet = IngredientSet(path: "data")
    
    // MARK: - LoadView
    override func loadView() {
        super.loadView()
        
        // configure animations
        detectedTipsView.setup(type: "detected")
        detectedTipsView.isHidden = true
        undetectedTipsView.setup(type: "!detected")
        isNoneTipsView.setup(type: "isnone")
        isNoneTipsView.isHidden = true
    }
    
    // MARK: - ViewDidLoad
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

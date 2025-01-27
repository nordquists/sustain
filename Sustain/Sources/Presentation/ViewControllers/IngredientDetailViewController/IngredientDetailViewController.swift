//
//  IngredientDetailViewController.swift
//  Sustain
//
//  Created by Sean Nordquist on 8/22/20.
//  Copyright © 2020 Sean Nordquist. All rights reserved.
//

import UIKit

class IngredientDetailViewController: UIViewController {

    @IBOutlet weak var IngredientNameLabel: UILabel!
    @IBOutlet weak var IngredientDescriptionLabel: UILabel!
    @IBOutlet weak var LearnMoreButton: UIButton!
    //    var ingredient: Ingredient
    var ingredientName: String?
    var ingredientDescription: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        updateUI()
    }
    
    func updateUI() {
        IngredientNameLabel.text = ingredientName
        IngredientDescriptionLabel.text = ingredientDescription
        LearnMoreButton.layer.cornerRadius = LearnMoreButton.frame.height / 2
    }
}

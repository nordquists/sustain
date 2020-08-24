//
//  IngredientTableViewCell.swift
//  Sustain
//
//  Created by Sean Nordquist on 8/22/20.
//  Copyright © 2020 Sean Nordquist. All rights reserved.
//

import UIKit

class IngredientTableViewCell: UITableViewCell {
    
    @IBOutlet weak var pillView: UIView!
    @IBOutlet var ingredient: UILabel!

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        self.backgroundColor = .none
        let radius = pillView.frame.height / 2
        pillView.layer.cornerRadius = radius
    }

//    override func setSelected(_ selected: Bool, animated: Bool) {
//        super.setSelected(selected, animated: animated)
//
//        // Configure the view for the selected state
//    }
    
}

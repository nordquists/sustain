//
//  IngredientDataUtils.swift
//  Sustain
//
//  Created by Sean Nordquist on 8/23/20.
//  Copyright © 2020 Sean Nordquist. All rights reserved.
//

import Foundation
import UIKit

// Read in a JSON file with an array of harmful ingredients
// * We need an dictionary object that maps detectedIngredient:String.lower to an Ingredient object
// To achieve this, we
// 1. Read in the JSON file into an array of type [Any]
// 2. For each object in the array
//      a. create Ingredient object
//      b. insert the name into the dictonary and map to Ingredient object
// 3. Generate Regex pattern

struct Ingredient {
    var name: String
    var description: String
    var outboundLinks: [[String]]
    var tags: [String]
}

class IngredientSet {

    var ingredientRegex: String
    var ingredientDictionary: [String: Ingredient]

    init(path: String) {
        self.ingredientRegex = #""#
        self.ingredientDictionary = [:]
        generateDictionary(pathName: path)
        self.ingredientRegex = String(self.ingredientRegex.dropLast())
    }

    func getIngredientRegex() -> String {
        return self.ingredientRegex
    }

    func getIngredientDictionary() -> [String: Ingredient]{
        return self.ingredientDictionary
    }

    func generateDictionary(pathName: String) {
        guard let path = Bundle.main.path(forResource: pathName, ofType: "json") else { return }

        let url = URL(fileURLWithPath: path)

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data)

            guard let array = json as? [Any] else { return }
            for ingredient in array {
                guard let ingredientDict = ingredient as? [String: Any] else { return }
                let newIngredient = Ingredient(name: ingredientDict["name"] as! String, description: ingredientDict["description"] as! String, outboundLinks: ingredientDict["links"] as! [[String]], tags: ingredientDict["tags"] as! [String])
                self.ingredientDictionary[(ingredientDict["name"] as! String).uppercased()] = newIngredient
                self.ingredientRegex += #"\b"# + (ingredientDict["name"] as! String) + #"|"#
            }
        } catch {
            print("Error reading in file \(pathName)")
        }
    }
}

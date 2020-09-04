/*
See LICENSE folder for this sample’s licensing information.

Abstract:
Utilities for dealing with recognized strings
*/

import Foundation

extension String {
    func extractIngredients(regexPattern: String) -> [(Range<String.Index>, String)]? {
        let pattern = regexPattern
        let range = self.startIndex..<self.endIndex
        
        var ingredients: [(Range<String.Index>, String)] = []
        
        let substring = String(self[range])
        let nsrange = NSRange(substring.startIndex..., in: substring)
        
        do {
            // Extract the characters from the substring.
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex.matches(in: substring, options: [], range: nsrange)
            for match in matches {
                for rangeInd in 0 ..< match.numberOfRanges {
                    let range = match.range(at: rangeInd)
                    let matchString = (substring as NSString).substring(with: range)
                    
                    ingredients.append(contentsOf: [(Range(range, in: substring)!, matchString as String)])
                }
            }
        } catch {
            print("Error \(error) when creating pattern")
        }
        
        if ingredients.count == 0 {
            return nil
        }
    
        return ingredients
    }
    
    func extractIngredientLabel() -> (Range<String.Index>, String)? {
        // function that determines if we are looking at an ingredient label
        let pattern = #"\bingredients|\bingredient"#
        
        guard let range = self.range(of: pattern, options: [.regularExpression, .caseInsensitive], range: nil, locale: nil) else {
            // No phone number found.
            return nil
        }
        
        let substring = String(self[range])
        let nsrange = NSRange(substring.startIndex..., in: substring)
        
        do {
            // Extract the characters from the substring.
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            if regex.firstMatch(in: substring, options: [], range: nsrange) != nil {
                return (range, "Ingredients")
            }
        } catch {
            print("Error \(error) when creating pattern")
        }
        
        return nil
    }
}

class StringTracker {
    var frameIndex: Int64 = 0

    typealias StringObservation = (lastSeen: Int64, count: Int64)
    
    // Dictionary of seen strings. Used to get stable recognition before
    // displaying anything.
    var seenStrings = [String: StringObservation]()
    var bestCount = Int64(0)
    var bestString = ""

    func logFrame(strings: [String]) {
        for string in strings {
            if seenStrings[string] == nil {
                seenStrings[string] = (lastSeen: Int64(0), count: Int64(-1))
            }
            seenStrings[string]?.lastSeen = frameIndex
            seenStrings[string]?.count += 1
        }
    
        var obsoleteStrings = [String]()

        // Go through strings and prune any that have not been seen in while.
        // Also find the (non-pruned) string with the greatest count.
        for (string, obs) in seenStrings {
            // Remove previously seen text after 30 frames (~1s).
            if obs.lastSeen < frameIndex - 30 {
                obsoleteStrings.append(string)
            }
            
            // Find the string with the greatest count.
            let count = obs.count
            if !obsoleteStrings.contains(string) && count > bestCount {
                bestCount = Int64(count)
                bestString = string
            }
        }
        // Remove old strings.
        for string in obsoleteStrings {
            seenStrings.removeValue(forKey: string)
        }
        
        frameIndex += 1
    }
    
    func hasSeenStrings() -> Bool {
        return seenStrings.count != 0
    }
    
    func getStableString() -> String? {
        // Require the recognizer to see the same string at least 10 times.
        if bestCount >= 1 {
            return bestString
        } else {
            return nil
        }
    }
    
    func reset(string: String) {
        seenStrings.removeValue(forKey: string)
        bestCount = 0
        bestString = ""
    }
}

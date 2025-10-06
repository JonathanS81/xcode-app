//
//  Game+TurnEngine.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//

import Foundation
import SwiftData

@Model
final class AppSettings {
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    var enableSmallStraight: Bool
    var smallStraightScore: Int
    var darkMode: Bool
    
    init(
        upperBonusThreshold: Int = 63,
        upperBonusValue: Int = 35,
        enableSmallStraight: Bool = true,
        smallStraightScore: Int = 10,
        darkMode: Bool = false
    ) {
        self.upperBonusThreshold = upperBonusThreshold
        self.upperBonusValue = upperBonusValue
        self.enableSmallStraight = enableSmallStraight
        self.smallStraightScore = smallStraightScore
        self.darkMode = darkMode
    }
}



import Foundation
import SwiftData

@Model
final class AppSettings {
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    var enableSmallStraight: Bool
    var smallStraightScore: Int      // ← nouveau
    var darkMode: Bool
    var middleModeRaw: String
    var bottomModeRaw: String

    var middleMode: MiddleMode {
        get { MiddleMode(rawValue: middleModeRaw) ?? .marieAnne }
        set { middleModeRaw = newValue.rawValue }
    }
    var bottomMode: BottomMode {
        get { BottomMode(rawValue: bottomModeRaw) ?? .jon }
        set { bottomModeRaw = newValue.rawValue }
    }

    init(
        upperBonusThreshold: Int = 63,
        upperBonusValue: Int = 35,
        enableSmallStraight: Bool = true,
        smallStraightScore: Int = 10,   // ← valeur par défaut
        darkMode: Bool = false
    ) {
        self.upperBonusThreshold = upperBonusThreshold
        self.upperBonusValue = upperBonusValue
        self.enableSmallStraight = enableSmallStraight
        self.smallStraightScore = smallStraightScore
        self.darkMode = darkMode
        self.middleModeRaw = MiddleMode.marieAnne.rawValue
        self.bottomModeRaw = BottomMode.jon.rawValue
    }
}


import Foundation
import SwiftData

@Model
final class Game: Identifiable {
    var id: UUID
    // Frozen parameters at creation time
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    var middleModeRaw: String
    var bottomModeRaw: String
    var enableSmallStraight: Bool
    var smallStraightScore: Int    // ← nouveau

    // State
    var createdAt: Date
    var comment: String
    var columns: Int
    var statusRaw: String

    // Relationship
    @Relationship(deleteRule: .cascade) var scorecards: [Scorecard] = []

    var status: GameStatus {
        get { GameStatus(rawValue: statusRaw) ?? .inProgress }
        set { statusRaw = newValue.rawValue }
    }

    var middleMode: MiddleMode { MiddleMode(rawValue: middleModeRaw) ?? .marieAnne }
    var bottomMode: BottomMode { BottomMode(rawValue: bottomModeRaw) ?? .jon }

    init(settings: AppSettings, columns: Int = 1, comment: String = "") {
        self.id = UUID()
        self.upperBonusThreshold = settings.upperBonusThreshold
        self.upperBonusValue = settings.upperBonusValue
        self.middleModeRaw = settings.middleModeRaw
        self.bottomModeRaw = settings.bottomModeRaw
        self.enableSmallStraight = settings.enableSmallStraight
        self.smallStraightScore = settings.smallStraightScore   // ← nouveau
        self.createdAt = Date()
        self.comment = comment
        self.columns = columns
        self.statusRaw = GameStatus.inProgress.rawValue
    }
}

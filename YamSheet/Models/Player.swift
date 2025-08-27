import Foundation
import SwiftData

@Model
final class Player: Identifiable {
    var id: UUID
    var name: String
    var nickname: String
    var email: String?
    var isGuest: Bool

    // Basic stats
    var gamesCount: Int
    var yamsCount: Int
    var averageScore: Double
    var bestScore: Int
    var worstScore: Int
    var wins: Int
    var losses: Int

    init(name: String, nickname: String, email: String? = nil, isGuest: Bool = false) {
        self.id = UUID()
        self.name = name
        self.nickname = nickname
        self.email = email
        self.isGuest = isGuest
        self.gamesCount = 0
        self.yamsCount = 0
        self.averageScore = 0
        self.bestScore = 0
        self.worstScore = 0
        self.wins = 0
        self.losses = 0
    }
}

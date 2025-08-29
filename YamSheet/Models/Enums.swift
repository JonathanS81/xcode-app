import Foundation

enum GameStatus: String, Codable, CaseIterable, Identifiable {
    case inProgress, paused, completed
    var id: String { rawValue }
}

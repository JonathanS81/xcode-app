import Foundation

enum MiddleMode: String, Codable, CaseIterable, Identifiable {
    case disabled, marieAnne, jon
    var id: String { rawValue }
}

enum BottomMode: String, Codable, CaseIterable, Identifiable {
    case marieAnne, jon
    var id: String { rawValue }
}

enum GameStatus: String, Codable, CaseIterable, Identifiable {
    case inProgress, paused, completed
    var id: String { rawValue }
}

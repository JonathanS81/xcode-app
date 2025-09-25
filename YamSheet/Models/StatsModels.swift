//
//  StatsModels.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 21/09/2025.
//
import Foundation

struct PlayerStats: Identifiable, Hashable {
    var id: UUID { playerID }
    let playerID: UUID
    let name: String

    let gamesPlayed: Int
    let wins: Int
    var winRate: Double { gamesPlayed > 0 ? Double(wins) / Double(gamesPlayed) : 0 }

    let avgScore: Double
    let bestScore: Int
    let worstScore: Int
    let yamsRate: Double

    // 👉 Historique des scores pour les graphiques
    let scoresHistory: [Int]
}

struct AppStats {
    let totalGames: Int
    let completedGames: Int
    let totalPlayers: Int

    let bestScoreEver: (name: String, score: Int)?
    /// Classement global (du meilleur au moins bon) : (nom, meilleur score)
    let leaderboardTop: [(name: String, bestScore: Int)]

    let mostWins: (name: String, wins: Int)?
}

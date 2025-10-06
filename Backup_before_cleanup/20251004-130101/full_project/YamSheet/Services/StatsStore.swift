//
//  StatsStore.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 23/09/2025.
//

import Foundation
@preconcurrency import SwiftData
import Combine

// Explicitly declare a box that we assert is safe to send across Task boundaries
private struct UnsafeSendable<T>: @unchecked Sendable { let value: T }

@MainActor
final class StatsStore: ObservableObject {
    @Published private(set) var playerStats: [PlayerStats] = []
    @Published private(set) var appStats: AppStats? = nil

    private var calcTask: Task<Void, Never>?
    private var lastFingerprint: String = ""

    func refresh(players: [Player], games: [Game]) {
        // Empêche recalcul si rien n’a changé (fingerprint léger)
        let fp = Self.fingerprint(players: players, games: games)
        guard fp != lastFingerprint else { return }
        lastFingerprint = fp

        calcTask?.cancel()
        let p = UnsafeSendable(value: players)
        let g = UnsafeSendable(value: games)
        calcTask = Task { [p, g] in
            // Petit debounce pour regrouper les rafales de changements
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms

            // Calcul en tâche de fond
            let result = Self.compute(players: p.value, games: g.value)
            guard !Task.isCancelled else { return }

            self.playerStats = result.playerStats
            self.appStats = result.appStats
        }
    }

    private static func fingerprint(players: [Player], games: [Game]) -> String {
        // très léger : nb joueurs, nb parties, nb complétées, dernières dates
        let p = players.count
        let g = games.count
        let gc = games.filter { $0.statusOrDefault == .completed }.count
        let lastGameEdit = games.compactMap { $0.endedAt ?? $0.startedAt }.max() ?? .distantPast
        return "\(p)-\(g)-\(gc)-\(lastGameEdit.timeIntervalSince1970)"
    }

    private static func compute(players: [Player], games: [Game]) -> (playerStats: [PlayerStats], appStats: AppStats) {
        // Calcul pur (aucun accès UI / MainActor)
        let ps = StatsService.playerStats(allPlayers: players, games: games)
        let asg = StatsService.appStats(allPlayers: players, games: games)
        return (ps, asg)
    }
}

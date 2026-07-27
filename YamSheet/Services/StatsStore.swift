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
    private var lastFingerprint: Int?

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
            do {
                try await Task.sleep(nanoseconds: 150_000_000) // 150ms
            } catch {
                return
            }
            guard !Task.isCancelled else { return }

            // Calcul unique après le debounce. Les modèles SwiftData restent
            // volontairement sur leur acteur d'origine.
            let result = Self.compute(players: p.value, games: g.value)
            guard !Task.isCancelled else { return }

            self.playerStats = result.playerStats
            self.appStats = result.appStats
        }
    }

    private static func fingerprint(players: [Player], games: [Game]) -> Int {
        var hasher = Hasher()

        for player in players.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(player.id)
            hasher.combine(player.name)
            hasher.combine(player.nickname)
        }

        for game in games.sorted(by: { $0.id.uuidString < $1.id.uuidString }) {
            hasher.combine(game.id)
            hasher.combine(game.statusOrDefault.rawValue)
            hasher.combine(game.endedAt)
            hasher.combine(game.notationData)

            for scorecard in game.scorecards.sorted(
                by: { $0.id.uuidString < $1.id.uuidString }
            ) {
                hasher.combine(scorecard.id)
                hasher.combine(scorecard.playerID)
                hasher.combine(scorecard.onesData)
                hasher.combine(scorecard.twosData)
                hasher.combine(scorecard.threesData)
                hasher.combine(scorecard.foursData)
                hasher.combine(scorecard.fivesData)
                hasher.combine(scorecard.sixesData)
                hasher.combine(scorecard.maxValsData)
                hasher.combine(scorecard.minValsData)
                hasher.combine(scorecard.brelanData)
                hasher.combine(scorecard.chanceData)
                hasher.combine(scorecard.fullData)
                hasher.combine(scorecard.carreData)
                hasher.combine(scorecard.yamsData)
                hasher.combine(scorecard.suiteData)
                hasher.combine(scorecard.petiteSuiteData)
                hasher.combine(scorecard.declaredYamsData)
                hasher.combine(scorecard.extraYamsAwarded)
                hasher.combine(scorecard.extraYamsSourceData)
                hasher.combine(scorecard.extraYamsAwardsData)
            }
        }

        return hasher.finalize()
    }

    private static func compute(players: [Player], games: [Game]) -> (playerStats: [PlayerStats], appStats: AppStats) {
        // Calcul pur (aucun accès UI / MainActor)
        let ps = StatsService.playerStats(allPlayers: players, games: games)
        let asg = StatsService.appStats(allPlayers: players, games: games)
        return (ps, asg)
    }
}

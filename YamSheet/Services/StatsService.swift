//
//  StatsService.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 21/09/2025.
//

import Foundation
import SwiftData

enum StatsService {

    // MARK: - Totaux

    /// Score total (toutes sections + extra yams)
    /// Par défaut on travaille en colonne 0 (score simple colonne).
    static func total(for sc: Scorecard, game: Game, col: Int = 0) -> Int {
        StatsEngine.total(sc: sc, game: game, col: col)
    }

    // MARK: - Stats par joueur

    /// Calcule les statistiques par joueur à partir des parties **terminées**.
    /// Optimisé : pré-calcul des totaux (gameID × playerID) pour éviter les recalculs.
    static func playerStats(allPlayers: [Player], games: [Game]) -> [PlayerStats] {
        let playersByID = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0) })
        let completed = games.filter { $0.statusOrDefault == .completed }

        // 1) Pré-calcul des totaux par (gameID, playerID)
        var totalByGamePlayer: [ObjectIdentifier: [UUID: Int]] = [:]
        for g in completed {
            let gid = ObjectIdentifier(g)
            totalByGamePlayer[gid] = Dictionary(uniqueKeysWithValues:
                g.scorecards.map { sc in (sc.playerID, total(for: sc, game: g)) }
            )
        }

        // 2) Accumulation sans recalculer
        var acc: [UUID: (scores: [Int], wins: Int, yamsHits: Int, gamesPlayed: Int, name: String)] = [:]

        for g in completed {
            let gid = ObjectIdentifier(g)
            guard let row = totalByGamePlayer[gid] else { continue }

            // Gagnants de la partie (égalité supportée)
            let totals = row.map { (pid: $0.key, total: $0.value) }
            let top = totals.map { $0.total }.max() ?? 0
            let winners = Set(totals.filter { $0.total == top }.map { $0.pid })

            for sc in g.scorecards {
                let pid = sc.playerID
                let name = playersByID[pid]?.nickname ?? "—"

                var e = acc[pid] ?? (scores: [], wins: 0, yamsHits: 0, gamesPlayed: 0, name: name)
                let t = row[pid] ?? 0

                e.scores.append(t)
                e.gamesPlayed += 1
                if winners.contains(pid) { e.wins += 1 }

                // Yams > 0 en colonne 0 ?
                let yamsVal = (0 < sc.yams.count) ? sc.yams[0] : -1
                if yamsVal > 0 { e.yamsHits += 1 }

                e.name = name
                acc[pid] = e
            }
        }

        return acc.map { (pid, s) in
            let played = s.gamesPlayed
            let sum = s.scores.reduce(0, +)
            let avg = played > 0 ? Double(sum) / Double(played) : 0
            let best = s.scores.max() ?? 0
            let worst = s.scores.min() ?? 0
            let yRate = played > 0 ? Double(s.yamsHits) / Double(played) : 0

            return PlayerStats(
                playerID: pid,
                name: s.name,
                gamesPlayed: played,
                wins: s.wins,
                avgScore: avg,
                bestScore: best,
                worstScore: worst,
                yamsRate: yRate,
                scoresHistory: s.scores
            )
        }
        .sorted { $0.bestScore > $1.bestScore }
    }

    // MARK: - Stats globales

    /// Statistiques générales de l’application (sur parties terminées).
    static func appStats(allPlayers: [Player], games: [Game]) -> AppStats {
        let completed = games.filter { $0.statusOrDefault == .completed }

        var bestEver: (name: String, score: Int)? = nil
        var bestByPlayer: [UUID: Int] = [:]
        var winsByPlayer: [UUID: Int] = [:]

        for g in completed {
            // Totaux de la partie
            let totals = g.scorecards.map { (pid: $0.playerID, total: total(for: $0, game: g)) }

            // Meilleur score de la partie (pour bestEver + wins)
            if let max = totals.max(by: { $0.total < $1.total }) {
                // Best ever (record global)
                if bestEver == nil || max.total > bestEver!.score {
                    let winnerName = allPlayers.first(where: { $0.id == max.pid })?.nickname
                        ?? g.scorecards.first(where: { $0.playerID == max.pid }).map { _ in "—" }
                        ?? "—"
                    bestEver = (winnerName, max.total)
                }

                // Victoires : tous les ex-aequo en tête marquent 1 win
                let top = totals.map { $0.total }.max() ?? max.total
                for t in totals where t.total == top {
                    winsByPlayer[t.pid, default: 0] += 1
                }
            }

            // Meilleur score par joueur (perso)
            for sc in g.scorecards {
                let t = total(for: sc, game: g)
                bestByPlayer[sc.playerID] = max(bestByPlayer[sc.playerID] ?? 0, t)
            }
        }

        // Leaderboard = meilleurs scores personnels
        let leaderboard: [(name: String, bestScore: Int)] = bestByPlayer.compactMap { (pid, score) in
            guard let name = allPlayers.first(where: { $0.id == pid })?.nickname else { return nil }
            return (name, score)
        }
        .sorted { $0.bestScore > $1.bestScore }

        // Joueur avec le plus de victoires
        let mostWins: (name: String, wins: Int)? = winsByPlayer
            .max(by: { $0.value < $1.value })
            .flatMap { (pid, w) in
                if let name = allPlayers.first(where: { $0.id == pid })?.nickname {
                    return (name, w)
                }
                return nil
            }

        return AppStats(
            totalGames: games.count,
            completedGames: completed.count,
            totalPlayers: allPlayers.count,
            bestScoreEver: bestEver,
            leaderboardTop: leaderboard,
            mostWins: mostWins
        )
    }
}

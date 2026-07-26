//
//  StatsService.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 21/09/2025.
//

import Foundation

enum StatsService {

    // MARK: - Totaux

    /// Score total (toutes sections + extra yams)
    /// Par défaut on travaille en colonne 0 (score simple colonne).
    static func total(for sc: Scorecard, game: Game, col: Int = 0) -> Int {
        StatsEngine.total(sc: sc, game: game, col: col)
    }

    // MARK: - Yams

    /// Nombre réel de lancers de Yams enregistrés sur une feuille.
    /// Une déclaration et une prime rattachées à la même catégorie ne comptent qu'une fois.
    static func yamsCount(for sc: Scorecard, col: Int? = nil) -> Int {
        let columns = col.map { [$0] } ?? Array(0..<max(sc.columns, sc.extraYamsAwarded.count))
        var count = 0

        for column in columns {
            if sc.yams.indices.contains(column), sc.yams[column] > 0 {
                count += 1
            }

            let prefix = "\(column)."
            let declaredKeys = Set(
                sc.declaredYams.compactMap { entry -> String? in
                    guard entry.value, entry.key.hasPrefix(prefix) else { return nil }
                    return String(entry.key.dropFirst(prefix.count))
                }
            )
            count += declaredKeys.filter { $0 != "yams" }.count

            let representedKeys = declaredKeys.union(
                sc.yams.indices.contains(column) && sc.yams[column] > 0 ? ["yams"] : []
            )
            for source in sc.extraYamsAwardSources(col: column) {
                if !representedKeys.contains(source) {
                    count += 1
                }
            }
        }

        return count
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
        var acc: [UUID: (scores: [Int], wins: Int, yamsHits: Int, yamsCount: Int, gamesPlayed: Int, name: String)] = [:]

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

                var e = acc[pid] ?? (scores: [], wins: 0, yamsHits: 0, yamsCount: 0, gamesPlayed: 0, name: name)
                let t = row[pid] ?? 0

                e.scores.append(t)
                e.gamesPlayed += 1
                if winners.contains(pid) { e.wins += 1 }

                let gameYamsCount = yamsCount(for: sc)
                e.yamsCount += gameYamsCount
                if gameYamsCount > 0 { e.yamsHits += 1 }

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
                yamsCount: s.yamsCount,
                scoresHistory: s.scores
            )
        }
        .sorted { $0.bestScore > $1.bestScore }
    }


    // MARK: - Extra Yams (primes)

    /// Nombre de primes de Yams par joueur.
    static func yamsPrimesByPlayer(games: [Game], col: Int = 0) -> [UUID: Int] {
        let completed = games.filter { $0.statusOrDefault == .completed }
        var acc: [UUID: Int] = [:]
        for g in completed {
            for sc in g.scorecards {
                let count = sc.extraYamsAwardsCount(col: col)
                if count > 0 {
                    acc[sc.playerID, default: 0] += count
                }
            }
        }
        return acc
    }

    /// Nombre de primes de Yams pour un joueur donné.
    static func yamsPrimesCount(for playerID: UUID, games: [Game], col: Int = 0) -> Int {
        yamsPrimesByPlayer(games: games, col: col)[playerID] ?? 0
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

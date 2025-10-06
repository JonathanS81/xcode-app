//
//  AppStatsView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 21/09/2025.
//

import SwiftUI
import Charts
import SwiftData

private struct VictoryEntry: Identifiable {
    let id = UUID()
    let name: String
    let wins: Int
}

private struct AverageEntry: Identifiable {
    let id = UUID()
    let name: String
    let avg: Double
}

struct AppStatsView: View {
    @EnvironmentObject var statsStore: StatsStore
    let stats: AppStats?
    @Environment(\.modelContext) private var modelContext
    @Query private var allGames: [Game]
    @Query(sort: \Player.nickname, order: .forward) private var allPlayers: [Player]
  

    private var colorByName: [String: Color] {
        Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.nickname.isEmpty ? $0.name : $0.nickname, $0.color) })
    }

    private var domainNamesForCharts: [String] {
        // Assure un ordre stable pour la palette custom
        Array(colorByName.keys).sorted()
    }

    private var rangeColorsForCharts: [Color] {
        domainNamesForCharts.compactMap { colorByName[$0] }
    }

    private var fallbackVictories: [VictoryEntry] {
        guard !allGames.isEmpty else { return [] }
        var winsByPlayer: [UUID: Int] = [:]
        for g in allGames where g.statusOrDefault == .completed {
            var bestPID: UUID? = nil
            var bestScore = Int.min
            for sc in g.scorecards {
                var total = 0
                let mirror = Mirror(reflecting: sc)
                if let totals = mirror.children.first(where: { $0.label == "totals" })?.value as? [Int] {
                    total = totals.last ?? 0
                } else if let totalAll = mirror.children.first(where: { $0.label == "totalAll" })?.value as? Int {
                    total = totalAll
                }
                if total > bestScore {
                    bestScore = total
                    bestPID = sc.playerID
                }
            }
            if let pid = bestPID { winsByPlayer[pid, default: 0] += 1 }
        }
        let nameByID = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0.nickname) })
        return winsByPlayer.compactMap { (pid, w) in
            guard let name = nameByID[pid] else { return nil }
            return VictoryEntry(name: name, wins: w)
        }.sorted { $0.wins > $1.wins }
    }

    // Best-effort extraction of a scorecard's final total across various model versions
    private func finalTotal(from sc: Scorecard) -> Int {
        let m = Mirror(reflecting: sc)

        // 1) Direct well-known integer fields
        if let v = m.children.first(where: { $0.label == "totalAll" })?.value as? Int { return v }
        if let v = m.children.first(where: { $0.label == "grandTotal" })?.value as? Int { return v }
        if let v = m.children.first(where: { $0.label == "total" })?.value as? Int { return v }
        if let v = m.children.first(where: { $0.label == "overallTotal" })?.value as? Int { return v }

        // 2) Arrays potentially containing totals – take the last or the max
        if let arr = m.children.first(where: { $0.label == "totals" })?.value as? [Int] { return arr.last ?? 0 }
        if let arr = m.children.first(where: { $0.label == "allTotals" })?.value as? [Int] { return arr.last ?? 0 }
        if let arr = m.children.first(where: { $0.label == "sectionTotals" })?.value as? [Int] { return arr.reduce(0, +) }

        // 3) Any Int field whose name contains "total" or "sum" – keep the max
        var best = 0
        for c in m.children {
            guard let label = c.label?.lowercased() else { continue }
            if let v = c.value as? Int, (label.contains("total") || label.contains("sum")) {
                best = max(best, v)
            }
            if let arr = c.value as? [Int], (label.contains("total") || label.contains("sum")) {
                if let last = arr.last { best = max(best, last) }
            }
        }

        // 4) Numeric strings that look like totals (e.g., "123" or "Total: 245") – take the max number found
        if best == 0 {
            var numericMax = 0
            for c in m.children {
                guard let label = c.label?.lowercased() else { continue }
                if label.contains("total"), let s = c.value as? String {
                    let digits = s.filter { $0.isNumber }
                    if let v = Int(digits) { numericMax = max(numericMax, v) }
                }
            }
            best = max(best, numericMax)
        }
        return best
    }

    private var fallbackAverages: [AverageEntry] {
        guard !allGames.isEmpty else { return [] }
        var sums: [UUID: Int] = [:]
        var counts: [UUID: Int] = [:]
        for g in allGames where g.statusOrDefault == .completed {
            for sc in g.scorecards {
                let total = finalTotal(from: sc)
                sums[sc.playerID, default: 0] += total
                counts[sc.playerID, default: 0] += 1
            }
        }
        let nameByID = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0.nickname) })
        return sums.compactMap { (pid, sum) in
            guard let c = counts[pid], c > 0, let name = nameByID[pid] else { return nil }
            return AverageEntry(name: name, avg: Double(sum) / Double(c))
        }.sorted { $0.avg > $1.avg }
    }

    // Compute averages directly from the canonical score engine (StatsService/StatsEngine)
    private func averagesFromEngine() -> [AverageEntry] {
        guard !allGames.isEmpty else { return [] }
        var sums: [UUID: Int] = [:]
        var counts: [UUID: Int] = [:]
        for g in allGames where g.statusOrDefault == .completed {
            for sc in g.scorecards {
                let t = StatsService.total(for: sc, game: g)
                sums[sc.playerID, default: 0] += t
                counts[sc.playerID, default: 0] += 1
            }
        }
        let nameByID = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0.nickname) })
        return sums.compactMap { (pid, sum) in
            guard let c = counts[pid], c > 0, let name = nameByID[pid] else { return nil }
            return AverageEntry(name: name, avg: Double(sum) / Double(c))
        }
    }

    var body: some View {
        List {
            if let s = stats {
                // Section: Général
                Section("Général") {
                    LabeledContent("Parties (total)", value: "\(s.totalGames)")
                    LabeledContent("Parties terminées", value: "\(s.completedGames)")
                    LabeledContent("Joueurs", value: "\(s.totalPlayers)")
                }

                // Section: Records
                Section("Records") {
                    if let best = s.bestScoreEver {
                        LabeledContent("Meilleur score", value: "\(best.score) — \(best.name)")
                    } else {
                        Text("Pas encore de partie terminée.")
                    }
                    if let mw = s.mostWins {
                        LabeledContent("Plus de victoires", value: "\(mw.wins) — \(mw.name)")
                    }
                }

                // Section: Victoires par joueur (Bar Chart)
                Section("Victoires par joueur") {
                    let victories: [VictoryEntry] = {
                        let fromStore = statsStore.playerStats
                            .map { VictoryEntry(name: $0.name, wins: $0.wins) }
                            .filter { $0.wins > 0 }
                        return fromStore.isEmpty ? fallbackVictories : fromStore
                    }()
                    if !victories.isEmpty {
                        Chart {
                            ForEach(victories) { entry in
                                SectorMark(
                                    angle: .value("Victoires", entry.wins),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(by: .value("Joueur", entry.name))
                                .annotation(position: .overlay, alignment: .center) {
                                    Text(entry.name).font(.caption2)
                                }
                            }
                        }
                        .chartForegroundStyleScale(domain: domainNamesForCharts, range: rangeColorsForCharts)
                        .frame(height: 220)
                        
                    } else {
                        Text("Aucune donnée de victoires par joueur.").foregroundStyle(.secondary)
                    }
                }

                // Section: Score moyen par joueur (Bar Chart)
                Section("Score moyen par joueur") {
                    let avgsFromStore: [AverageEntry] = statsStore.playerStats.map { AverageEntry(name: $0.name, avg: $0.avgScore) }

                    // 2) Fallback: si le store est vide **ou** ne retourne que des 0, on calcule via StatsService/StatsEngine
                    let avgs: [AverageEntry] = {
                        if avgsFromStore.isEmpty || avgsFromStore.allSatisfy({ $0.avg == 0 }) {
                            let engine = averagesFromEngine()
                            return engine.isEmpty ? fallbackAverages : engine
                        }
                        return avgsFromStore
                    }()
                    let avgsSorted = avgs.sorted { $0.avg > $1.avg }

                    if !avgsSorted.isEmpty {
                        let maxAvg = avgsSorted.map { $0.avg }.max() ?? 0
                        Chart {
                            ForEach(avgsSorted) { entry in
                                BarMark(
                                    x: .value("Joueur", entry.name),
                                    y: .value("Moyenne", entry.avg)
                                )
                                .foregroundStyle(by: .value("Joueur", entry.name))
                                .annotation(position: .overlay, alignment: .center) {
                                    Text("\(Int(entry.avg.rounded()))")
                                        .font(.caption2)
                                        .bold()
                                }
                            }
                        }
                        .chartForegroundStyleScale(domain: domainNamesForCharts, range: rangeColorsForCharts)
                        .chartYScale(domain: 0...(maxAvg > 0 ? maxAvg * 1.1 : 1))
                        .frame(height: 220)
                    } else {
                        Text("Pas encore assez de parties pour calculer des moyennes.")
                            .foregroundStyle(.secondary)
                    }
                }

                // Section: Répartition des victoires (Pie Chart)
                Section("Répartition des victoires") {
                    let victories: [VictoryEntry] = {
                        let fromStore = statsStore.playerStats
                            .map { VictoryEntry(name: $0.name, wins: $0.wins) }
                            .filter { $0.wins > 0 }
                        return fromStore.isEmpty ? fallbackVictories : fromStore
                    }()
                    if !victories.isEmpty {
                        Chart {
                            ForEach(victories) { entry in
                                SectorMark(
                                    angle: .value("Victoires", entry.wins),
                                    innerRadius: .ratio(0.5),
                                    angularInset: 2
                                )
                                .foregroundStyle(by: .value("Joueur", entry.name))
                                .annotation(position: .overlay, alignment: .center) {
                                    Text(entry.name)
                                        .font(.caption2)
                                }
                            }
                        }
                        .frame(height: 220)
                    } else {
                        Text("Aucune donnée sur la répartition des victoires.").foregroundStyle(.secondary)
                    }
                }

            } else {
                Text("Calcul des statistiques…").foregroundStyle(.secondary)
            }
        }
    }
}

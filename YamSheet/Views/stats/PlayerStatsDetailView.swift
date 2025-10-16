//
//  PlayerStatsDetailView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 22/09/2025.
//
import SwiftUI
import Charts
import SwiftData

struct PlayerStatsDetailView: View {
    
    let stats: PlayerStats

    @Query private var allPlayers: [Player]

    private var playerColor: Color {
        allPlayers.first(where: { $0.id == stats.playerID })?.color ?? .accentColor
    }
    
    @EnvironmentObject private var statsStore: StatsStore
    @Environment(\.modelContext) private var modelContext
    @Query private var allGames: [Game]

    // Helpers for charts
    private var scoresIndexed: [(index: Int, score: Int)] {
        stats.scoresHistory.enumerated().map { (idx, v) in (idx + 1, v) }
    }
    private var scoreDistribution: [(bucket: String, count: Int)] {
        guard !stats.scoresHistory.isEmpty else { return [] }
        // Buckets of 50 points, labels simplified: "0", "50", "100", ...
        let maxScore = stats.scoresHistory.max() ?? 0
        let upper = ((maxScore / 50) + 1) * 50
        var bins: [String: Int] = [:]
        for s in stride(from: 0, through: upper, by: 50) {
            let key = String(format: "%d", s)
            bins[key] = 0
        }
        for v in stats.scoresHistory {
            let bucketStart = (v / 50) * 50
            let key = String(format: "%d", bucketStart)
            bins[key, default: 0] += 1
        }
        return bins.keys
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
            .map { k in (k, bins[k] ?? 0) }
    }

    // Indexed bins for chart legibility (show fewer x labels)
    private var scoreDistributionIndexed: [(idx: Int, label: String, count: Int)] {
        let bins = scoreDistribution
        return bins.enumerated().map { (i, el) in (idx: i, label: el.bucket, count: el.count) }
    }

    private var extraYamsCount: Int {
        // Compte robustement les primes de Yams pour ce joueur, sans dépendre d'un service externe
        allGames.reduce(0) { acc, g in
            acc + g.scorecards
                .filter { $0.playerID == stats.playerID }
                .map { sc in sc.extraYamsAwarded.reduce(0) { $0 + ($1 ? 1 : 0) } }
                .reduce(0, +)
        }
    }

    var body: some View {
        List {
            // KPIs row
            Section("Résumé") {
                KPIGrid(stats: stats, extraYamsCount: extraYamsCount)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            }

            if !stats.scoresHistory.isEmpty {
                Section("Évolution des scores") {
                    Chart {
                        ForEach(scoresIndexed, id: \.index) { pt in
                            AreaMark(
                                x: .value("Partie", pt.index),
                                y: .value("Score", pt.score)
                                

                            )
                            .opacity(0.12)
                            .foregroundStyle(playerColor.opacity(0.25))   // ← fill teinté
                            LineMark(
                                x: .value("Partie", pt.index),
                                y: .value("Score", pt.score)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .foregroundStyle(playerColor)
                            PointMark(
                                x: .value("Partie", pt.index),
                                y: .value("Score", pt.score)
                            )
                            .foregroundStyle(playerColor)
                        }
                    }
                    .frame(height: 220)
                }

                Section("Distribution des scores") {
                    VStack(alignment: .leading, spacing: 4) {
                        Chart {
                            ForEach(scoreDistributionIndexed, id: \.idx) { bin in
                                BarMark(
                                    x: .value("Bin", bin.idx),
                                    y: .value("Occurrences", bin.count)
                                )
                                .foregroundStyle(playerColor)
                                .annotation(position: .top, alignment: .center) {
                                    if bin.count > 0 {
                                        Text("\(bin.count)").font(.caption2)
                                    }
                                }
                            }
                        }
                        .chartXAxis {
                            let bins = scoreDistributionIndexed
                            let total = bins.count
                            let step = max(1, total / 6)
                            AxisMarks(values: bins.map { $0.idx }) { value in
                                AxisGridLine().foregroundStyle(.clear)
                                AxisTick()
                                if let i = value.as(Int.self) {
                                    if i % step == 0 || i == total - 1 {
                                        AxisValueLabel(bins[i].label)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                AxisValueLabel()
                            }
                        }
                        .frame(height: 220)

                        Text("*Les valeurs de l’axe horizontal représentent des intervalles de 50 points*")
                            .font(.footnote)
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                }
            }
        }
        .navigationTitle(stats.name)
    }
}

// MARK: - KPI Grid
private struct KPIGrid: View {
    let stats: PlayerStats
    let extraYamsCount: Int

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                KPI(title: "Parties", value: "\(stats.gamesPlayed)")
                KPI(title: "Victoires", value: "\(stats.wins)")
                KPI(title: "% Win", value: "\(Int(stats.winRate * 100))%")
            }
            HStack(spacing: 12) {
                KPI(title: "Moyenne", value: "\(Int(stats.avgScore.rounded()))")
                KPI(title: "Best", value: "\(stats.bestScore)")
                KPI(title: "Worst", value: "\(stats.worstScore)")
            }
            HStack(spacing: 12) {
                KPI(title: "Taux Yams", value: "\(Int(stats.yamsRate * 100))%")
                KPI(title: "Primes Yams", value: "\(extraYamsCount)")
            }
        }
        .padding(.vertical, 4)
    }
}

private struct KPI: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }
}

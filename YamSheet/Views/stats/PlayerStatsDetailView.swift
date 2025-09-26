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

    @EnvironmentObject private var statsStore: StatsStore
    @Environment(\.modelContext) private var modelContext
    @Query private var allGames: [Game]

    // Helpers for charts
    private var scoresIndexed: [(index: Int, score: Int)] {
        stats.scoresHistory.enumerated().map { (idx, v) in (idx + 1, v) }
    }
    private var scoreDistribution: [(bucket: String, count: Int)] {
        guard !stats.scoresHistory.isEmpty else { return [] }
        // Buckets of 50 points: 0-49, 50-99, ... up to max
        let maxScore = stats.scoresHistory.max() ?? 0
        let upper = ((maxScore / 50) + 1) * 50
        var bins: [String: Int] = [:]
        for s in stride(from: 0, through: upper, by: 50) {
            let key = String(format: "%d–%d", s, min(s+49, upper))
            bins[key] = 0
        }
        for v in stats.scoresHistory {
            let bucketStart = (v / 50) * 50
            let key = String(format: "%d–%d", bucketStart, min(bucketStart+49, upper))
            bins[key, default: 0] += 1
        }
        // keep natural order
        return bins.keys.sorted { a, b in
            let aStart = Int(a.split(separator: "–").first ?? "0") ?? 0
            let bStart = Int(b.split(separator: "–").first ?? "0") ?? 0
            return aStart < bStart
        }.map { k in (k, bins[k] ?? 0) }
    }
    private var extraYamsCount: Int {
        // Utilise directement les parties via SwiftData (@Query)
        StatsService.yamsPrimesCount(for: stats.playerID, games: allGames)
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
                            LineMark(
                                x: .value("Partie", pt.index),
                                y: .value("Score", pt.score)
                            )
                            .interpolationMethod(.catmullRom)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            PointMark(
                                x: .value("Partie", pt.index),
                                y: .value("Score", pt.score)
                            )
                        }
                    }
                    .frame(height: 220)
                }

                Section("Distribution des scores") {
                    Chart {
                        ForEach(scoreDistribution, id: \.bucket) { bin in
                            BarMark(
                                x: .value("Plage", bin.bucket),
                                y: .value("Occurrences", bin.count)
                            )
                            .annotation(position: .top, alignment: .center) {
                                if bin.count > 0 {
                                    Text("\(bin.count)").font(.caption2)
                                }
                            }
                        }
                    }
                    .chartXAxis {
                        AxisMarks(position: .bottom) { _ in
                            AxisGridLine().foregroundStyle(.clear) // éviter le bruit
                            AxisTick()
                            AxisValueLabel()
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading) { value in
                            AxisGridLine()
                            AxisValueLabel()
                        }
                    }
                    .frame(height: 220)
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

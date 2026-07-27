//
//  PlayerStatsDetailView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 22/09/2025.
//
import SwiftUI
import Charts
import SwiftData

private struct PlayerScorePoint: Identifiable {
    let index: Int
    let score: Int
    var id: Int { index }
}

private struct ScoreDistributionPoint: Identifiable {
    let index: Int
    let label: String
    let count: Int
    var id: Int { index }
}

private struct PlayerStatsSnapshot {
    let notationOptions: [StatsNotationOption]
    let completedPlayerGamesCount: Int
    let displayedStats: PlayerStats
    let scoresHistory: [Int]
    let scoresIndexed: [PlayerScorePoint]
    let scoreDistribution: [ScoreDistributionPoint]
    let extraYamsCount: Int

    static func empty(for stats: PlayerStats) -> PlayerStatsSnapshot {
        PlayerStatsSnapshot(
            notationOptions: [],
            completedPlayerGamesCount: 0,
            displayedStats: PlayerStats(
                playerID: stats.playerID,
                name: stats.name,
                gamesPlayed: 0,
                wins: 0,
                avgScore: 0,
                bestScore: 0,
                bestScoreNotation: nil,
                worstScore: 0,
                worstScoreNotation: nil,
                yamsRate: 0,
                yamsCount: 0,
                scoresHistory: []
            ),
            scoresHistory: [],
            scoresIndexed: [],
            scoreDistribution: [],
            extraYamsCount: 0
        )
    }
}

struct PlayerStatsDetailView: View {
    
    let stats: PlayerStats

    @Query private var allPlayers: [Player]

    private var playerColor: Color {
        allPlayers.first(where: { $0.id == stats.playerID })?.color ?? .accentColor
    }
    
    @Query private var allGames: [Game]
    @State private var selectedNotationName: String?
    @State private var snapshot: PlayerStatsSnapshot?

    private func scoreDistribution(
        from scoresHistory: [Int]
    ) -> [ScoreDistributionPoint] {
        guard !scoresHistory.isEmpty else { return [] }
        // Buckets of 50 points, labels simplified: "0", "50", "100", ...
        let maxScore = scoresHistory.max() ?? 0
        let upper = ((maxScore / 50) + 1) * 50
        var bins: [String: Int] = [:]
        for s in stride(from: 0, through: upper, by: 50) {
            let key = String(format: "%d", s)
            bins[key] = 0
        }
        for v in scoresHistory {
            let bucketStart = (v / 50) * 50
            let key = String(format: "%d", bucketStart)
            bins[key, default: 0] += 1
        }
        return bins.keys
            .sorted { (Int($0) ?? 0) < (Int($1) ?? 0) }
            .enumerated()
            .map {
                ScoreDistributionPoint(
                    index: $0.offset,
                    label: $0.element,
                    count: bins[$0.element] ?? 0
                )
            }
    }

    private func makeSnapshot() -> PlayerStatsSnapshot {
        let completedPlayerGames = allGames.filter {
            $0.statusOrDefault == .completed
                && $0.scorecards.contains {
                    $0.playerID == stats.playerID
                }
        }
        let filteredGames = StatsService.completedGames(
            from: completedPlayerGames,
            notationName: selectedNotationName
        )
        let displayedStats = StatsService.playerStats(
            allPlayers: allPlayers,
            games: filteredGames
        )
        .first(where: { $0.playerID == stats.playerID })
            ?? PlayerStatsSnapshot.empty(for: stats).displayedStats
        let scoresHistory = filteredGames
            .sorted {
                ($0.endedAt ?? $0.createdAt)
                    < ($1.endedAt ?? $1.createdAt)
            }
            .compactMap { game in
                game.scorecards
                    .first { $0.playerID == stats.playerID }
                    .map { StatsService.total(for: $0, game: game) }
            }
        let scoresIndexed = scoresHistory.enumerated().map {
            PlayerScorePoint(index: $0.offset + 1, score: $0.element)
        }
        let extraYamsCount = filteredGames.reduce(0) { accumulated, game in
            accumulated + game.scorecards
                .filter { $0.playerID == stats.playerID }
                .map { scorecard in
                    (0..<max(
                        scorecard.columns,
                        scorecard.extraYamsAwarded.count
                    ))
                    .reduce(0) {
                        $0 + scorecard.extraYamsAwardsCount(col: $1)
                    }
                }
                .reduce(0, +)
        }

        return PlayerStatsSnapshot(
            notationOptions: StatsService.notationOptions(
                games: completedPlayerGames
            ),
            completedPlayerGamesCount: completedPlayerGames.count,
            displayedStats: displayedStats,
            scoresHistory: scoresHistory,
            scoresIndexed: scoresIndexed,
            scoreDistribution: scoreDistribution(from: scoresHistory),
            extraYamsCount: extraYamsCount
        )
    }

    private func refreshSnapshot() {
        snapshot = makeSnapshot()
    }

    var body: some View {
        let displayedSnapshot = snapshot
            ?? PlayerStatsSnapshot.empty(for: stats)

        List {
            if displayedSnapshot.completedPlayerGamesCount > 0 {
                Section {
                    Picker(
                        "Notation",
                        selection: $selectedNotationName
                    ) {
                        Text("Toutes")
                            .tag(String?.none)
                        ForEach(displayedSnapshot.notationOptions) { option in
                            Text(option.name)
                                .tag(Optional(option.name))
                        }
                    }
                    .pickerStyle(.menu)
                }
            }

            // KPIs row
            Section("Résumé") {
                KPIGrid(
                    stats: displayedSnapshot.displayedStats,
                    extraYamsCount: displayedSnapshot.extraYamsCount
                )
                .listRowInsets(
                    EdgeInsets(
                        top: 8,
                        leading: 12,
                        bottom: 8,
                        trailing: 12
                    )
                )
            }

            if !displayedSnapshot.scoresHistory.isEmpty {
                Section("Évolution des scores") {
                    Chart {
                        ForEach(displayedSnapshot.scoresIndexed) { pt in
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
                            ForEach(
                                displayedSnapshot.scoreDistribution
                            ) { bin in
                                BarMark(
                                    x: .value("Bin", bin.index),
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
                            let bins = displayedSnapshot.scoreDistribution
                            let total = bins.count
                            let step = max(1, total / 6)
                            AxisMarks(values: bins.map { $0.index }) { value in
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
            } else if displayedSnapshot.completedPlayerGamesCount > 0 {
                Section {
                    Text("Aucun score pour cette notation.")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(stats.name)
        .task {
            refreshSnapshot()
        }
        .onChange(of: allGames) {
            refreshSnapshot()
        }
        .onChange(of: allPlayers) {
            refreshSnapshot()
        }
        .onChange(of: selectedNotationName) {
            refreshSnapshot()
        }
    }
}

// MARK: - KPI Grid
private struct KPIGrid: View {
    let stats: PlayerStats
    let extraYamsCount: Int

    var body: some View {
        LazyVGrid(
            columns: Array(
                repeating: GridItem(.flexible(), spacing: 12),
                count: 3
            ),
            spacing: 12
        ) {
            KPI(title: "Parties", value: "\(stats.gamesPlayed)")
            KPI(title: "Victoires", value: "\(stats.wins)")
            KPI(title: "% Win", value: "\(Int(stats.winRate * 100))%")
            KPI(
                title: "Moyenne",
                value: "\(Int(stats.avgScore.rounded()))",
                reservesDetailSpace: true
            )
            KPI(
                title: "Meilleur",
                value: "\(stats.bestScore)",
                detail: stats.bestScoreNotation
            )
            KPI(
                title: "Pire",
                value: "\(stats.worstScore)",
                detail: stats.worstScoreNotation
            )
            KPI(title: "Taux Yams", value: "\(Int(stats.yamsRate * 100))%")
            KPI(title: "Yams", value: "\(stats.yamsCount)")
            KPI(title: "Primes Yams", value: "\(extraYamsCount)")
        }
        .padding(.vertical, 4)
    }
}

private struct KPI: View {
    let title: String
    let value: String
    var detail: String? = nil
    var reservesDetailSpace = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3).bold()
            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            } else if reservesDetailSpace {
                Text(" ")
                    .font(.caption2)
            }
        }
        .padding(12)
        .frame(
            maxWidth: .infinity,
            minHeight: 66,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.ultraThinMaterial)
        )
    }
}

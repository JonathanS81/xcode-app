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
    let id: UUID   // player id
    let name: String
    let wins: Int
}

private struct AverageEntry: Identifiable {
    let id: UUID
    let name: String
    let avg: Double
}

private struct BarTip: Equatable {
    var name: String
    var wins: Int
    var pos: CGPoint
}

private struct BarTipText: Equatable {
    var id: UUID?    // player id when known
    var name: String
    var valueText: String
    var pos: CGPoint
}

struct AppStatsView: View {
    @EnvironmentObject var statsStore: StatsStore
    let stats: AppStats?
    @Environment(\.modelContext) private var modelContext
    @Query private var allGames: [Game]
    @Query(sort: \Player.nickname, order: .forward) private var allPlayers: [Player]
    @State private var showPieChart = false
    @State private var selectedVictoryNameBar: String?
    @State private var selectedVictorySlice: String?
    @State private var selectedNotationName: String?
    
    // Tooltip state (iOS 17+)
    @State private var barTip: BarTip? = nil
    @State private var barTipRate: BarTipText? = nil
    @State private var barTipAvg: BarTipText? = nil
    
    private func tipBubble(_ title: String, _ value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.caption.weight(.medium))
            }
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 2)
    }
    
    private func tipValueBubble(_ value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(value).font(.caption.weight(.medium))
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .shadow(radius: 2)
    }
    
    private var nameByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0.nickname.isEmpty ? $0.name : $0.nickname) })
    }
    
    private var colorByID: [UUID: Color] {
        Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0.color) })
    }

    private var notationOptions: [StatsNotationOption] {
        StatsService.notationOptions(games: allGames)
    }

    private var filteredGames: [Game] {
        StatsService.games(
            from: allGames,
            notationName: selectedNotationName
        )
    }

    private var completedGames: [Game] {
        StatsService.completedGames(
            from: allGames,
            notationName: selectedNotationName
        )
    }

    private var filteredPlayerCount: Int {
        guard selectedNotationName != nil else {
            return stats?.totalPlayers ?? allPlayers.count
        }
        return Set(
            filteredGames.flatMap {
                $0.participantIDs + $0.scorecards.map(\.playerID)
            }
        ).count
    }
    
    // Best-effort extraction of a scorecard's final total across various model versions
    private func finalTotal(from sc: Scorecard, game: Game) -> Int {
          return StatsService.total(for: sc, game: game)
      }
    // Compute averages directly from the canonical score engine (StatsService/StatsEngine)
    private func averagesFromEngine(games: [Game]) -> [AverageEntry] {
        guard !games.isEmpty else { return [] }
        var sums: [UUID: Int] = [:]
        var counts: [UUID: Int] = [:]
        for g in games {
            for sc in g.scorecards {
                let t = StatsService.total(for: sc, game: g)
                sums[sc.playerID, default: 0] += t
                counts[sc.playerID, default: 0] += 1
            }
        }
        let nameByID = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0.nickname) })
        return sums.compactMap { (pid, sum) in
            guard let c = counts[pid], c > 0, let name = nameByID[pid] else { return nil }
            return AverageEntry(
                id: pid,
                name: name,
                avg: Double(sum) / Double(c)
            )
        }
        .sorted { $0.avg > $1.avg }  // ← Ajouter le tri
    }
    
    /// Victoires par joueur, calculées à partir des parties complétées avec le moteur de score
    private func victoriesFromEngine(games: [Game]) -> [VictoryEntry] {
        guard !games.isEmpty else { return [] }
        var winsByPID: [UUID: Int] = [:]
        for g in games {
            let totals = g.scorecards.map {
                (
                    playerID: $0.playerID,
                    score: finalTotal(from: $0, game: g)
                )
            }
            guard let bestScore = totals.map(\.score).max() else {
                continue
            }
            for entry in totals where entry.score == bestScore {
                winsByPID[entry.playerID, default: 0] += 1
            }
        }
        return winsByPID.compactMap { (pid, w) in
            guard let n = nameByID[pid] else { return nil }
            return VictoryEntry(id: pid, name: n, wins: w)
        }
        .sorted { lhs, rhs in
            if lhs.wins != rhs.wins { return lhs.wins > rhs.wins } // score desc
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending // name asc
        }
    }
    
    /// Nombre total de Yams marqués par joueur (toutes parties complétées, toutes colonnes)
    private func yamsCounts(
        games: [Game]
    ) -> [(id: UUID, name: String, count: Int)] {
        guard !games.isEmpty else { return [] }
        var byPID: [UUID: Int] = [:]
        for g in games {
            for sc in g.scorecards {
                let c = StatsService.yamsCount(for: sc)
                if c > 0 { byPID[sc.playerID, default: 0] += c }
            }
        }
        return byPID.compactMap { (pid, v) in
            guard let n = nameByID[pid] else { return nil }
            return (pid, n, v)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count } // score desc
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending // name asc
        }
    }
    
    /// Nombre total de primes Yams supplémentaires attribuées par joueur
    private func extraYamsCounts(
        games: [Game]
    ) -> [(id: UUID, name: String, count: Int)] {
        guard !games.isEmpty else { return [] }
        var byPID: [UUID: Int] = [:]
        for g in games {
            for sc in g.scorecards {
                let cnt = (0..<max(sc.columns, sc.extraYamsAwarded.count))
                    .reduce(0) { $0 + sc.extraYamsAwardsCount(col: $1) }
                if cnt > 0 { byPID[sc.playerID, default: 0] += cnt }
            }
        }
        return byPID.compactMap { (pid, v) in
            guard let n = nameByID[pid] else { return nil }
            return (pid, n, v)
        }
        .sorted { lhs, rhs in
            if lhs.count != rhs.count { return lhs.count > rhs.count }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    private var totalYams: Int {
        completedGames
            .flatMap { $0.scorecards }
            .map { StatsService.yamsCount(for: $0) }
            .reduce(0, +)
    }
    
    private var totalExtraYams: Int {
        completedGames
            .flatMap { $0.scorecards }
            .map { sc in
                (0..<max(sc.columns, sc.extraYamsAwarded.count))
                    .reduce(0) { $0 + sc.extraYamsAwardsCount(col: $1) }
            }
            .reduce(0, +)
    }
    
    /// Taux de victoire par joueur = victoires / parties complétées jouées
    private struct WinRateEntry: Identifiable { let id: UUID; let name: String; let rate: Double; let wins: Int; let played: Int }
    private func winRates(games: [Game]) -> [WinRateEntry] {
        let victories = victoriesFromEngine(games: games)
        guard !games.isEmpty else { return [] }
        var playedByPID: [UUID: Int] = [:]
        for g in games {
            let pids = Set(g.scorecards.map { $0.playerID })
            for pid in pids { playedByPID[pid, default: 0] += 1 }
        }
        var byPID: [UUID: WinRateEntry] = [:]
        for (pid, played) in playedByPID {
            let wins = victories.first(where: { $0.id == pid })?.wins ?? 0
            let name = nameByID[pid] ?? "—"
            let rate = played > 0 ? (Double(wins) / Double(played) * 100.0) : 0
            byPID[pid] = WinRateEntry(id: pid, name: name, rate: rate, wins: wins, played: played)
        }
        return Array(byPID.values).sorted { $0.rate > $1.rate }
    }
    
    // MARK: - Row helpers (consistent spacing + separators inside a card)
    @ViewBuilder private func statRows(_ items: [(title: String, value: String)]) -> some View {
        VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { i in
                let it = items[i]
                LabeledContent(it.title) { Text(it.value).bold() }
                    .padding(.vertical, 10)
                if i < items.count - 1 { Divider() }
            }
        }
    }

    @ViewBuilder private func recordRow(
        title: String,
        value: String,
        notation: String? = nil
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .bold()
                    .multilineTextAlignment(.trailing)
                if let notation, !notation.isEmpty {
                    Text("(\(notation))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(.vertical, 10)
    }
    
    @ViewBuilder private func medalRow(rank: Int, color: Color, name: String, value: String) -> some View {
        HStack {
            Text(["🥇","🥈","🥉"][min(rank,2)])
            Circle().fill(color).frame(width: 10, height: 10)
            Text(name)
            Spacer()
            Text(value).bold()
        }
        .padding(.vertical, 10)
    }
    
    private func bestScoreRecord(games: [Game]) -> (
        value: Int,
        name: String,
        notation: String
    ) {
        var bestScoreVal = 0
        var bestScoreNames: Set<String> = []
        var bestNotationNames: Set<String> = []
        for g in games {
            for sc in g.scorecards {
                let t = StatsService.total(for: sc, game: g)
                if t > bestScoreVal {
                    bestScoreVal = t
                    bestScoreNames = [nameByID[sc.playerID] ?? "—"]
                    bestNotationNames = [
                        StatsService.notationName(for: g)
                    ]
                } else if t == bestScoreVal {
                    bestScoreNames.insert(nameByID[sc.playerID] ?? "—")
                    bestNotationNames.insert(
                        StatsService.notationName(for: g)
                    )
                }
            }
        }
        return (
            bestScoreVal,
            bestScoreNames.isEmpty
                ? "—"
                : bestScoreNames.sorted().joined(separator: ", "),
            bestNotationNames.isEmpty
                ? "—"
                : bestNotationNames.sorted().joined(separator: ", ")
        )
    }
    
    var body: some View {
        List {
            Section {
                Picker(
                    "Notation",
                    selection: $selectedNotationName
                ) {
                    Text("Toutes")
                        .tag(String?.none)
                    ForEach(notationOptions) { option in
                        Text(option.name)
                            .tag(Optional(option.name))
                    }
                }
                .pickerStyle(.menu)
            }

            // Section: Général
            Section {
                statRows([
                    ("Parties (total)", "\(filteredGames.count)"),
                    ("Parties terminées", "\(completedGames.count)"),
                    ("Joueurs", "\(filteredPlayerCount)"),
                    ("Total Yams", "\(totalYams)"),
                    ("Total primes Yams", "\(totalExtraYams)")
                ])
            } header: { Text("Général") }
            .headerProminence(.increased)
            
            // Section: Records
            Section {
                // Compute records outside of control-flow inside ViewBuilder
                let victories = victoriesFromEngine(
                    games: completedGames
                )
                let mostWins = victories.max(by: { $0.wins < $1.wins })
                let best = bestScoreRecord(games: completedGames)
                
                VStack(spacing: 0) {
                    recordRow(
                        title: "Meilleur score",
                        value: "\(best.value) — \(best.name)",
                        notation: best.notation
                    )
                    Divider()
                    recordRow(
                        title: "Victoires",
                        value: "\(mostWins?.wins ?? 0) — \(mostWins?.name ?? "—")"
                    )
                }
            } header: { Text("Records") }
            .headerProminence(.increased)
            
            // Section: Podium — Yams (top 3)
            Section {
                let top = Array(
                    yamsCounts(games: completedGames).prefix(3)
                )
                if top.isEmpty {
                    Text("Aucun Yams enregistré.").foregroundStyle(.secondary).padding(.horizontal)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(top.enumerated()), id: \.offset) { idx, e in
                            medalRow(rank: idx, color: colorByID[e.id] ?? .gray, name: e.name, value: "\(e.count)")
                            if idx < top.count - 1 { Divider() }
                        }
                    }
                }
            } header: { Text("Podium — Yams (top 3)") }
            .headerProminence(.increased)
            
            // Section: Podium — Primes de Yams (top 3)
            Section {
                let top = Array(
                    extraYamsCounts(games: completedGames).prefix(3)
                )
                if top.isEmpty {
                    Text("Aucune prime enregistrée.").foregroundStyle(.secondary).padding(.horizontal)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(top.enumerated()), id: \.offset) { idx, e in
                            medalRow(rank: idx, color: colorByID[e.id] ?? .gray, name: e.name, value: "\(e.count)")
                            if idx < top.count - 1 { Divider() }
                        }
                    }
                }
            } header: { Text("Podium — Primes de Yams (top 3)") }
            .headerProminence(.increased)

            // Section: Victoires par joueur (Bar Chart)
            Section {
                let victories = victoriesFromEngine(
                    games: completedGames
                )
                if victories.isEmpty {
                    Text("Aucune donnée de victoires par joueur.").foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(victories) { entry in
                            BarMark(
                                x: .value("Joueur", entry.name),
                                y: .value("Victoires", entry.wins)
                            )
                            .foregroundStyle(colorByID[entry.id] ?? .gray)
                            .annotation(position: .top, alignment: .center) {
                                Text("\(entry.wins)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 220)
                }
            } header: { Text("Victoires par joueur") }
            .headerProminence(.increased)
            
            // Section: Répartition des victoires (Pie Chart)
            Section {
                let victories = victoriesFromEngine(
                    games: completedGames
                )
                if victories.isEmpty {
                    Text("Aucune donnée de victoires par joueur.").foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(victories) { entry in
                            SectorMark(
                                angle: .value("Victoires", entry.wins),
                                innerRadius: .ratio(0.45),
                                angularInset: 1
                            )
                            // Categorie pour la légende
                            .foregroundStyle(by: .value("Joueur", entry.name))
                            .annotation(position: .overlay) {
                                Text("\(entry.wins)")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .shadow(radius: 1)
                            }
                        }
                    }
                    // Palette par joueur (nom -> couleur)
                    .chartForegroundStyleScale(
                        domain: victories.map { $0.name },
                        range: victories.map { colorByID[$0.id] ?? .gray }
                    )
                    // Forcer l’affichage et placer la légende
                    .chartLegend(position: .bottom, alignment: .center, spacing: 8)
                    .frame(height: 220)
                }
            } header: { Text("Répartition des victoires") }
            .headerProminence(.increased)
            
            // Section: Taux de victoire (en %)
            Section {
                let rates = winRates(games: completedGames)
                if rates.isEmpty {
                    Text("Pas encore de statistiques suffisantes.").foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(rates) { r in
                            BarMark(
                                x: .value("Joueur", r.name),
                                y: .value("Taux", r.rate)
                            )
                            .foregroundStyle(colorByID[r.id] ?? .gray)
                            .annotation(position: .top, alignment: .center) {
                                Text("\(Int(r.rate.rounded()))%")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 220)
                }
            } header: { Text("Taux de victoire (%)") }
            .headerProminence(.increased)
            
            // Section: Score moyen par joueur (Bar Chart)
            Section {
                let avgs = averagesFromEngine(games: completedGames)
                let avgsSorted = avgs.sorted { lhs, rhs in
                    if lhs.avg != rhs.avg { return lhs.avg > rhs.avg }
                    return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                }
                if avgsSorted.isEmpty {
                    Text("Pas encore assez de parties pour calculer des moyennes.").foregroundStyle(.secondary)
                } else {
                    Chart {
                        ForEach(avgsSorted) { entry in
                            BarMark(
                                x: .value("Joueur", entry.name),
                                y: .value("Moyenne", entry.avg)
                            )
                            .foregroundStyle(colorByID[entry.id] ?? .gray)
                            .annotation(position: .top, alignment: .center) {
                                Text("\(Int(entry.avg.rounded()))")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.primary)
                                    .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 220)
                }
            } header: { Text("Score moyen par joueur") }
            .headerProminence(.increased)
        }
        .listStyle(.insetGrouped)
    }
}

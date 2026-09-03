import Foundation
import UIKit

@MainActor
enum YamSheetPDFExportService {
    static func playersReport(
        players selectedPlayers: [Player],
        allPlayers: [Player],
        games: [Game]
    ) -> Data {
        let playersByID = Dictionary(
            uniqueKeysWithValues: allPlayers.map { ($0.id, $0) }
        )
        let statistics = Dictionary(
            uniqueKeysWithValues: StatsService.playerStats(
                allPlayers: allPlayers,
                games: games
            ).map { ($0.playerID, $0) }
        )
        let primes = StatsService.yamsPrimesByPlayer(games: games)

        return makePDF { writer in
            for player in selectedPlayers.sorted(by: playerSort) {
                let history = playerHistory(
                    for: player,
                    games: games,
                    playersByID: playersByID
                )
                let stats = statistics[player.id]
                let gamesPlayed = stats?.gamesPlayed ?? 0
                let wins = stats?.wins ?? 0
                let winRate = gamesPlayed > 0
                    ? Double(wins) / Double(gamesPlayed)
                    : 0

                writer.startPage(
                    title: player.displayName,
                    subtitle: "Fiche joueur YamSheet · \(formatted(Date()))",
                    accentColor: readablePrintColor(for: player)
                )
                if let email = player.email, !email.isEmpty {
                    writer.row("Adresse e-mail", email)
                }
                writer.section("Vue d’ensemble")
                writer.metricCards([
                    ("Parties", "\(gamesPlayed)"),
                    ("Victoires", "\(wins)"),
                    ("Score moyen", decimal(stats?.avgScore ?? 0)),
                    ("Record", "\(stats?.bestScore ?? 0)"),
                    ("Yams", "\(stats?.yamsCount ?? 0)"),
                    ("Primes Yams", "\(primes[player.id] ?? 0)")
                ])
                writer.progressBar(
                    label: "Taux de victoire",
                    value: winRate,
                    displayedValue: percentage(winRate)
                )
                writer.progressBar(
                    label: "Parties avec au moins un Yams",
                    value: stats?.yamsRate ?? 0,
                    displayedValue: percentage(stats?.yamsRate ?? 0)
                )

                writer.section("Évolution des scores")
                writer.lineChart(
                    values: history.reversed().map(\.playerScore),
                    emptyMessage: "Aucune partie terminée"
                )

                writer.table(
                    sectionTitle: "Historique détaillé",
                    headers: ["Partie", "Date", "Adversaires", "Scores"],
                    rows: history.map {
                        [
                            $0.gameName,
                            $0.date,
                            $0.opponents,
                            $0.scores
                        ]
                    },
                    columnFractions: [0.23, 0.16, 0.24, 0.37],
                    emptyMessage: "Aucune partie terminée"
                )
            }
        }
    }

    static func gamesReport(
        games selectedGames: [Game],
        allGames: [Game],
        players: [Player]
    ) -> Data {
        let playersByID = Dictionary(
            uniqueKeysWithValues: players.map { ($0.id, $0) }
        )

        return makePDF(
            pageBounds: CGRect(x: 0, y: 0, width: 842, height: 595)
        ) { writer in
            for game in selectedGames.sorted(by: { $0.createdAt > $1.createdAt }) {
                let rankedScorecards = game.scorecards.sorted {
                    StatsService.total(for: $0, game: game)
                        > StatsService.total(for: $1, game: game)
                }
                let yamsCount = game.scorecards.reduce(0) {
                    $0 + StatsService.yamsCount(for: $1)
                }
                let primesCount = game.scorecards.reduce(0) {
                    partial, scorecard in
                    partial + (0..<max(scorecard.columns, 1)).reduce(0) {
                        $0 + scorecard.extraYamsAwardsCount(col: $1)
                    }
                }

                writer.startPage(
                    title: game.name.isEmpty ? "Partie sans nom" : game.name,
                    subtitle: "Feuille de score YamSheet",
                    compact: true
                )
                writer.compactGameDetails(
                    items: [
                        ("Date", formatted(game.createdAt)),
                        ("État", statusLabel(game.statusOrDefault)),
                        ("Notation", game.notation.name),
                        ("Yams réalisés", "\(yamsCount)"),
                        ("Primes activées", "\(primesCount)")
                    ],
                    record: recordSummary(
                        for: game,
                        allGames: allGames,
                        playersByID: playersByID
                    ),
                    comment: game.comment
                )

                let playerColors = rankedScorecards.map {
                    printColor(
                        for: playersByID[$0.playerID]
                    )
                }
                let columnFractions = gamePDFColumnFractions(
                    playerCount: rankedScorecards.count
                )
                writer.compactTable(
                    sectionTitle: "Récapitulatif",
                    headers: [""] + rankedScorecards.map {
                        playerName($0.playerID, playersByID)
                    },
                    rows: [
                        ["Rang"] + rankedScorecards.indices.map {
                            "\($0 + 1)"
                        },
                        ["Score"] + rankedScorecards.map {
                            "\(StatsService.total(for: $0, game: game))"
                        },
                        ["Yams"] + rankedScorecards.map {
                            "\(StatsService.yamsCount(for: $0))"
                        },
                        ["Primes"] + rankedScorecards.map {
                            "\(totalPrimes(for: $0))"
                        }
                    ],
                    columnFractions: columnFractions,
                    headerColors: [nil] + playerColors.map(Optional.some),
                    emptyMessage: "Aucun score"
                )

                writer.compactTable(
                    sectionTitle: "Tableau des scores",
                    headers: ["Catégorie"] + rankedScorecards.map {
                        playerName($0.playerID, playersByID)
                    },
                    rows: scoreTableRows(
                        for: rankedScorecards,
                        game: game
                    ),
                    columnFractions: columnFractions,
                    headerColors: [nil] + playerColors.map(Optional.some),
                    emptyMessage: "Aucun score"
                )
            }
        }
    }

    private static func playerHistory(
        for player: Player,
        games: [Game],
        playersByID: [UUID: Player]
    ) -> [PlayerPDFHistoryRow] {
        games
            .filter {
                $0.statusOrDefault == .completed
                    && $0.scorecards.contains {
                        $0.playerID == player.id
                    }
            }
            .sorted {
                ($0.endedAt ?? $0.createdAt)
                    > ($1.endedAt ?? $1.createdAt)
            }
            .compactMap { game in
                guard let playerScorecard = game.scorecards.first(where: {
                    $0.playerID == player.id
                }) else {
                    return nil
                }

                let opponents = game.participantIDs
                    .filter { $0 != player.id }
                    .map { playerName($0, playersByID) }
                let scores = game.scorecards
                    .sorted {
                        StatsService.total(for: $0, game: game)
                            > StatsService.total(for: $1, game: game)
                    }
                    .map {
                        "\(playerName($0.playerID, playersByID)) : \(StatsService.total(for: $0, game: game))"
                    }

                return PlayerPDFHistoryRow(
                    gameName: game.name.isEmpty
                        ? "Partie sans nom"
                        : game.name,
                    date: shortDate(game.endedAt ?? game.createdAt),
                    opponents: opponents.isEmpty
                        ? "Aucun"
                        : opponents.joined(separator: ", "),
                    scores: scores.joined(separator: " · "),
                    playerScore: StatsService.total(
                        for: playerScorecard,
                        game: game
                    )
                )
            }
    }

    private static func scoreTableRows(
        for scorecards: [Scorecard],
        game: Game
    ) -> [[String]] {
        var rows = scoreCategories(for: game).map { category in
            [category.label] + scorecards.map {
                scoreValue(category.values($0))
            }
        }
        if game.notation.upperSectionIsEnabled {
            rows.append(
                ["Total section haute"] + scorecards.map {
                    "\(StatsEngine.upperTotal(sc: $0, game: game, col: 0))"
                }
            )
        }
        if game.notation.middleSectionIsEnabled {
            rows.append(
                ["Total section milieu"] + scorecards.map {
                    "\(StatsEngine.middleTotal(sc: $0, game: game, col: 0))"
                }
            )
        }
        if game.notation.isBottomFieldEnabled(.yams) {
            rows.append(
                ["Yams réalisés"] + scorecards.map {
                    "\(StatsService.yamsCount(for: $0))"
                }
            )
            rows.append(
                ["Primes de Yams"] + scorecards.map {
                    "\(totalPrimes(for: $0))"
                }
            )
        }
        rows.append(
            ["TOTAL GÉNÉRAL"] + scorecards.map {
                "\(StatsService.total(for: $0, game: game))"
            }
        )
        return rows
    }

    private static func scoreCategories(
        for game: Game
    ) -> [(label: String, values: (Scorecard) -> [Int])] {
        var rows: [(String, (Scorecard) -> [Int])] = []
        if game.notation.upperSectionIsEnabled {
            rows += [
                ("As", { $0.ones }),
                ("Deux", { $0.twos }),
                ("Trois", { $0.threes }),
                ("Quatre", { $0.fours }),
                ("Cinq", { $0.fives }),
                ("Six", { $0.sixes })
            ]
        }
        if game.notation.middleSectionIsEnabled {
            rows += [
                ("Max", { $0.maxVals }),
                ("Min", { $0.minVals })
            ]
        }
        if game.notation.isBottomFieldEnabled(.brelan) {
            rows.append(("Brelan", { $0.brelan }))
        }
        if game.notation.isBottomFieldEnabled(.chance) {
            rows.append(("Chance", { $0.chance }))
        }
        if game.notation.isBottomFieldEnabled(.full) {
            rows.append(("Full", { $0.full }))
        }
        if game.notation.isBottomFieldEnabled(.suite) {
            rows.append(("Grande suite", { $0.suite }))
        }
        if game.notation.isBottomFieldEnabled(.petiteSuite) {
            rows.append(("Petite suite", { $0.petiteSuite }))
        }
        if game.notation.isBottomFieldEnabled(.carre) {
            rows.append(("Carré", { $0.carre }))
        }
        if game.notation.isBottomFieldEnabled(.yams) {
            rows.append(("Yams", { $0.yams }))
        }
        return rows
    }

    private static func scoreValue(_ values: [Int]) -> String {
        guard let value = values.first, value >= 0 else { return "—" }
        return "\(value)"
    }

    private static func totalPrimes(for scorecard: Scorecard) -> Int {
        (0..<max(scorecard.columns, 1)).reduce(0) {
            $0 + scorecard.extraYamsAwardsCount(col: $1)
        }
    }

    private static func recordSummary(
        for game: Game,
        allGames: [Game],
        playersByID: [UUID: Player]
    ) -> String {
        guard game.statusOrDefault == .completed,
              let best = bestScore(in: game) else {
            return "Non applicable"
        }

        let gameDate = game.endedAt ?? game.createdAt
        let previousBest = allGames
            .filter {
                $0.id != game.id
                    && $0.statusOrDefault == .completed
                    && $0.notationData == game.notationData
                    && ($0.endedAt ?? $0.createdAt) < gameDate
            }
            .compactMap { bestScore(in: $0) }
            .map(\.score)
            .max()

        let recordHolders = game.scorecards
            .filter {
                StatsService.total(for: $0, game: game) == best.score
            }
            .map { playerName($0.playerID, playersByID) }
            .joined(separator: ", ")

        guard let previousBest else {
            return "Oui — \(recordHolders), \(best.score) points (premier record de cette notation)"
        }
        guard best.score > previousBest else {
            return "Non — \(best.score) points, record précédent \(previousBest)"
        }
        return "Oui — \(recordHolders), \(best.score) points (ancien record \(previousBest))"
    }

    private static func bestScore(in game: Game) -> (score: Int, playerID: UUID)? {
        game.scorecards
            .map {
                (
                    score: StatsService.total(for: $0, game: game),
                    playerID: $0.playerID
                )
            }
            .max { $0.score < $1.score }
    }

    private static func playerName(
        _ id: UUID,
        _ playersByID: [UUID: Player]
    ) -> String {
        playersByID[id]?.displayName ?? "Joueur inconnu"
    }

    private static func makePDF(
        pageBounds: CGRect = CGRect(
            x: 0,
            y: 0,
            width: 595,
            height: 842
        ),
        content: (YamSheetPDFWriter) -> Void
    ) -> Data {
        let renderer = UIGraphicsPDFRenderer(bounds: pageBounds)
        return renderer.pdfData { context in
            content(
                YamSheetPDFWriter(
                    context: context,
                    pageBounds: pageBounds
                )
            )
        }
    }

    private static func gamePDFColumnFractions(
        playerCount: Int
    ) -> [CGFloat] {
        guard playerCount > 0 else { return [1] }
        let labelFraction: CGFloat = playerCount <= 4 ? 0.24 : 0.18
        let playerFraction = (1 - labelFraction) / CGFloat(playerCount)
        return [labelFraction]
            + Array(repeating: playerFraction, count: playerCount)
    }

    private static func printColor(for player: Player?) -> UIColor {
        guard let player else { return .systemGray }
        return UIColor(player.color)
    }

    private static func readablePrintColor(for player: Player) -> UIColor {
        let color = printColor(for: player)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard color.getRed(
            &red,
            green: &green,
            blue: &blue,
            alpha: &alpha
        ) else {
            return color
        }
        let luminance = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
        guard luminance > 0.55 else {
            return UIColor(red: red, green: green, blue: blue, alpha: 1)
        }
        let factor = 0.55 / luminance
        return UIColor(
            red: red * factor,
            green: green * factor,
            blue: blue * factor,
            alpha: 1
        )
    }

    private static func playerSort(_ lhs: Player, _ rhs: Player) -> Bool {
        lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
            == .orderedAscending
    }

    private static func statusLabel(_ status: GameStatus) -> String {
        switch status {
        case .inProgress: return "En cours"
        case .paused: return "En pause"
        case .completed: return "Terminée"
        }
    }

    private static func formatted(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: "fr_FR"))
                .day()
                .month(.wide)
                .year()
                .hour()
                .minute()
        )
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(
            .dateTime
                .locale(Locale(identifier: "fr_FR"))
                .day(.twoDigits)
                .month(.twoDigits)
                .year()
        )
    }

    private static func decimal(_ value: Double) -> String {
        value.formatted(
            .number
                .locale(Locale(identifier: "fr_FR"))
                .precision(.fractionLength(1))
        )
    }

    private static func percentage(_ value: Double) -> String {
        value.formatted(
            .percent
                .locale(Locale(identifier: "fr_FR"))
                .precision(.fractionLength(0))
        )
    }
}

private struct PlayerPDFHistoryRow {
    let gameName: String
    let date: String
    let opponents: String
    let scores: String
    let playerScore: Int
}

private final class YamSheetPDFWriter {
    private let context: UIGraphicsPDFRendererContext
    private let pageBounds: CGRect
    private let margin: CGFloat
    private var accent = UIColor(
        red: 0.05,
        green: 0.48,
        blue: 0.39,
        alpha: 1
    )
    private let textColor = UIColor(white: 0.10, alpha: 1)
    private let secondaryTextColor = UIColor(white: 0.48, alpha: 1)
    private let chartBackgroundColor = UIColor(white: 0.96, alpha: 1)
    private let progressTrackColor = UIColor(white: 0.88, alpha: 1)
    private let gridColor = UIColor(white: 0.80, alpha: 1)
    private var cursorY: CGFloat = 44

    init(context: UIGraphicsPDFRendererContext, pageBounds: CGRect) {
        self.context = context
        self.pageBounds = pageBounds
        margin = pageBounds.width > pageBounds.height ? 24 : 44
    }

    func startPage(
        title: String,
        subtitle: String,
        compact: Bool = false,
        accentColor: UIColor? = nil
    ) {
        if let accentColor {
            accent = accentColor
        }
        context.beginPage()
        cursorY = margin
        draw(
            title,
            font: .boldSystemFont(ofSize: compact ? 19 : 24),
            color: textColor,
            spacingAfter: compact ? 2 : 5
        )
        draw(
            subtitle,
            font: .systemFont(ofSize: compact ? 8 : 10),
            color: secondaryTextColor,
            spacingAfter: compact ? 8 : 20
        )
    }

    func compactGameDetails(
        items: [(label: String, value: String)],
        record: String,
        comment: String
    ) {
        guard !items.isEmpty else { return }
        let availableWidth = pageBounds.width - (2 * margin)
        let gap: CGFloat = 5
        let itemWidth = (
            availableWidth - CGFloat(items.count - 1) * gap
        ) / CGFloat(items.count)
        let itemHeight: CGFloat = 28
        ensureSpace(itemHeight)

        for (index, item) in items.enumerated() {
            let rect = CGRect(
                x: margin + CGFloat(index) * (itemWidth + gap),
                y: cursorY,
                width: itemWidth,
                height: itemHeight
            )
            context.cgContext.setFillColor(
                accent.withAlphaComponent(0.06).cgColor
            )
            context.cgContext.addPath(
                UIBezierPath(
                    roundedRect: rect,
                    cornerRadius: 5
                ).cgPath
            )
            context.cgContext.fillPath()
            drawText(
                item.label,
                in: CGRect(
                    x: rect.minX + 6,
                    y: rect.minY + 3,
                    width: rect.width - 12,
                    height: 9
                ),
                font: .systemFont(ofSize: 6.5, weight: .semibold),
                color: secondaryTextColor,
                lineBreakMode: .byTruncatingTail
            )
            drawText(
                item.value,
                in: CGRect(
                    x: rect.minX + 6,
                    y: rect.minY + 13,
                    width: rect.width - 12,
                    height: 11
                ),
                font: .systemFont(ofSize: 8, weight: .semibold),
                color: textColor,
                lineBreakMode: .byTruncatingTail
            )
        }
        cursorY += itemHeight + 4
        compactLabeledLine("Record", record)

        let cleanedComment = comment
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanedComment.isEmpty {
            compactLabeledLine("Commentaire", cleanedComment)
        }
    }

    func compactTable(
        sectionTitle: String,
        headers: [String],
        rows: [[String]],
        columnFractions: [CGFloat],
        headerColors: [UIColor?],
        emptyMessage: String
    ) {
        guard !rows.isEmpty else {
            compactSection(sectionTitle)
            paragraph(emptyMessage)
            return
        }
        guard headers.count == columnFractions.count,
              headerColors.count == headers.count else {
            return
        }

        compactSection(sectionTitle)
        let totalWidth = pageBounds.width - (2 * margin)
        let widths = columnFractions.map { totalWidth * $0 }
        let fontSize = max(
            5.6,
            min(7.2, 8.2 - CGFloat(headers.count) * 0.16)
        )
        drawCompactTableRow(
            headers,
            widths: widths,
            height: 17,
            isHeader: true,
            headerColors: headerColors,
            fontSize: fontSize
        )
        for row in rows where row.count == headers.count {
            drawCompactTableRow(
                row,
                widths: widths,
                height: 14,
                isHeader: false,
                headerColors: [],
                fontSize: fontSize
            )
        }
    }

    private func compactSection(_ text: String) {
        cursorY += 4
        drawText(
            text,
            in: CGRect(
                x: margin,
                y: cursorY,
                width: pageBounds.width - (2 * margin),
                height: 14
            ),
            font: .boldSystemFont(ofSize: 10.5),
            color: accent
        )
        cursorY += 17
    }

    private func compactLabeledLine(_ label: String, _ value: String) {
        let availableWidth = pageBounds.width - (2 * margin)
        let labelWidth: CGFloat = 72
        drawText(
            label,
            in: CGRect(
                x: margin,
                y: cursorY,
                width: labelWidth,
                height: 13
            ),
            font: .systemFont(ofSize: 7.4, weight: .semibold),
            color: textColor
        )
        drawText(
            value,
            in: CGRect(
                x: margin + labelWidth,
                y: cursorY,
                width: availableWidth - labelWidth,
                height: 13
            ),
            font: .systemFont(ofSize: 7.4),
            color: textColor,
            lineBreakMode: .byTruncatingTail
        )
        cursorY += 14
    }

    func section(_ text: String) {
        ensureSpace(42)
        cursorY += 12
        draw(
            text,
            font: .boldSystemFont(ofSize: 14),
            color: accent,
            spacingAfter: 8
        )
    }

    func spacer(_ height: CGFloat) {
        ensureSpace(height)
        cursorY += height
    }

    func row(_ label: String, _ value: String) {
        let availableWidth = pageBounds.width - (2 * margin)
        let labelWidth = availableWidth * 0.34
        let valueX = margin + labelWidth + 12
        let valueWidth = availableWidth - labelWidth - 12
        let font = UIFont.systemFont(ofSize: 10.5)
        let height = max(
            18,
            max(
                textHeight(label, font: font, width: labelWidth),
                textHeight(value, font: font, width: valueWidth)
            )
        )
        ensureSpace(height + 6)

        drawText(
            label,
            in: CGRect(x: margin, y: cursorY, width: labelWidth, height: height),
            font: .systemFont(ofSize: 10.5, weight: .semibold),
            color: textColor
        )
        drawText(
            value,
            in: CGRect(x: valueX, y: cursorY, width: valueWidth, height: height),
            font: font,
            color: textColor
        )
        cursorY += height + 6
    }

    func metricCards(_ metrics: [(label: String, value: String)]) {
        let columns = 3
        let gap: CGFloat = 8
        let availableWidth = pageBounds.width - (2 * margin)
        let cardWidth = (
            availableWidth - (CGFloat(columns - 1) * gap)
        ) / CGFloat(columns)
        let cardHeight: CGFloat = 58
        let rows = Int(ceil(Double(metrics.count) / Double(columns)))
        ensureSpace(CGFloat(rows) * (cardHeight + gap))

        for (index, metric) in metrics.enumerated() {
            let column = index % columns
            let row = index / columns
            let rect = CGRect(
                x: margin + CGFloat(column) * (cardWidth + gap),
                y: cursorY + CGFloat(row) * (cardHeight + gap),
                width: cardWidth,
                height: cardHeight
            )
            context.cgContext.setFillColor(
                accent.withAlphaComponent(0.08).cgColor
            )
            context.cgContext.addPath(
                UIBezierPath(
                    roundedRect: rect,
                    cornerRadius: 10
                ).cgPath
            )
            context.cgContext.fillPath()

            drawText(
                metric.value,
                in: CGRect(
                    x: rect.minX + 10,
                    y: rect.minY + 9,
                    width: rect.width - 20,
                    height: 25
                ),
                font: .boldSystemFont(ofSize: 18),
                color: accent
            )
            drawText(
                metric.label,
                in: CGRect(
                    x: rect.minX + 10,
                    y: rect.minY + 34,
                    width: rect.width - 20,
                    height: 18
                ),
                font: .systemFont(ofSize: 8.5),
                color: secondaryTextColor
            )
        }
        cursorY += CGFloat(rows) * (cardHeight + gap)
    }

    func progressBar(
        label: String,
        value: Double,
        displayedValue: String
    ) {
        ensureSpace(38)
        let width = pageBounds.width - (2 * margin)
        drawText(
            label,
            in: CGRect(x: margin, y: cursorY, width: width - 60, height: 16),
            font: .systemFont(ofSize: 9.5, weight: .semibold),
            color: textColor
        )
        drawText(
            displayedValue,
            in: CGRect(
                x: pageBounds.width - margin - 60,
                y: cursorY,
                width: 60,
                height: 16
            ),
            font: .boldSystemFont(ofSize: 9.5),
            color: accent,
            alignment: .right
        )
        let track = CGRect(
            x: margin,
            y: cursorY + 19,
            width: width,
            height: 7
        )
        context.cgContext.setFillColor(
            progressTrackColor.cgColor
        )
        context.cgContext.fill(track)
        context.cgContext.setFillColor(accent.cgColor)
        context.cgContext.fill(
            CGRect(
                x: track.minX,
                y: track.minY,
                width: track.width * CGFloat(min(max(value, 0), 1)),
                height: track.height
            )
        )
        cursorY += 36
    }

    func lineChart(values: [Int], emptyMessage: String) {
        guard !values.isEmpty else {
            paragraph(emptyMessage)
            return
        }

        let height: CGFloat = 140
        ensureSpace(height + 22)
        let chart = CGRect(
            x: margin,
            y: cursorY,
            width: pageBounds.width - (2 * margin),
            height: height
        )
        context.cgContext.setFillColor(chartBackgroundColor.cgColor)
        context.cgContext.fill(chart)

        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? minValue
        let range = max(maxValue - minValue, 1)
        let inset: CGFloat = 18
        let plot = chart.insetBy(dx: inset, dy: inset)
        let stepX = values.count > 1
            ? plot.width / CGFloat(values.count - 1)
            : 0
        func xPosition(for index: Int) -> CGFloat {
            guard values.count > 1 else { return plot.midX }
            return plot.minX + CGFloat(index) * stepX
        }
        func yPosition(for value: Int) -> CGFloat {
            guard maxValue != minValue else { return plot.midY }
            let ratio = CGFloat(value - minValue) / CGFloat(range)
            return plot.maxY - (ratio * plot.height)
        }

        context.cgContext.setStrokeColor(accent.cgColor)
        context.cgContext.setLineWidth(2)
        for (index, value) in values.enumerated() {
            let x = xPosition(for: index)
            let y = yPosition(for: value)
            if index == 0 {
                context.cgContext.move(to: CGPoint(x: x, y: y))
            } else {
                context.cgContext.addLine(to: CGPoint(x: x, y: y))
            }
        }
        context.cgContext.strokePath()

        context.cgContext.setFillColor(accent.cgColor)
        for (index, value) in values.enumerated() {
            let x = xPosition(for: index)
            let y = yPosition(for: value)
            context.cgContext.fillEllipse(
                in: CGRect(x: x - 2.5, y: y - 2.5, width: 5, height: 5)
            )
        }

        if minValue == maxValue {
            drawText(
                "\(maxValue)",
                in: CGRect(
                    x: chart.minX + 3,
                    y: chart.midY - 7,
                    width: 40,
                    height: 14
                ),
                font: .systemFont(ofSize: 7.5),
                color: secondaryTextColor
            )
        } else {
            drawText(
                "\(maxValue)",
                in: CGRect(
                    x: chart.minX + 3,
                    y: chart.minY + 2,
                    width: 40,
                    height: 14
                ),
                font: .systemFont(ofSize: 7.5),
                color: secondaryTextColor
            )
            drawText(
                "\(minValue)",
                in: CGRect(
                    x: chart.minX + 3,
                    y: chart.maxY - 14,
                    width: 40,
                    height: 12
                ),
                font: .systemFont(ofSize: 7.5),
                color: secondaryTextColor
            )
        }
        cursorY += height + 8
    }

    func table(
        sectionTitle: String? = nil,
        headers: [String],
        rows: [[String]],
        columnFractions: [CGFloat],
        emptyMessage: String
    ) {
        guard !rows.isEmpty else {
            if let sectionTitle {
                section(sectionTitle)
            }
            paragraph(emptyMessage)
            return
        }
        guard headers.count == columnFractions.count else { return }

        let totalWidth = pageBounds.width - (2 * margin)
        let widths = columnFractions.map { totalWidth * $0 }
        let headerHeight = tableRowHeight(
            headers,
            widths: widths,
            font: .systemFont(ofSize: 8.5, weight: .semibold)
        )
        let rowHeights = rows.map {
            tableRowHeight(
                $0,
                widths: widths,
                font: .systemFont(ofSize: 8.2)
            )
        }
        let titleHeight: CGFloat = sectionTitle == nil ? 0 : 42
        let totalHeight = titleHeight
            + headerHeight
            + rowHeights.reduce(0, +)
        let usablePageHeight = pageBounds.height - (2 * margin)
        if totalHeight <= usablePageHeight {
            ensureSpace(totalHeight)
        } else {
            ensureSpace(titleHeight + headerHeight + 24)
        }
        if let sectionTitle {
            section(sectionTitle)
        }
        drawTableRow(
            headers,
            widths: widths,
            height: headerHeight,
            isHeader: true
        )

        for (row, height) in zip(rows, rowHeights)
            where row.count == headers.count {
            if ensureSpace(height + headerHeight) {
                drawTableRow(
                    headers,
                    widths: widths,
                    height: headerHeight,
                    isHeader: true
                )
            }
            drawTableRow(
                row,
                widths: widths,
                height: height,
                isHeader: false
            )
        }
    }

    func paragraph(_ text: String) {
        let font = UIFont.systemFont(ofSize: 10)
        let width = pageBounds.width - (2 * margin)
        let height = textHeight(text, font: font, width: width)
        ensureSpace(min(height, pageBounds.height - (2 * margin)))
        drawText(
            text,
            in: CGRect(x: margin, y: cursorY, width: width, height: height),
            font: font,
            color: textColor
        )
        cursorY += height + 8
    }

    private func tableRowHeight(
        _ values: [String],
        widths: [CGFloat],
        font: UIFont
    ) -> CGFloat {
        max(
            24,
            zip(values, widths)
                .map {
                    textHeight(
                        $0.0,
                        font: font,
                        width: max($0.1 - 10, 10)
                    ) + 10
                }
                .max() ?? 24
        )
    }

    private func drawTableRow(
        _ values: [String],
        widths: [CGFloat],
        height: CGFloat,
        isHeader: Bool
    ) {
        var x = margin
        for (index, value) in values.enumerated() {
            let rect = CGRect(
                x: x,
                y: cursorY,
                width: widths[index],
                height: height
            )
            context.cgContext.setFillColor(
                (
                    isHeader
                        ? accent.withAlphaComponent(0.16)
                        : UIColor.white
                ).cgColor
            )
            context.cgContext.fill(rect)
            context.cgContext.setStrokeColor(gridColor.cgColor)
            context.cgContext.setLineWidth(0.5)
            context.cgContext.stroke(rect)
            drawText(
                value,
                in: rect.insetBy(dx: 5, dy: 5),
                font: isHeader
                    ? .systemFont(ofSize: 8.5, weight: .semibold)
                    : .systemFont(ofSize: 8.2),
                color: textColor
            )
            x += widths[index]
        }
        cursorY += height
    }

    private func drawCompactTableRow(
        _ values: [String],
        widths: [CGFloat],
        height: CGFloat,
        isHeader: Bool,
        headerColors: [UIColor?],
        fontSize: CGFloat
    ) {
        var x = margin
        for (index, value) in values.enumerated() {
            let rect = CGRect(
                x: x,
                y: cursorY,
                width: widths[index],
                height: height
            )
            let playerColor = isHeader ? headerColors[index] : nil
            context.cgContext.setFillColor(
                (
                    playerColor?.withAlphaComponent(0.18)
                        ?? (
                            isHeader
                                ? accent.withAlphaComponent(0.14)
                                : UIColor.white
                        )
                ).cgColor
            )
            context.cgContext.fill(rect)
            if let playerColor {
                context.cgContext.setFillColor(
                    playerColor.withAlphaComponent(0.95).cgColor
                )
                context.cgContext.fill(
                    CGRect(
                        x: rect.minX,
                        y: rect.minY,
                        width: rect.width,
                        height: 2
                    )
                )
            }
            context.cgContext.setStrokeColor(gridColor.cgColor)
            context.cgContext.setLineWidth(0.4)
            context.cgContext.stroke(rect)
            drawText(
                value,
                in: rect.insetBy(dx: 3, dy: 2),
                font: .systemFont(
                    ofSize: fontSize,
                    weight: isHeader ? .semibold : .regular
                ),
                color: textColor,
                alignment: index == 0 ? .left : .center,
                lineBreakMode: .byTruncatingTail
            )
            x += widths[index]
        }
        cursorY += height
    }

    private func draw(
        _ text: String,
        font: UIFont,
        color: UIColor,
        spacingAfter: CGFloat
    ) {
        let width = pageBounds.width - (2 * margin)
        let height = textHeight(text, font: font, width: width)
        ensureSpace(height + spacingAfter)
        drawText(
            text,
            in: CGRect(x: margin, y: cursorY, width: width, height: height),
            font: font,
            color: color
        )
        cursorY += height + spacingAfter
    }

    @discardableResult
    private func ensureSpace(_ requiredHeight: CGFloat) -> Bool {
        guard cursorY + requiredHeight > pageBounds.height - margin else {
            return false
        }
        context.beginPage()
        cursorY = margin
        return true
    }

    private func textHeight(
        _ text: String,
        font: UIFont,
        width: CGFloat
    ) -> CGFloat {
        ceil(
            (text as NSString).boundingRect(
                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: font],
                context: nil
            ).height
        )
    }

    private func drawText(
        _ text: String,
        in rect: CGRect,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment = .left,
        lineBreakMode: NSLineBreakMode = .byWordWrapping
    ) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        paragraphStyle.lineBreakMode = lineBreakMode
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .foregroundColor: color,
                .paragraphStyle: paragraphStyle
            ],
            context: nil
        )
    }
}

import Foundation
import SwiftData

struct YamSheetImportResult {
    var playersAdded = 0
    var playersSkipped = 0
    var gamesAdded = 0
    var gamesSkipped = 0
    var notationsAdded = 0
    var notationsSkipped = 0
    var settingsApplied = false

    var summary: String {
        var lines = [
            "\(playersAdded) joueur(s) ajouté(s), \(playersSkipped) fiche(s) locale(s) conservée(s)",
            "\(gamesAdded) partie(s) ajoutée(s), \(gamesSkipped) partie(s) locale(s) conservée(s)"
        ]

        if notationsAdded > 0 || notationsSkipped > 0 {
            lines.append(
                "\(notationsAdded) notation(s) ajoutée(s), \(notationsSkipped) déjà présente(s)"
            )
        }
        if settingsApplied {
            lines.append("Paramètres et préférences appliqués")
        }
        return lines.joined(separator: "\n")
    }
}

@MainActor
enum YamSheetBackupService {
    private static let tintLightKey = "tintLight"
    private static let tintDarkKey = "tintDark"
    private static let columnRecenterModeKey = "columnRecenterMode"

    static func makeArchive(
        scope: YamSheetBackupScope,
        players: [Player],
        games: [Game],
        notations: [Notation],
        settings: AppSettings?,
        selectedPlayerIDs: Set<UUID>? = nil
    ) throws -> YamSheetBackupArchive {
        let selectedPlayerIDs = selectedPlayerIDs
            ?? Set(players.map(\.id))
        let exportedGames: [Game]
        switch scope {
        case .players:
            exportedGames = games.filter { game in
                !Set(game.participantIDs)
                    .intersection(selectedPlayerIDs)
                    .isEmpty
            }
        case .games, .full:
            exportedGames = games
        case .notations:
            exportedGames = []
        }
        let includedPlayerIDs: Set<UUID>

        switch scope {
        case .players:
            includedPlayerIDs = selectedPlayerIDs
                .union(referencedPlayerIDs(in: exportedGames))
        case .full:
            includedPlayerIDs = Set(players.map(\.id))
                .union(referencedPlayerIDs(in: exportedGames))
        case .games:
            includedPlayerIDs = referencedPlayerIDs(in: exportedGames)
        case .notations:
            includedPlayerIDs = []
        }

        var playerRecords = players
            .filter { includedPlayerIDs.contains($0.id) }
            .map(YamSheetPlayerRecord.init)

        let representedPlayerIDs = Set(playerRecords.map(\.id))
        for missingID in includedPlayerIDs.subtracting(representedPlayerIDs) {
            playerRecords.append(.placeholder(id: missingID))
        }
        playerRecords.sort {
            $0.nickname.localizedCaseInsensitiveCompare($1.nickname) == .orderedAscending
        }

        let statistics: [YamSheetPlayerStatisticsRecord]
        if scope == .players || scope == .full {
            statistics = makeStatistics(
                for: scope == .players
                    ? playerRecords.filter { selectedPlayerIDs.contains($0.id) }
                    : playerRecords,
                currentPlayers: players,
                games: games
            )
        } else {
            statistics = []
        }

        let archive = YamSheetBackupArchive(
            metadata: YamSheetBackupMetadata(
                magic: YamSheetBackupMetadata.expectedMagic,
                formatVersion: YamSheetBackupMetadata.currentFormatVersion,
                archiveID: UUID(),
                exportedAt: Date(),
                sourceAppVersion: appVersion,
                sourceBuild: appBuild,
                scope: scope
            ),
            players: playerRecords,
            playerStatistics: statistics,
            games: exportedGames
                .map(YamSheetGameRecord.init)
                .sorted { $0.createdAt > $1.createdAt },
            notations: scope == .full || scope == .notations
                ? notations.map(YamSheetNotationRecord.init)
                    .sorted {
                        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                : [],
            settings: scope == .full ? settings.map(YamSheetSettingsRecord.init) : nil,
            interfacePreferences: scope == .full ? currentInterfacePreferences : nil
        )

        try YamSheetBackupValidator.validate(archive)
        return archive
    }

    static func importArchive(
        _ archive: YamSheetBackupArchive,
        into context: ModelContext
    ) throws -> YamSheetImportResult {
        try YamSheetBackupValidator.validate(archive)

        var result = YamSheetImportResult()

        do {
            var knownPlayers = try context.fetch(FetchDescriptor<Player>())
            var playersByID = Dictionary(
                uniqueKeysWithValues: knownPlayers.map { ($0.id, $0) }
            )
            var resolvedPlayerIDs: [UUID: UUID] = [:]

            for record in archive.players {
                if let existing = playersByID[record.id] {
                    resolvedPlayerIDs[record.id] = existing.id
                    result.playersSkipped += 1
                    continue
                }

                if let existing = matchingPlayer(
                    for: record,
                    among: knownPlayers
                ) {
                    resolvedPlayerIDs[record.id] = existing.id
                    result.playersSkipped += 1
                    continue
                }

                let importedPlayer = record.makePlayer()
                context.insert(importedPlayer)
                knownPlayers.append(importedPlayer)
                playersByID[importedPlayer.id] = importedPlayer
                resolvedPlayerIDs[record.id] = importedPlayer.id
                result.playersAdded += 1
            }

            var existingNotations = try context.fetch(FetchDescriptor<Notation>())
            var existingNotationRecords = Set(
                existingNotations.map {
                    YamSheetNotationRecord($0).duplicateDetectionRecord
                }
            )

            for record in archive.notations {
                let duplicateDetectionRecord = record.duplicateDetectionRecord
                if existingNotationRecords.contains(duplicateDetectionRecord) {
                    result.notationsSkipped += 1
                    continue
                }

                let importedNotation = record.makeNotation(
                    legacyCreationDate: NotationCreationDatePolicy.fallback(
                        sourceAppVersion: archive.metadata.sourceAppVersion,
                        exportedAt: archive.metadata.exportedAt
                    )
                )
                resolveNotationNameConflict(
                    for: importedNotation,
                    sourceName: record.name,
                    among: existingNotations
                )
                context.insert(importedNotation)
                existingNotations.append(importedNotation)
                existingNotationRecords.insert(duplicateDetectionRecord)
                result.notationsAdded += 1
            }

            let existingGames = try context.fetch(FetchDescriptor<Game>())
            var existingGameIDs = Set(existingGames.map(\.id))
            let settingsForGame: AppSettings?
            if !archive.games.isEmpty || archive.settings != nil {
                settingsForGame = try settingsForImport(
                    archiveSettings: archive.settings,
                    context: context
                )
            } else {
                settingsForGame = nil
            }

            for sourceRecord in archive.games {
                if existingGameIDs.contains(sourceRecord.id) {
                    result.gamesSkipped += 1
                    continue
                }

                guard let settingsForGame else {
                    throw YamSheetBackupError.invalidContent(
                        "les paramètres nécessaires aux parties sont manquants"
                    )
                }
                let record = sourceRecord.remappingPlayers(
                    using: resolvedPlayerIDs
                )
                context.insert(try record.makeGame(settings: settingsForGame))
                existingGameIDs.insert(sourceRecord.id)
                result.gamesAdded += 1
            }

            if let importedSettings = archive.settings,
               let settingsForGame {
                importedSettings.apply(to: settingsForGame)
                result.settingsApplied = true
            }

            try context.save()

            if let preferences = archive.interfacePreferences {
                preferences.apply()
                result.settingsApplied = true
            }

            return result
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func referencedPlayerIDs(in games: [Game]) -> Set<UUID> {
        games.reduce(into: Set<UUID>()) { ids, game in
            ids.formUnion(game.participantIDs)
            ids.formUnion(game.turnOrder)
            ids.formUnion(game.scorecards.map(\.playerID))
        }
    }

    private static func matchingPlayer(
        for record: YamSheetPlayerRecord,
        among players: [Player]
    ) -> Player? {
        if let email = normalizedOptional(record.email),
           let emailMatch = players.first(where: {
               normalizedOptional($0.email) == email
           }) {
            return emailMatch
        }

        let importedName = normalizedIdentity(record.name)
        let importedNickname = normalizedIdentity(record.nickname)
        return players.first {
            normalizedIdentity($0.name) == importedName
                && normalizedIdentity($0.nickname) == importedNickname
        }
    }

    private static func normalizedOptional(_ value: String?) -> String? {
        guard let value else { return nil }
        let normalized = normalizedIdentity(value)
        return normalized.isEmpty ? nil : normalized
    }

    private static func normalizedIdentity(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: Locale(identifier: "fr_FR")
            )
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    /// Conserve les notations homonymes qui n'ont pas les mêmes règles.
    /// La plus ancienne reçoit V1, la suivante V2, etc. Une notation intégrée
    /// garde toutefois son nom officiel et occupe sa place chronologique.
    private static func resolveNotationNameConflict(
        for importedNotation: Notation,
        sourceName: String,
        among existingNotations: [Notation]
    ) {
        let baseName = notationVersionBaseName(sourceName)
        let identity = normalizedIdentity(baseName)
        let conflicts = existingNotations.filter {
            normalizedIdentity(notationVersionBaseName($0.name)) == identity
        }

        guard !conflicts.isEmpty else {
            importedNotation.name = sourceName.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return
        }

        let ordered = (conflicts + [importedNotation])
            .enumerated()
            .sorted { lhs, rhs in
                let lhsDate = lhs.element.createdAt ?? .distantPast
                let rhsDate = rhs.element.createdAt ?? .distantPast
                if lhsDate == rhsDate {
                    return lhs.offset < rhs.offset
                }
                return lhsDate < rhsDate
            }

        for (position, entry) in ordered.enumerated() {
            guard !entry.element.isBuiltIn else { continue }
            entry.element.name = "\(baseName)_V\(position + 1)"
        }
    }

    private static func makeStatistics(
        for records: [YamSheetPlayerRecord],
        currentPlayers: [Player],
        games: [Game]
    ) -> [YamSheetPlayerStatisticsRecord] {
        let stats = StatsService.playerStats(
            allPlayers: currentPlayers,
            games: games
        )
        let statsByPlayerID = Dictionary(
            uniqueKeysWithValues: stats.map { ($0.playerID, $0) }
        )
        let primesByPlayerID = StatsService.yamsPrimesByPlayer(games: games)

        return records.map { player in
            let stats = statsByPlayerID[player.id]
            return YamSheetPlayerStatisticsRecord(
                playerID: player.id,
                displayName: player.nickname,
                gamesPlayed: stats?.gamesPlayed ?? 0,
                wins: stats?.wins ?? 0,
                averageScore: stats?.avgScore ?? 0,
                bestScore: stats?.bestScore ?? 0,
                worstScore: stats?.worstScore ?? 0,
                yamsRate: stats?.yamsRate ?? 0,
                yamsCount: stats?.yamsCount ?? 0,
                yamsPrimesCount: primesByPlayerID[player.id] ?? 0,
                scoresHistory: stats?.scoresHistory ?? []
            )
        }
    }

    private static func settingsForImport(
        archiveSettings: YamSheetSettingsRecord?,
        context: ModelContext
    ) throws -> AppSettings {
        if let existing = try context.fetch(FetchDescriptor<AppSettings>()).first {
            return existing
        }

        let settings = archiveSettings?.makeSettings() ?? AppSettings()
        context.insert(settings)
        return settings
    }

    private static var currentInterfacePreferences: YamSheetInterfacePreferencesRecord {
        let defaults = UserDefaults.standard
        return YamSheetInterfacePreferencesRecord(
            tintLight: defaults.object(forKey: tintLightKey) as? Double ?? 0.25,
            tintDark: defaults.object(forKey: tintDarkKey) as? Double ?? 0.65,
            columnRecenterMode: defaults.object(forKey: columnRecenterModeKey) as? Int ?? 1
        )
    }

    private static var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
    }

    private static var appBuild: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "—"
    }
}

private func notationVersionBaseName(_ name: String) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    let withoutVersion = trimmed.replacingOccurrences(
        of: #"_V\d+$"#,
        with: "",
        options: [.regularExpression, .caseInsensitive]
    )
    return withoutVersion.isEmpty ? "Notation" : withoutVersion
}

private extension YamSheetPlayerRecord {
    init(_ player: Player) {
        id = player.id
        name = player.name
        nickname = player.nickname
        email = player.email
        favoriteEmoji = player.favoriteEmoji
        colorData = player.colorData
        avatarImageData = player.avatarImageData
        isGuest = player.isGuest
        legacyGamesCount = player.legacy_gamesCount
        legacyYamsCount = player.legacy_yamsCount
        legacyAverageScore = player.legacy_averageScore
        legacyBestScore = player.legacy_bestScore
        legacyWorstScore = player.legacy_worstScore
        legacyWins = player.legacy_wins
        legacyLosses = player.legacy_losses
    }

    static func placeholder(id: UUID) -> YamSheetPlayerRecord {
        YamSheetPlayerRecord(
            id: id,
            name: "Joueur importé",
            nickname: "Joueur importé",
            email: nil,
            favoriteEmoji: nil,
            colorData: nil,
            avatarImageData: nil,
            isGuest: true,
            legacyGamesCount: nil,
            legacyYamsCount: nil,
            legacyAverageScore: nil,
            legacyBestScore: nil,
            legacyWorstScore: nil,
            legacyWins: nil,
            legacyLosses: nil
        )
    }

    func makePlayer() -> Player {
        let player = Player(
            id: id,
            name: name,
            nickname: nickname,
            email: email,
            favoriteEmoji: favoriteEmoji,
            avatarImageData: avatarImageData,
            isGuest: isGuest
        )
        player.colorData = colorData
        player.legacy_gamesCount = legacyGamesCount
        player.legacy_yamsCount = legacyYamsCount
        player.legacy_averageScore = legacyAverageScore
        player.legacy_bestScore = legacyBestScore
        player.legacy_worstScore = legacyWorstScore
        player.legacy_wins = legacyWins
        player.legacy_losses = legacyLosses
        return player
    }
}

private extension YamSheetGameRecord {
    func remappingPlayers(using mapping: [UUID: UUID]) -> Self {
        var copy = self
        copy.legacyWinnerPlayerID = legacyWinnerPlayerID.map {
            mapping[$0] ?? $0
        }
        copy.participantIDs = participantIDs.map { mapping[$0] ?? $0 }
        copy.turnOrder = turnOrder.map { mapping[$0] ?? $0 }
        copy.scorecards = scorecards.map { scorecard in
            var remapped = scorecard
            remapped.playerID = mapping[scorecard.playerID]
                ?? scorecard.playerID
            return remapped
        }
        copy.lastFilledCountByPlayer = lastFilledCountByPlayer.reduce(
            into: [:]
        ) { values, entry in
            let targetID = mapping[entry.key] ?? entry.key
            values[targetID] = max(values[targetID] ?? 0, entry.value)
        }
        return copy
    }

    init(_ game: Game) {
        id = game.id
        legacyUpdatedAt = game.legacy_updatedAt
        legacyWinnerPlayerID = game.legacy_winnerPlayerID
        participantIDs = game.participantIDs
        scorecards = game.scorecards.map(YamSheetScorecardRecord.init)
        upperBonusThreshold = game.upperBonusThreshold
        upperBonusValue = game.upperBonusValue
        enableSmallStraight = game.enableSmallStraight
        smallStraightScore = game.smallStraightScore
        name = game.name
        enableExtraYamsBonus = game.enableExtraYamsBonus
        enableChance = game.enableChance
        notationData = game.notationData
        createdAt = game.createdAt
        comment = game.comment
        columns = game.columns
        statusRaw = game.statusRaw
        status = game.status ?? GameStatus(rawValue: game.statusRaw)
        turnOrder = game.turnOrder
        currentTurnIndex = game.currentTurnIndex
        lastFilledCountByPlayer = game.lastFilledCountByPlayer
        requiredNotationKeys = game.requiredNotationKeys
        optionalNotationKeys = game.optionalNotationKeys
        startedAt = game.startedAt
        endedAt = game.endedAt
    }

    func makeGame(settings: AppSettings) throws -> Game {
        let notation = try JSONDecoder().decode(
            NotationSnapshot.self,
            from: notationData
        )
        let game = Game(
            settings: settings,
            notation: notation,
            columns: columns,
            comment: comment
        )

        game.id = id
        game.legacy_updatedAt = legacyUpdatedAt
        game.legacy_winnerPlayerID = legacyWinnerPlayerID
        game.participantIDs = participantIDs
        game.upperBonusThreshold = upperBonusThreshold
        game.upperBonusValue = upperBonusValue
        game.enableSmallStraight = enableSmallStraight
        game.smallStraightScore = smallStraightScore
        game.name = name
        game.enableExtraYamsBonus = enableExtraYamsBonus
        game.enableChance = enableChance
        game.notationData = notationData
        game.createdAt = createdAt
        game.comment = comment
        game.columns = columns
        game.statusRaw = statusRaw
        game.status = status ?? GameStatus(rawValue: statusRaw) ?? .inProgress
        game.turnOrder = turnOrder
        game.currentTurnIndex = currentTurnIndex
        game.lastFilledCountByPlayer = lastFilledCountByPlayer
        game.requiredNotationKeys = requiredNotationKeys
        game.optionalNotationKeys = optionalNotationKeys
        game.startedAt = startedAt
        game.endedAt = endedAt
        game.scorecards = scorecards.map { $0.makeScorecard() }
        game.scorecards.forEach { $0.game = game }
        return game
    }
}

private extension YamSheetScorecardRecord {
    init(_ scorecard: Scorecard) {
        id = scorecard.id
        playerID = scorecard.playerID
        columns = scorecard.columns
        legacyExtraYams = scorecard.legacy_extraYams
        extraYamsAwarded = scorecard.extraYamsAwarded
        declaredYams = scorecard.declaredYams
        extraYamsSources = scorecard.extraYamsSources
        extraYamsAwards = scorecard.extraYamsAwards
        ones = scorecard.ones
        twos = scorecard.twos
        threes = scorecard.threes
        fours = scorecard.fours
        fives = scorecard.fives
        sixes = scorecard.sixes
        maxVals = scorecard.maxVals
        minVals = scorecard.minVals
        brelan = scorecard.brelan
        chance = scorecard.chance
        full = scorecard.full
        carre = scorecard.carre
        yams = scorecard.yams
        suite = scorecard.suite
        petiteSuite = scorecard.petiteSuite
        locks = scorecard.locks
    }

    func makeScorecard() -> Scorecard {
        let scorecard = Scorecard(playerID: playerID, columns: columns)
        scorecard.id = id
        scorecard.legacy_extraYams = legacyExtraYams
        scorecard.extraYamsAwarded = extraYamsAwarded
        scorecard.declaredYams = declaredYams
        scorecard.extraYamsSources = extraYamsSources
        scorecard.extraYamsAwards = extraYamsAwards
        scorecard.ones = ones
        scorecard.twos = twos
        scorecard.threes = threes
        scorecard.fours = fours
        scorecard.fives = fives
        scorecard.sixes = sixes
        scorecard.maxVals = maxVals
        scorecard.minVals = minVals
        scorecard.brelan = brelan
        scorecard.chance = chance
        scorecard.full = full
        scorecard.carre = carre
        scorecard.yams = yams
        scorecard.suite = suite
        scorecard.petiteSuite = petiteSuite
        scorecard.locks = locks
        return scorecard
    }
}

private extension YamSheetNotationRecord {
    /// Compare les notations selon leur comportement réel plutôt que selon la
    /// présence des champs ajoutés après la V1 dans le fichier de sauvegarde.
    var duplicateDetectionRecord: YamSheetNotationRecord {
        var record = self
        record.name = notationVersionBaseName(name)
        // La date départage les homonymes, mais ne fait pas partie des règles.
        record.createdAt = nil
        record.comment = normalizedOptionalText(comment)
        record.tooltipUpper = normalizedOptionalText(tooltipUpper)
        record.tooltipMiddle = normalizedOptionalText(tooltipMiddle)
        record.tooltipBottom = normalizedOptionalText(tooltipBottom)
        record.middleInvalidPairMode = middleInvalidPairMode ?? .keepSum
        record.chanceEnabled = chanceEnabled ?? true
        record.scoreHelpTexts = scoreHelpTexts ?? [:]
        record.visibility = visibility ?? .allVisible
        record.scorecardAppearance = scorecardAppearance ?? .standard
        return record
    }

    private func normalizedOptionalText(_ text: String?) -> String? {
        let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    init(_ notation: Notation) {
        name = notation.name
        createdAt = notation.createdAt
        comment = notation.comment.isEmpty ? nil : notation.comment
        tooltipUpper = notation.tooltipUpper
        tooltipMiddle = notation.tooltipMiddle
        tooltipBottom = notation.tooltipBottom
        upperBonusThreshold = notation.upperBonusThreshold
        upperBonusValue = notation.upperBonusValue
        middleMode = notation.middleMode
        middleBonusSumThreshold = notation.middleBonusSumThreshold
        middleBonusValue = notation.middleBonusValue
        middleInvalidPairMode = notation.middleInvalidPairMode
        ruleBrelan = notation.ruleBrelan
        ruleChance = notation.ruleChance
        chanceEnabled = notation.isChanceEnabled
        ruleFull = notation.ruleFull
        ruleSuite = notation.ruleSuite
        rulePetiteSuite = notation.rulePetiteSuite
        smallStraightEnabled = notation.isSmallStraightEnabled
        ruleCarre = notation.ruleCarre
        ruleYams = notation.ruleYams
        suiteBigMode = notation.suiteBigMode
        suiteBigFixed = notation.suiteBigFixed
        suiteBigFixed1to5 = notation.suiteBigFixed1to5
        suiteBigFixed2to6 = notation.suiteBigFixed2to6
        extraYamsBonusMode = notation.extraYamsBonusMode
        extraYamsBonusValue = notation.extraYamsBonusValue
        scoreHelpTexts = notation.scoreHelpTexts
        visibility = notation.visibility
        scorecardAppearance = notation.scorecardAppearance
    }

    func makeNotation(legacyCreationDate: Date) -> Notation {
        let notation = Notation(
            name: name,
            createdAt: createdAt ?? legacyCreationDate,
            comment: comment ?? "",
            tooltipUpper: tooltipUpper,
            tooltipMiddle: tooltipMiddle,
            tooltipBottom: tooltipBottom,
            upperBonusThreshold: upperBonusThreshold,
            upperBonusValue: upperBonusValue,
            middleMode: middleMode,
            middleBonusSumThreshold: middleBonusSumThreshold,
            middleBonusValue: middleBonusValue,
            middleInvalidPairMode: middleInvalidPairMode ?? .keepSum,
            ruleBrelan: ruleBrelan,
            ruleChance: ruleChance,
            chanceEnabled: chanceEnabled ?? true,
            ruleFull: ruleFull,
            ruleSuite: ruleSuite,
            rulePetiteSuite: rulePetiteSuite,
            smallStraightEnabled: smallStraightEnabled,
            ruleCarre: ruleCarre,
            ruleYams: ruleYams,
            extraYamsBonusEnabled: extraYamsBonusMode != .disabled,
            extraYamsBonusValue: extraYamsBonusValue
        )
        notation.suiteBigMode = suiteBigMode
        notation.suiteBigFixed = suiteBigFixed
        notation.suiteBigFixed1to5 = suiteBigFixed1to5
        notation.suiteBigFixed2to6 = suiteBigFixed2to6
        notation.extraYamsBonusMode = extraYamsBonusMode
        notation.scoreHelpTexts = scoreHelpTexts ?? [:]
        notation.visibility = visibility ?? .allVisible
        notation.scorecardAppearance = scorecardAppearance ?? .standard
        return notation
    }
}

private extension YamSheetSettingsRecord {
    init(_ settings: AppSettings) {
        upperBonusThreshold = settings.upperBonusThreshold
        upperBonusValue = settings.upperBonusValue
        enableSmallStraight = settings.enableSmallStraight
        smallStraightScore = settings.smallStraightScore
        darkMode = settings.darkMode
        scoreHelpEnabled = settings.showsScoreHelp
    }

    func makeSettings() -> AppSettings {
        AppSettings(
            upperBonusThreshold: upperBonusThreshold,
            upperBonusValue: upperBonusValue,
            enableSmallStraight: enableSmallStraight,
            smallStraightScore: smallStraightScore,
            darkMode: darkMode,
            scoreHelpEnabled: scoreHelpEnabled ?? true
        )
    }

    func apply(to settings: AppSettings) {
        settings.upperBonusThreshold = upperBonusThreshold
        settings.upperBonusValue = upperBonusValue
        settings.enableSmallStraight = enableSmallStraight
        settings.smallStraightScore = smallStraightScore
        settings.darkMode = darkMode
        settings.showsScoreHelp = scoreHelpEnabled ?? true
    }
}

private extension YamSheetInterfacePreferencesRecord {
    func apply() {
        let defaults = UserDefaults.standard
        defaults.set(tintLight, forKey: "tintLight")
        defaults.set(tintDark, forKey: "tintDark")
        defaults.set(columnRecenterMode, forKey: "columnRecenterMode")
    }
}

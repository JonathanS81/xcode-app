import XCTest
import SwiftData
import SwiftUI
import CoreGraphics
@testable import YamSheet

final class YamSheetBackupTests: XCTestCase {
    @MainActor
    func testCompleteBackupRoundTripAndDuplicateSafeImport() throws {
        let sourceContainer = try makeContainer()
        let sourceContext = ModelContext(sourceContainer)

        let settings = AppSettings(darkMode: true)
        let player = Player(
            name: "Alice Martin",
            nickname: "Alice",
            email: "alice@example.com",
            favoriteEmoji: "🎲"
        )
        let notation = Notation(
            name: "Classique test",
            extraYamsBonusEnabled: true,
            extraYamsBonusValue: 50
        )
        notation.extraYamsBonusMode = .multiple
        notation.middleInvalidPairMode = .zeroSection
        notation.isChanceEnabled = false
        notation.setHelpText("Additionnez les As obtenus.", for: .ones)
        notation.setHelpText("Règles de la section haute.", for: .sectionUpper)
        settings.showsScoreHelp = false

        sourceContext.insert(settings)
        sourceContext.insert(player)
        sourceContext.insert(notation)

        let game = Game(
            settings: settings,
            notation: notation.snapshot(),
            columns: 1,
            comment: "Partie de contrôle"
        )
        game.name = "Sauvegarde test"
        XCTAssertFalse(game.enableChance)
        game.participantIDs = [player.id]
        game.turnOrder = [player.id]
        game.requiredNotationKeys = ["ones", "yams"]
        game.statusOrDefault = .completed
        game.startedAt = game.createdAt
        game.endedAt = Date()

        let scorecard = Scorecard(playerID: player.id, columns: 1)
        scorecard.ones = [5]
        scorecard.yams = [25]
        scorecard.setDeclaredYams(true, col: 0, key: "ones")
        scorecard.addExtraYamsAward(col: 0, source: "yams")
        game.scorecards = [scorecard]
        scorecard.game = game

        sourceContext.insert(game)
        try sourceContext.save()

        let playersArchive = try YamSheetBackupService.makeArchive(
            scope: .players,
            players: [player],
            games: [game],
            notations: [notation],
            settings: settings
        )
        XCTAssertEqual(playersArchive.players.count, 1)
        XCTAssertEqual(playersArchive.playerStatistics.count, 1)
        XCTAssertEqual(playersArchive.games.count, 1)
        XCTAssertTrue(playersArchive.notations.isEmpty)
        XCTAssertNil(playersArchive.settings)

        let gamesArchive = try YamSheetBackupService.makeArchive(
            scope: .games,
            players: [player],
            games: [game],
            notations: [notation],
            settings: settings
        )
        XCTAssertEqual(gamesArchive.players.count, 1)
        XCTAssertEqual(gamesArchive.games.count, 1)
        XCTAssertTrue(gamesArchive.playerStatistics.isEmpty)
        XCTAssertTrue(gamesArchive.notations.isEmpty)
        XCTAssertNil(gamesArchive.settings)

        let notationsArchive = try YamSheetBackupService.makeArchive(
            scope: .notations,
            players: [],
            games: [],
            notations: [notation],
            settings: nil
        )
        XCTAssertTrue(notationsArchive.players.isEmpty)
        XCTAssertTrue(notationsArchive.playerStatistics.isEmpty)
        XCTAssertTrue(notationsArchive.games.isEmpty)
        XCTAssertEqual(notationsArchive.notations.count, 1)
        XCTAssertNil(notationsArchive.settings)
        try YamSheetBackupValidator.validate(notationsArchive)

        let notationDestination = try makeContainer()
        let notationContext = ModelContext(notationDestination)
        let notationImport = try YamSheetBackupService.importArchive(
            notationsArchive,
            into: notationContext
        )
        XCTAssertEqual(notationImport.notationsAdded, 1)
        let importedNotationOnly = try notationContext.fetch(
            FetchDescriptor<Notation>()
        ).first
        XCTAssertEqual(importedNotationOnly?.isChanceEnabled, false)
        XCTAssertEqual(importedNotationOnly?.middleInvalidPairMode, .zeroSection)
        XCTAssertEqual(
            try notationContext.fetchCount(FetchDescriptor<Notation>()),
            1
        )
        XCTAssertEqual(
            try notationContext.fetchCount(FetchDescriptor<AppSettings>()),
            0
        )

        let archive = try YamSheetBackupService.makeArchive(
            scope: .full,
            players: [player],
            games: [game],
            notations: [notation],
            settings: settings
        )
        let encoded = try YamSheetBackupCoding.encode(archive)
        let decoded = try YamSheetBackupCoding.decode(encoded)
        try YamSheetBackupValidator.validate(decoded)

        XCTAssertEqual(decoded.players.count, 1)
        XCTAssertEqual(decoded.games.count, 1)
        XCTAssertEqual(decoded.games.first?.scorecards.count, 1)
        XCTAssertEqual(decoded.playerStatistics.first?.yamsCount, 2)
        XCTAssertEqual(decoded.playerStatistics.first?.yamsPrimesCount, 1)
        XCTAssertEqual(decoded.notations.first?.chanceEnabled, false)
        XCTAssertEqual(
            decoded.notations.first?.scoreHelpTexts?[ScoreHelpKey.ones.rawValue],
            "Additionnez les As obtenus."
        )
        XCTAssertEqual(decoded.settings?.scoreHelpEnabled, false)

        let destinationContainer = try makeContainer()
        let destinationContext = ModelContext(destinationContainer)

        let firstImport = try YamSheetBackupService.importArchive(
            decoded,
            into: destinationContext
        )
        XCTAssertEqual(firstImport.playersAdded, 1)
        XCTAssertEqual(firstImport.gamesAdded, 1)
        XCTAssertEqual(firstImport.notationsAdded, 1)
        XCTAssertTrue(firstImport.settingsApplied)

        let importedPlayers = try destinationContext.fetch(FetchDescriptor<Player>())
        let importedGames = try destinationContext.fetch(FetchDescriptor<Game>())
        let importedSettings = try destinationContext.fetch(FetchDescriptor<AppSettings>())
        let importedNotations = try destinationContext.fetch(
            FetchDescriptor<Notation>()
        )

        XCTAssertEqual(importedPlayers.first?.id, player.id)
        XCTAssertEqual(importedPlayers.first?.email, "alice@example.com")
        XCTAssertEqual(importedGames.first?.id, game.id)
        XCTAssertEqual(importedGames.first?.scorecards.count, 1)
        XCTAssertEqual(importedGames.first?.scorecards.first?.ones, [5])
        XCTAssertEqual(
            importedGames.first?.scorecards.first?.isDeclaredYams(col: 0, key: "ones"),
            true
        )
        XCTAssertEqual(
            importedGames.first?.scorecards.first?.extraYamsAwardsCount(col: 0),
            1
        )
        XCTAssertEqual(importedSettings.first?.darkMode, true)
        XCTAssertEqual(importedSettings.first?.showsScoreHelp, false)
        XCTAssertEqual(importedNotations.first?.isChanceEnabled, false)
        XCTAssertEqual(
            importedNotations.first?.helpTextValue(for: .ones),
            "Additionnez les As obtenus."
        )
        XCTAssertEqual(
            importedGames.first?.notation.helpText(for: .sectionUpper),
            "Règles de la section haute."
        )

        let secondImport = try YamSheetBackupService.importArchive(
            decoded,
            into: destinationContext
        )
        XCTAssertEqual(secondImport.playersAdded, 0)
        XCTAssertEqual(secondImport.playersSkipped, 1)
        XCTAssertEqual(secondImport.gamesAdded, 0)
        XCTAssertEqual(secondImport.gamesSkipped, 1)
        XCTAssertEqual(
            try destinationContext.fetchCount(FetchDescriptor<Player>()),
            1
        )
        XCTAssertEqual(
            try destinationContext.fetchCount(FetchDescriptor<Game>()),
            1
        )
    }

    @MainActor
    func testLegacyNotationSnapshotDefaultsChanceToEnabled() throws {
        let notation = Notation(name: "Ancienne notation")
        let encoded = try JSONEncoder().encode(notation.snapshot())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "chanceEnabled")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(
            NotationSnapshot.self,
            from: legacyData
        )

        XCTAssertTrue(decoded.resolvedChanceEnabled)
    }

    func testLegacyNotationHelpFallsBackToExistingTooltipFields() throws {
        let notation = Notation(
            name: "Ancienne notation",
            tooltipUpper: "Ancienne aide haute",
            ruleBrelan: FigureRule(
                mode: .raw,
                tooltip: "Ancienne aide du brelan"
            )
        )
        let encoded = try JSONEncoder().encode(notation.snapshot())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "scoreHelpTexts")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(
            NotationSnapshot.self,
            from: legacyData
        )

        XCTAssertEqual(decoded.helpText(for: .sectionUpper), "Ancienne aide haute")
        XCTAssertEqual(decoded.helpText(for: .brelan), "Ancienne aide du brelan")
        XCTAssertNil(decoded.helpText(for: .ones))
    }

    func testLegacyNotationSnapshotDefaultsInvalidMaxMinPairToKeepSum() throws {
        let notation = Notation(name: "Ancienne notation")
        let encoded = try JSONEncoder().encode(notation.snapshot())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "middleInvalidPairMode")
        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let decoded = try JSONDecoder().decode(
            NotationSnapshot.self,
            from: legacyData
        )

        XCTAssertEqual(decoded.resolvedMiddleInvalidPairMode, .keepSum)
    }

    @MainActor
    func testPlayerBackupIncludesHistoryAndKeepsLocalPlayer() throws {
        let sourceContainer = try makeContainer()
        let sourceContext = ModelContext(sourceContainer)
        let sourcePlayer = Player(
            name: "Élodie Martin",
            nickname: "Elo",
            email: "elodie@example.com"
        )
        let opponent = Player(name: "Bob Durand", nickname: "Bob")
        let settings = AppSettings()
        let notation = Notation(name: "Classique")
        let game = Game(
            settings: settings,
            notation: notation.snapshot(),
            columns: 1
        )
        game.name = "Historique partagé"
        game.participantIDs = [sourcePlayer.id, opponent.id]
        game.turnOrder = [sourcePlayer.id, opponent.id]
        game.statusOrDefault = .completed
        game.endedAt = Date()

        let sourceScorecard = Scorecard(
            playerID: sourcePlayer.id,
            columns: 1
        )
        sourceScorecard.ones = [5]
        let opponentScorecard = Scorecard(
            playerID: opponent.id,
            columns: 1
        )
        opponentScorecard.ones = [3]
        game.scorecards = [sourceScorecard, opponentScorecard]
        sourceScorecard.game = game
        opponentScorecard.game = game

        sourceContext.insert(settings)
        sourceContext.insert(sourcePlayer)
        sourceContext.insert(opponent)
        sourceContext.insert(notation)
        sourceContext.insert(game)
        try sourceContext.save()

        let archive = try YamSheetBackupService.makeArchive(
            scope: .players,
            players: [sourcePlayer, opponent],
            games: [game],
            notations: [],
            settings: nil,
            selectedPlayerIDs: [sourcePlayer.id]
        )
        XCTAssertEqual(archive.players.count, 2)
        XCTAssertEqual(archive.playerStatistics.count, 1)
        XCTAssertEqual(archive.games.count, 1)

        let destinationContainer = try makeContainer()
        let destinationContext = ModelContext(destinationContainer)
        let localPlayer = Player(
            name: "Elodie Martin",
            nickname: "Elo",
            email: "elodie@example.com"
        )
        localPlayer.legacy_gamesCount = 99
        destinationContext.insert(localPlayer)
        try destinationContext.save()

        let result = try YamSheetBackupService.importArchive(
            archive,
            into: destinationContext
        )
        XCTAssertEqual(result.playersSkipped, 1)
        XCTAssertEqual(result.playersAdded, 1)
        XCTAssertEqual(result.gamesAdded, 1)

        let importedPlayers = try destinationContext.fetch(
            FetchDescriptor<Player>()
        )
        let importedGames = try destinationContext.fetch(
            FetchDescriptor<Game>()
        )
        XCTAssertEqual(importedPlayers.count, 2)
        XCTAssertEqual(localPlayer.legacy_gamesCount, 99)
        XCTAssertFalse(importedPlayers.contains { $0.id == sourcePlayer.id })
        XCTAssertTrue(
            importedGames[0].participantIDs.contains(localPlayer.id)
        )
        XCTAssertTrue(
            importedGames[0].scorecards.contains {
                $0.playerID == localPlayer.id
            }
        )
    }

    @MainActor
    func testPDFExportsAreReadableDocuments() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let settings = AppSettings()
        let player = Player(
            name: "Alice Martin",
            nickname: "Alice",
            color: .red
        )
        let bob = Player(
            name: "Bob Durand",
            nickname: "Bob",
            color: .blue
        )
        let chloe = Player(
            name: "Chloé Petit",
            nickname: "Chloé",
            color: .green
        )
        let notation = Notation(name: "Classique")
        let game = Game(
            settings: settings,
            notation: notation.snapshot(),
            columns: 1
        )
        game.name = "Partie PDF"
        game.participantIDs = [player.id, bob.id, chloe.id]
        game.turnOrder = [player.id, bob.id, chloe.id]
        game.statusOrDefault = .completed

        let scorecard = Scorecard(playerID: player.id, columns: 1)
        scorecard.ones = [5]
        scorecard.yams = [25]
        scorecard.setDeclaredYams(true, col: 0, key: "ones")
        scorecard.addExtraYamsAward(col: 0, source: "yams")
        let bobScorecard = Scorecard(playerID: bob.id, columns: 1)
        bobScorecard.ones = [3]
        bobScorecard.yams = [0]
        let chloeScorecard = Scorecard(playerID: chloe.id, columns: 1)
        chloeScorecard.ones = [4]
        chloeScorecard.yams = [20]
        game.scorecards = [scorecard, bobScorecard, chloeScorecard]
        scorecard.game = game
        bobScorecard.game = game
        chloeScorecard.game = game

        context.insert(settings)
        context.insert(player)
        context.insert(bob)
        context.insert(chloe)
        context.insert(notation)
        context.insert(game)
        try context.save()

        let playerPDF = YamSheetPDFExportService.playersReport(
            players: [player],
            allPlayers: [player, bob, chloe],
            games: [game]
        )
        let gamePDF = YamSheetPDFExportService.gamesReport(
            games: [game],
            allGames: [game],
            players: [player, bob, chloe]
        )

        XCTAssertTrue(playerPDF.starts(with: Data("%PDF".utf8)))
        XCTAssertTrue(gamePDF.starts(with: Data("%PDF".utf8)))
        XCTAssertGreaterThan(playerPDF.count, 1_000)
        XCTAssertGreaterThan(gamePDF.count, 1_000)
        let provider = CGDataProvider(data: gamePDF as CFData)
        let document = provider.flatMap(CGPDFDocument.init)
        XCTAssertEqual(document?.numberOfPages, 1)
        if let firstPage = document?.page(at: 1) {
            let pageBox = firstPage.getBoxRect(.mediaBox)
            XCTAssertGreaterThan(pageBox.width, pageBox.height)
        } else {
            XCTFail("Le PDF de partie ne contient aucune page.")
        }
    }

    @MainActor
    func testStatsSeparateNotationsAndLabelPlayerRecords() throws {
        let settings = AppSettings()
        let player = Player(name: "Alice Martin", nickname: "Alice")
        let classic = Notation(name: "Classique")
        let rapide = Notation(name: "Rapide")

        let classicGame = Game(
            settings: settings,
            notation: classic.snapshot(),
            columns: 1
        )
        classicGame.statusOrDefault = .completed
        classicGame.participantIDs = [player.id]
        let classicScorecard = Scorecard(
            playerID: player.id,
            columns: 1
        )
        classicScorecard.chance = [100]
        classicScorecard.game = classicGame
        classicGame.scorecards = [classicScorecard]

        let rapideGame = Game(
            settings: settings,
            notation: rapide.snapshot(),
            columns: 1
        )
        rapideGame.statusOrDefault = .completed
        rapideGame.participantIDs = [player.id]
        let rapideScorecard = Scorecard(
            playerID: player.id,
            columns: 1
        )
        rapideScorecard.chance = [20]
        rapideScorecard.game = rapideGame
        rapideGame.scorecards = [rapideScorecard]

        let games = [classicGame, rapideGame]
        let allStats = StatsService.playerStats(
            allPlayers: [player],
            games: games
        )
        XCTAssertEqual(allStats.first?.bestScore, 100)
        XCTAssertEqual(allStats.first?.bestScoreNotation, "Classique")
        XCTAssertEqual(allStats.first?.worstScore, 20)
        XCTAssertEqual(allStats.first?.worstScoreNotation, "Rapide")

        let options = StatsService.notationOptions(games: games)
        XCTAssertEqual(options.map(\.name), ["Classique", "Rapide"])

        let classicName = options.first {
            $0.name == "Classique"
        }?.name
        let classicGames = StatsService.completedGames(
            from: games,
            notationName: classicName
        )
        let classicStats = StatsService.playerStats(
            allPlayers: [player],
            games: classicGames
        )
        XCTAssertEqual(classicGames.count, 1)
        XCTAssertEqual(classicStats.first?.avgScore, 100)

        let legacyNotation = Notation(name: "Par défaut")
        let legacyGame = Game(
            settings: settings,
            notation: legacyNotation.snapshot(),
            columns: 1
        )
        legacyGame.statusOrDefault = .completed
        XCTAssertEqual(
            StatsService.notationName(for: legacyGame),
            "Classique"
        )
        XCTAssertEqual(
            StatsService.notationOptions(
                games: [classicGame, legacyGame]
            ).map(\.name),
            ["Classique"]
        )
    }

    private func makeContainer() throws -> ModelContainer {
        let schema = Schema([
            AppSettings.self,
            Player.self,
            Game.self,
            Scorecard.self,
            Notation.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: schema,
            configurations: configuration
        )
    }
}

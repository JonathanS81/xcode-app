import XCTest
import SwiftData
@testable import YamSheet

final class BuiltInNotationTests: XCTestCase {
    func testFigureDiceBasisKeepsLegacyRulesAndExplicitChoices() throws {
        let legacyRaw = FigureRule(mode: .raw)
        let legacyCarreWithPrime = FigureRule(
            mode: .rawPlusFixed,
            fixedValue: 40
        )
        let explicitFiveDiceCarre = FigureRule(
            mode: .rawPlusFixed,
            fixedValue: 40,
            diceBasis: .fiveDice
        )
        let explicitFigureBrelan = FigureRule(
            mode: .rawTimes,
            multiplier: 2,
            diceBasis: .figureDice
        )

        XCTAssertEqual(legacyRaw.resolvedDiceBasis(for: .brelan), .fiveDice)
        XCTAssertEqual(legacyRaw.resolvedDiceBasis(for: .carre), .fiveDice)
        XCTAssertEqual(
            legacyCarreWithPrime.resolvedDiceBasis(for: .carre),
            .figureDice
        )
        XCTAssertEqual(
            explicitFiveDiceCarre.resolvedDiceBasis(for: .carre),
            .fiveDice
        )
        XCTAssertEqual(
            explicitFigureBrelan.resolvedDiceBasis(for: .brelan),
            .figureDice
        )

        let legacyEncoded = try JSONEncoder().encode(legacyCarreWithPrime)
        let legacyDecoded = try JSONDecoder().decode(
            FigureRule.self,
            from: legacyEncoded
        )
        XCTAssertNil(legacyDecoded.diceBasis)
        XCTAssertEqual(
            legacyDecoded.resolvedDiceBasis(for: .carre),
            .figureDice
        )

        let encoded = try JSONEncoder().encode(explicitFigureBrelan)
        let decoded = try JSONDecoder().decode(FigureRule.self, from: encoded)
        XCTAssertEqual(decoded.diceBasis, .figureDice)
    }

    func testFigureHelpDescribesTheSelectedDiceBasis() {
        let notation = Notation(
            name: "Aides des figures",
            ruleBrelan: FigureRule(
                mode: .rawPlusFixed,
                fixedValue: 10,
                diceBasis: .figureDice
            ),
            ruleCarre: FigureRule(
                mode: .rawTimes,
                multiplier: 2,
                diceBasis: .fiveDice
            )
        )

        XCTAssertTrue(
            notation.helpTextValue(for: .brelan)
                .contains("trois dés constituant le Brelan")
        )
        XCTAssertTrue(
            notation.helpTextValue(for: .carre)
                .contains("cinq dés")
        )
    }

    func testLegacySnapshotKeepsEveryHistoricalScoreField() throws {
        let notation = Notation(name: "Ancienne notation")
        let encoded = try JSONEncoder().encode(notation.snapshot())
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )
        object.removeValue(forKey: "visibility")
        object.removeValue(forKey: "scorecardAppearance")

        let legacyData = try JSONSerialization.data(withJSONObject: object)
        let legacySnapshot = try JSONDecoder().decode(
            NotationSnapshot.self,
            from: legacyData
        )

        XCTAssertEqual(legacySnapshot.resolvedVisibility, .allVisible)
        XCTAssertEqual(legacySnapshot.requiredScoreKeys.count, 15)
        XCTAssertTrue(legacySnapshot.requiredScoreKeys.contains("max"))
        XCTAssertTrue(legacySnapshot.requiredScoreKeys.contains("chance"))
        XCTAssertTrue(legacySnapshot.requiredScoreKeys.contains("petiteSuite"))
        XCTAssertEqual(legacySnapshot.resolvedScorecardAppearance, .standard)
    }

    func testStandardPresetHidesMiddleAndKeepsThirteenFields() {
        let notation = BuiltInNotations.make(.standard)
        let snapshot = notation.snapshot()

        XCTAssertTrue(notation.isBuiltIn)
        XCTAssertEqual(notation.name, "Standard")
        XCTAssertEqual(notation.comment, "Notation standard du Yahtzee")
        XCTAssertFalse(snapshot.middleSectionIsEnabled)
        XCTAssertFalse(snapshot.requiredScoreKeys.contains("max"))
        XCTAssertFalse(snapshot.requiredScoreKeys.contains("min"))
        XCTAssertEqual(snapshot.requiredScoreKeys.count, 13)
        XCTAssertEqual(snapshot.ruleFull.fixedValue, 25)
        XCTAssertEqual(snapshot.suiteBigFixed, 40)
        XCTAssertEqual(snapshot.ruleYams.fixedValue, 50)
        XCTAssertEqual(snapshot.extraYamsBonusValue, 100)
    }

    func testDuplicateBecomesEditableAndKeepsHelpAndVisibility() {
        let original = BuiltInNotations.make(.standard)
        original.scorecardAppearance = ScorecardAppearance(
            mode: .photo,
            imageData: Data([1, 2, 3]),
            intensity: 0.30
        )
        let duplicate = original.duplicate()

        XCTAssertFalse(duplicate.isBuiltIn)
        XCTAssertEqual(duplicate.name, "Standard - copie")
        XCTAssertEqual(duplicate.comment, original.comment)
        XCTAssertEqual(duplicate.visibility, original.visibility)
        XCTAssertEqual(duplicate.scorecardAppearance, original.scorecardAppearance)
        XCTAssertEqual(
            duplicate.helpTextValue(for: .sectionBottom),
            original.helpTextValue(for: .sectionBottom)
        )
    }

    @MainActor
    func testBuiltInInstallationIsIdempotent() throws {
        let schema = Schema([Notation.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        try BuiltInNotations.installIfNeeded(in: context)
        try BuiltInNotations.installIfNeeded(in: context)

        let notations = try context.fetch(FetchDescriptor<Notation>())
        XCTAssertEqual(notations.count, 1)
        XCTAssertEqual(Set(notations.compactMap(\.builtInIdentifier)), Set(BuiltInNotationID.allCases))
    }

    @MainActor
    func testInstallationRemovesRetiredPrototypeAndUpdatesStandard() throws {
        let schema = Schema([Notation.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: configuration)
        let context = ModelContext(container)

        let previousStandard = Notation(name: "Yahtzee standard")
        previousStandard.builtInIdentifierRaw = BuiltInNotationID.standard.rawValue
        let retiredClassic = Notation(name: "Yams classique")
        retiredClassic.builtInIdentifierRaw = "yamsheet.yams-classic.v1"
        let personalClassic = Notation(name: "Yams classique")
        personalClassic.createdAt = nil
        context.insert(previousStandard)
        context.insert(retiredClassic)
        context.insert(personalClassic)
        try context.save()

        try BuiltInNotations.installIfNeeded(in: context)

        let notations = try context.fetch(FetchDescriptor<Notation>())
        XCTAssertEqual(notations.count, 2)
        XCTAssertTrue(notations.contains(where: { $0 === personalClassic }))
        XCTAssertEqual(
            personalClassic.createdAt,
            NotationCreationDatePolicy.legacyV1
        )
        XCTAssertEqual(previousStandard.name, "Standard")
        XCTAssertEqual(previousStandard.comment, "Notation standard du Yahtzee")
        XCTAssertFalse(previousStandard.visibility.middleSectionEnabled)
        XCTAssertFalse(notations.contains(where: {
            $0.builtInIdentifierRaw == "yamsheet.yams-classic.v1"
        }))
    }

    func testHiddenSectionsDoNotContributeToTotals() {
        let notation = Notation(name: "Masquée")
        notation.visibility = NotationVisibility(
            upperSectionEnabled: false,
            middleSectionEnabled: false,
            bottomSectionEnabled: true,
            brelanEnabled: false,
            fullEnabled: false,
            suiteEnabled: false,
            carreEnabled: false,
            yamsEnabled: true
        )
        notation.isChanceEnabled = false
        notation.isSmallStraightEnabled = false

        let game = Game(settings: AppSettings(), notation: notation.snapshot())
        let scorecard = Scorecard(playerID: UUID(), columns: 1)
        scorecard.ones = [5]
        scorecard.maxVals = [30]
        scorecard.minVals = [5]
        scorecard.brelan = [30]
        scorecard.yams = [25]

        XCTAssertEqual(StatsEngine.upperTotal(sc: scorecard, game: game, col: 0), 0)
        XCTAssertEqual(StatsEngine.middleTotal(sc: scorecard, game: game, col: 0), 0)
        XCTAssertEqual(
            StatsEngine.bottomTotal(sc: scorecard, game: game, col: 0),
            75
        )
        XCTAssertEqual(game.requiredNotationKeys, ["yams"])
    }
}

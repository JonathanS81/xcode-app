import Foundation
import SwiftUI
import UniformTypeIdentifiers

enum YamSheetBackupScope: String, Codable, CaseIterable, Identifiable {
    case players
    case games
    case notations
    case full

    var id: String { rawValue }

    var title: String {
        switch self {
        case .players:
            return "Joueurs et statistiques"
        case .games:
            return "Historique des parties"
        case .notations:
            return "Notations"
        case .full:
            return "Sauvegarde complète"
        }
    }

    var detail: String {
        switch self {
        case .players:
            return "Fiches, avatars et résumé des statistiques, sans les parties."
        case .games:
            return "Parties sélectionnées, leurs scores et les joueurs associés."
        case .notations:
            return "Notations sélectionnées et toutes leurs règles."
        case .full:
            return "Joueurs, parties, notations et préférences de l’application."
        }
    }

    var systemImage: String {
        switch self {
        case .players:
            return "person.2"
        case .games:
            return "list.bullet.rectangle"
        case .notations:
            return "list.star"
        case .full:
            return "externaldrive"
        }
    }
}

struct YamSheetBackupMetadata: Codable {
    static let expectedMagic = "YAMSHEET_BACKUP"
    static let currentFormatVersion = 1

    var magic: String
    var formatVersion: Int
    var archiveID: UUID
    var exportedAt: Date
    var sourceAppVersion: String
    var sourceBuild: String
    var scope: YamSheetBackupScope
}

struct YamSheetBackupArchive: Codable, Identifiable {
    var id: UUID { metadata.archiveID }

    var metadata: YamSheetBackupMetadata
    var players: [YamSheetPlayerRecord]
    var playerStatistics: [YamSheetPlayerStatisticsRecord]
    var games: [YamSheetGameRecord]
    var notations: [YamSheetNotationRecord]
    var settings: YamSheetSettingsRecord?
    var interfacePreferences: YamSheetInterfacePreferencesRecord?
}

struct YamSheetPlayerRecord: Codable, Hashable {
    var id: UUID
    var name: String
    var nickname: String
    var email: String?
    var favoriteEmoji: String?
    var colorData: Data?
    var avatarImageData: Data?
    var isGuest: Bool
    var legacyGamesCount: Int?
    var legacyYamsCount: Int?
    var legacyAverageScore: Double?
    var legacyBestScore: Int?
    var legacyWorstScore: Int?
    var legacyWins: Int?
    var legacyLosses: Int?
}

struct YamSheetPlayerStatisticsRecord: Codable, Hashable {
    var playerID: UUID
    var displayName: String
    var gamesPlayed: Int
    var wins: Int
    var averageScore: Double
    var bestScore: Int
    var worstScore: Int
    var yamsRate: Double
    var yamsCount: Int
    var yamsPrimesCount: Int
    var scoresHistory: [Int]
}

struct YamSheetGameRecord: Codable, Hashable {
    var id: UUID
    var legacyUpdatedAt: Date?
    var legacyWinnerPlayerID: UUID?
    var participantIDs: [UUID]
    var scorecards: [YamSheetScorecardRecord]
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    var enableSmallStraight: Bool
    var smallStraightScore: Int
    var name: String
    var enableExtraYamsBonus: Bool
    var enableChance: Bool
    var notationData: Data
    var createdAt: Date
    var comment: String
    var columns: Int
    var statusRaw: String
    var status: GameStatus?
    var turnOrder: [UUID]
    var currentTurnIndex: Int
    var lastFilledCountByPlayer: [UUID: Int]
    var requiredNotationKeys: [String]
    var optionalNotationKeys: [String]
    var startedAt: Date?
    var endedAt: Date?
}

struct YamSheetScorecardRecord: Codable, Hashable {
    var id: UUID
    var playerID: UUID
    var columns: Int
    var legacyExtraYams: [Bool]?
    var extraYamsAwarded: [Bool]
    var declaredYams: [String: Bool]
    var extraYamsSources: [String: String]
    var extraYamsAwards: [String: [String]]
    var ones: [Int]
    var twos: [Int]
    var threes: [Int]
    var fours: [Int]
    var fives: [Int]
    var sixes: [Int]
    var maxVals: [Int]
    var minVals: [Int]
    var brelan: [Int]
    var chance: [Int]
    var full: [Int]
    var carre: [Int]
    var yams: [Int]
    var suite: [Int]
    var petiteSuite: [Int]
    var locks: [String: Bool]
}

struct YamSheetNotationRecord: Codable, Hashable {
    var name: String
    var tooltipUpper: String?
    var tooltipMiddle: String?
    var tooltipBottom: String?
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    var middleMode: MiddleRuleMode
    var middleBonusSumThreshold: Int
    var middleBonusValue: Int
    var ruleBrelan: FigureRule
    var ruleChance: FigureRule
    var chanceEnabled: Bool?
    var ruleFull: FigureRule
    var ruleSuite: FigureRule
    var rulePetiteSuite: FigureRule
    var smallStraightEnabled: Bool
    var ruleCarre: FigureRule
    var ruleYams: FigureRule
    var suiteBigMode: SuiteBigMode
    var suiteBigFixed: Int
    var suiteBigFixed1to5: Int
    var suiteBigFixed2to6: Int
    var extraYamsBonusMode: ExtraYamsBonusMode
    var extraYamsBonusValue: Int
    var scoreHelpTexts: [String: String]? = nil
}

struct YamSheetSettingsRecord: Codable, Hashable {
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    var enableSmallStraight: Bool
    var smallStraightScore: Int
    var darkMode: Bool
    var scoreHelpEnabled: Bool? = nil
}

struct YamSheetInterfacePreferencesRecord: Codable, Hashable {
    var tintLight: Double
    var tintDark: Double
    var columnRecenterMode: Int
}

enum YamSheetBackupCoding {
    private static let maximumFileSize = 250_000_000

    static func encode(_ archive: YamSheetBackupArchive) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(archive)
    }

    static func decode(_ data: Data) throws -> YamSheetBackupArchive {
        guard data.count <= maximumFileSize else {
            throw YamSheetBackupError.invalidContent("le fichier dépasse la taille maximale autorisée")
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(YamSheetBackupArchive.self, from: data)
    }
}

extension UTType {
    static var yamSheetBackup: UTType {
        UTType(filenameExtension: "yamsheet", conformingTo: .json) ?? .json
    }
}

struct YamSheetDataDocument: FileDocument {
    static var readableContentTypes: [UTType] {
        [.yamSheetBackup, .pdf, .data]
    }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw YamSheetBackupError.unreadableFile
        }
        self.data = data
    }

    func fileWrapper(configuration _: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

enum YamSheetBackupError: LocalizedError {
    case unreadableFile
    case invalidSignature
    case unsupportedVersion(Int)
    case invalidContent(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFile:
            return "Le fichier sélectionné ne peut pas être lu."
        case .invalidSignature:
            return "Ce fichier n’est pas une sauvegarde YamSheet valide."
        case let .unsupportedVersion(version):
            return "Cette sauvegarde utilise un format non pris en charge (version \(version))."
        case let .invalidContent(message):
            return "La sauvegarde est incomplète ou endommagée : \(message)"
        }
    }
}

enum YamSheetBackupValidator {
    static func validate(_ archive: YamSheetBackupArchive) throws {
        guard archive.metadata.magic == YamSheetBackupMetadata.expectedMagic else {
            throw YamSheetBackupError.invalidSignature
        }
        guard archive.metadata.formatVersion == YamSheetBackupMetadata.currentFormatVersion else {
            throw YamSheetBackupError.unsupportedVersion(archive.metadata.formatVersion)
        }
        guard archive.players.count <= 100_000,
              archive.games.count <= 100_000,
              archive.notations.count <= 10_000 else {
            throw YamSheetBackupError.invalidContent("le fichier contient trop d’éléments")
        }

        try validateScope(archive)

        let playerIDs = archive.players.map(\.id)
        guard Set(playerIDs).count == playerIDs.count else {
            throw YamSheetBackupError.invalidContent("des joueurs sont présents plusieurs fois")
        }

        let gameIDs = archive.games.map(\.id)
        guard Set(gameIDs).count == gameIDs.count else {
            throw YamSheetBackupError.invalidContent("des parties sont présentes plusieurs fois")
        }

        let scorecardIDs = archive.games.flatMap(\.scorecards).map(\.id)
        guard Set(scorecardIDs).count == scorecardIDs.count else {
            throw YamSheetBackupError.invalidContent("des feuilles de score sont présentes plusieurs fois")
        }

        let knownPlayers = Set(playerIDs)
        for game in archive.games {
            guard game.columns > 0, game.columns <= 100 else {
                throw YamSheetBackupError.invalidContent("une partie possède un nombre de colonnes incorrect")
            }
            guard game.currentTurnIndex >= 0 else {
                throw YamSheetBackupError.invalidContent("une partie possède un tour actif incorrect")
            }
            if !game.turnOrder.isEmpty {
                guard game.currentTurnIndex < game.turnOrder.count else {
                    throw YamSheetBackupError.invalidContent("une partie possède un tour actif hors limites")
                }
            }
            guard (try? JSONDecoder().decode(NotationSnapshot.self, from: game.notationData)) != nil else {
                throw YamSheetBackupError.invalidContent("la notation d’une partie est illisible")
            }

            let referencedPlayers = Set(game.participantIDs)
                .union(game.turnOrder)
                .union(game.scorecards.map(\.playerID))
            guard referencedPlayers.isSubset(of: knownPlayers) else {
                throw YamSheetBackupError.invalidContent("un joueur associé à une partie est manquant")
            }

            for scorecard in game.scorecards {
                try validate(scorecard)
            }
        }

        if let preferences = archive.interfacePreferences {
            guard (0...1).contains(preferences.tintLight),
                  (0...1).contains(preferences.tintDark),
                  (0...2).contains(preferences.columnRecenterMode) else {
                throw YamSheetBackupError.invalidContent("les préférences d’interface sont incorrectes")
            }
        }
    }

    private static func validateScope(_ archive: YamSheetBackupArchive) throws {
        switch archive.metadata.scope {
        case .players:
            guard archive.notations.isEmpty,
                  archive.settings == nil,
                  archive.interfacePreferences == nil else {
                throw YamSheetBackupError.invalidContent(
                    "le contenu ne correspond pas à un export de joueurs"
                )
            }
        case .games:
            guard archive.playerStatistics.isEmpty,
                  archive.notations.isEmpty,
                  archive.settings == nil,
                  archive.interfacePreferences == nil else {
                throw YamSheetBackupError.invalidContent(
                    "le contenu ne correspond pas à un export de parties"
                )
            }
        case .notations:
            guard archive.players.isEmpty,
                  archive.playerStatistics.isEmpty,
                  archive.games.isEmpty,
                  archive.settings == nil,
                  archive.interfacePreferences == nil else {
                throw YamSheetBackupError.invalidContent(
                    "le contenu ne correspond pas à un export de notations"
                )
            }
        case .full:
            break
        }
    }

    private static func validate(_ scorecard: YamSheetScorecardRecord) throws {
        guard scorecard.columns > 0, scorecard.columns <= 100 else {
            throw YamSheetBackupError.invalidContent("une feuille de score possède un nombre de colonnes incorrect")
        }

        let scoreArrays = [
            scorecard.ones, scorecard.twos, scorecard.threes,
            scorecard.fours, scorecard.fives, scorecard.sixes,
            scorecard.maxVals, scorecard.minVals, scorecard.brelan,
            scorecard.chance, scorecard.full, scorecard.carre,
            scorecard.yams, scorecard.suite, scorecard.petiteSuite
        ]
        guard scoreArrays.allSatisfy({ $0.count >= scorecard.columns }) else {
            throw YamSheetBackupError.invalidContent("une feuille de score contient des colonnes manquantes")
        }
    }
}

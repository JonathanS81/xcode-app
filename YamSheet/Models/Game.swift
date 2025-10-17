//
//  Game.swift
//  YamSheet
//
//  Created by Jonathan Sportiche on 28/08/2025.
//

import Foundation
import SwiftData

@Model
final class Game: Identifiable {
    // MARK: - Identité
    var id: UUID

    // MARK: - Compatibilité rétro (anciens champs possibles)
    // Ces champs n’existent plus dans ton code courant mais peuvent être présents
    // dans d’anciennes bases → ils doivent exister pour que SwiftData ouvre le store.
    @Attribute(originalName: "updatedAt")
    var legacy_updatedAt: Date?

    @Attribute(originalName: "winnerPlayerID")
    var legacy_winnerPlayerID: UUID?

    // MARK: - Participants et scorecards
    @Attribute(originalName: "participantIDs")
    private var participantIDsStorage: [UUID]?

    /// Participant IDs with safe fallback (never nil)
    @Transient
    var participantIDs: [UUID] {
        get { participantIDsStorage ?? [] }
        set { participantIDsStorage = newValue }
    }
    @Relationship(deleteRule: .cascade) var scorecards: [Scorecard] = []

    // MARK: - Paramètres figés au moment de la création
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    var enableSmallStraight: Bool
    var smallStraightScore: Int

    // Nom lisible de la partie
    var name: String = ""

    // Prime Extra Yams
    var enableExtraYamsBonus: Bool = true

    // Options de figures (par partie)
    var enableChance: Bool = true

    // Notation figée (snapshot JSON)
    var notationData: Data

    // MARK: - État
    var createdAt: Date
    var comment: String
    var columns: Int
    var statusRaw: String

    // MARK: - Turn Engine
    var status: GameStatus? = nil

    /// Toujours utiliser ce getter/setter pour lire/écrire le statut
    var statusOrDefault: GameStatus {
        get { status ?? .inProgress }
        set { status = newValue }
    }

    /// Ordre de passage des joueurs (IDs stables)
    @Attribute(originalName: "turnOrder")
    private var turnOrderStorage: [UUID]?

    /// Stable play order (never nil)
    @Transient
    var turnOrder: [UUID] {
        get { turnOrderStorage ?? participantIDs }
        set { turnOrderStorage = newValue }
    }

    /// Index du joueur actif dans `turnOrder`
    var currentTurnIndex: Int = 0

    // --- Snapshot "1 case par tour": stockage en Data + propriété calculée ---
    @Attribute(.externalStorage)
    var lastFilledCountSnapshotData: Data? = nil

    var lastFilledCountByPlayer: [UUID: Int] {
        get {
            guard let data = lastFilledCountSnapshotData else { return [:] }
            return (try? JSONDecoder().decode([UUID: Int].self, from: data)) ?? [:]
        }
        set {
            lastFilledCountSnapshotData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Cases obligatoires (figées selon options)
    @Attribute(originalName: "requiredNotationKeys")
    private var requiredNotationKeysStorage: [String]?

    /// Required notation keys (never nil)
    @Transient
    var requiredNotationKeys: [String] {
        get { requiredNotationKeysStorage ?? [] }
        set { requiredNotationKeysStorage = newValue }
    }

    /// Cases optionnelles (ex: prime Yams supplémentaire)
    @Attribute(originalName: "optionalNotationKeys")
    private var optionalNotationKeysStorage: [String]?

    /// Optional notation keys (never nil)
    @Transient
    var optionalNotationKeys: [String] {
        get { optionalNotationKeysStorage ?? [] }
        set { optionalNotationKeysStorage = newValue }
    }

    /// Dates de partie
    var startedAt: Date? = nil
    var endedAt: Date? = nil

    // MARK: - Helpers JSON
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // MARK: - Fallback pour les anciennes parties
    private func safeDefaultNotation() -> NotationSnapshot {
        NotationSnapshot(
            name: "Par défaut",
            tooltipUpper: "Atteindre \(upperBonusThreshold) en haut donne +\(upperBonusValue).",
            tooltipMiddle: "Multiplier : (Max − Min) × nombre d’As.",
            tooltipBottom: "Figures calculées selon la saisie (somme/prime).",
            upperBonusThreshold: upperBonusThreshold,
            upperBonusValue: upperBonusValue,
            middleMode: .multiplier,
            middleBonusSumThreshold: 50,
            middleBonusValue: 30,
            ruleBrelan: FigureRule(mode: .raw),
            ruleChance: FigureRule(mode: .raw),
            ruleFull: FigureRule(mode: .rawPlusFixed, fixedValue: 30),
            ruleSuite: FigureRule(mode: .fixed, fixedValue: 0),
            rulePetiteSuite: FigureRule(mode: .fixed, fixedValue: enableSmallStraight ? smallStraightScore : 0),
            ruleCarre: FigureRule(mode: .rawPlusFixed, fixedValue: 40),
            ruleYams: FigureRule(mode: .rawPlusFixed, fixedValue: 50),
            suiteBigMode: .splitFixed,
            suiteBigFixed: 0,
            suiteBigFixed1to5: 15,
            suiteBigFixed2to6: 20,
            extraYamsBonusEnabled: false,
            extraYamsBonusValue: 0
        )
    }

    // MARK: - Notation calculée
    var notation: NotationSnapshot {
        if !notationData.isEmpty,
           let snap = try? Game.decoder.decode(NotationSnapshot.self, from: notationData) {
            return snap
        } else {
            let fallback = safeDefaultNotation()
            notationData = (try? Game.encoder.encode(fallback)) ?? Data()
            return fallback
        }
    }

    // MARK: - Init
    init(settings: AppSettings, notation: NotationSnapshot, columns: Int = 1, comment: String = "") {
        self.id = UUID()
        self.upperBonusThreshold = settings.upperBonusThreshold
        self.upperBonusValue = settings.upperBonusValue
        self.enableSmallStraight = settings.enableSmallStraight
        self.smallStraightScore = settings.smallStraightScore
        self.notationData = (try? JSONEncoder().encode(notation)) ?? Data()
        self.createdAt = Date()
        self.comment = comment
        self.columns = columns
        self.statusRaw = GameStatus.inProgress.rawValue
    }
}

// MARK: - Extension création partie
extension Game {
    func applyCreationOptions(
        name: String,
        enableChance: Bool,
        enableSmallStraight: Bool,
        notation: Notation
    ) {
        self.name = name
        self.enableChance = enableChance
        self.enableSmallStraight = enableSmallStraight
        let snap = notation.snapshot()
        self.notationData = (try? JSONEncoder().encode(snap)) ?? Data()
    }
}

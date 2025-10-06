import Foundation
import SwiftData

@Model
final class Game: Identifiable {
    var id: UUID
    
    var participantIDs: [UUID] = []

    
    // MARK: - Turn Engine (stored properties)
    
    
    
    // Paramètres figés au moment de la création (compat existante)
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    var enableSmallStraight: Bool
    var smallStraightScore: Int
    
    // Nom lisible de la partie
    var name: String = ""

    //Prime Extra Yams
    var enableExtraYamsBonus: Bool = true

    // Options de figures (par partie)
    var enableChance: Bool = true
    // (tu as déjà enableSmallStraight d’après GameDetailView)
    
    // Notation figée (snapshot JSON)
    var notationData: Data
    
    // State
    var createdAt: Date
    var comment: String
    var columns: Int
    var statusRaw: String
    
    // Relationship
    @Relationship(deleteRule: .cascade) var scorecards: [Scorecard] = []
    
    // MARK: - Turn Engine (stored properties)

    var status: GameStatus? = nil

    /// Toujours utiliser ce getter/setter pour lire/écrire le statut
    var statusOrDefault: GameStatus {
        get { status ?? .inProgress }
        set { status = newValue }
    }

    /// Ordre de passage des joueurs (IDs stables)
    var turnOrder: [UUID] = [] as [UUID]             // annotation explicite

    /// Index du joueur actif dans `turnOrder`
    var currentTurnIndex: Int = 0

    // --- Snapshot "1 case par tour": stockage en Data + propriété calculée ---
    @Attribute(.externalStorage)
    var lastFilledCountSnapshotData: Data? = nil

    var lastFilledCountByPlayer: [UUID: Int] {
        get {
            guard let data = lastFilledCountSnapshotData else { return [:] }
            // On décode un dictionnaire [UUID: Int]; fallback sur [:] si échec
            return (try? JSONDecoder().decode([UUID: Int].self, from: data)) ?? [:]
        }
        set {
            lastFilledCountSnapshotData = try? JSONEncoder().encode(newValue)
        }
    }

    /// Cases obligatoires (figées selon options)
    var requiredNotationKeys: [String] = [] as [String]

    /// Cases optionnelles (ex: prime Yams supplémentaire)
    var optionalNotationKeys: [String] = [] as [String]

    /// Dates
    var startedAt: Date? = nil
    var endedAt: Date? = nil

    
    
    // Helpers JSON
    // Helpers JSON (sans force-unwrap)
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    // Fallback pour les anciennes parties (notationData vide / illisible)
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
            // Règles raisonnables par défaut
            ruleBrelan: FigureRule(mode: .raw),
            ruleChance: FigureRule(mode: .raw),
            ruleFull: FigureRule(mode: .rawPlusFixed, fixedValue: 30),
            ruleSuite: FigureRule(mode: .fixed, fixedValue: 0), // non utilisé avec la logique SuiteBig
            rulePetiteSuite: FigureRule(mode: .fixed, fixedValue: enableSmallStraight ? smallStraightScore : 0),
            ruleCarre: FigureRule(mode: .rawPlusFixed, fixedValue: 40),
            ruleYams: FigureRule(mode: .rawPlusFixed, fixedValue: 50),
            // Grande suite : 1–5 et 2–6 distinctes
            suiteBigMode: .splitFixed,
            suiteBigFixed: 0,          // ignoré en split
            suiteBigFixed1to5: 15,
            suiteBigFixed2to6: 20,
            // Bonus Yams sup désactivé par défaut
            extraYamsBonusEnabled: false,
            extraYamsBonusValue: 0
        )
    }

    // Notation figée pour la partie (avec upgrade transparent)
    var notation: NotationSnapshot {
        if !notationData.isEmpty,
           let snap = try? Game.decoder.decode(NotationSnapshot.self, from: notationData) {
            return snap
        } else {
            let fallback = safeDefaultNotation()
            // Upgrade : on persiste un snapshot par défaut,
            // il sera sauvegardé lors d’un prochain save() du ModelContext.
            notationData = (try? Game.encoder.encode(fallback)) ?? Data()
            return fallback
        }
    }

    
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

import Foundation

extension Game {
    /// Applique les options de création et fige la notation pour la partie
    func applyCreationOptions(
        name: String,
        enableChance: Bool,
        enableSmallStraight: Bool,
        notation: Notation
    ) {
        self.name = name
        self.enableChance = enableChance
        self.enableSmallStraight = enableSmallStraight

        // On fige la notation (snapshot) dans la partie
        let snap = notation.snapshot()
        if let data = try? JSONEncoder().encode(snap) {
            self.notationData = data
        } else {
            self.notationData = Data()
        }
    }
}





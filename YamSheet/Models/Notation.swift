//
//  Notation.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import Foundation
import SwiftData
import SwiftUI

enum ScorecardBackgroundMode: String, Codable, CaseIterable, Identifiable {
    case standard
    case color
    case photo

    var id: String { rawValue }

    var label: String {
        switch self {
        case .standard: return "Standard"
        case .color: return "Couleur"
        case .photo: return "Photo"
        }
    }
}

/// Apparence optionnelle de la feuille de score.
/// Une valeur absente correspond toujours au fond système historique.
struct ScorecardAppearance: Codable, Hashable {
    var mode: ScorecardBackgroundMode = .standard
    var colorData: Data? = nil
    var imageData: Data? = nil
    var intensity: Double = 0.22

    static let standard = ScorecardAppearance()

    var normalizedIntensity: Double {
        min(max(intensity, 0.05), 1.00)
    }

    var color: Color {
        get {
            guard let colorData,
                  let decoded = try? JSONDecoder().decode(ColorCodable.self, from: colorData) else {
                return .accentColor
            }
            return decoded.color
        }
        set {
            colorData = try? JSONEncoder().encode(ColorCodable(newValue))
        }
    }
}

// Règle pour la section du milieu
enum MiddleRuleMode: String, Codable, CaseIterable, Identifiable {
    case multiplier      // (Max - Min) * (#As)
    case bonusGate       // si Max > Min ET Max+Min >= seuil => +bonus
    var id: String { rawValue }
}

/// Résultat de la section milieu lorsque Max n'est pas strictement supérieur à Min.
enum MiddleInvalidPairMode: String, Codable, CaseIterable, Identifiable {
    case zeroSection
    case keepSum

    var id: String { rawValue }

    var label: String {
        switch self {
        case .zeroSection: return "Section à zéro"
        case .keepSum: return "Conserver Max + Min"
        }
    }
}

// Mode de calcul pour les figures de la section basse
enum BottomRuleMode: String, Codable, CaseIterable, Identifiable {
    case raw            // valeur saisie telle quelle
    case fixed          // valeur fixe si > 0 (marquée), 0 si barrée
    case rawPlusFixed   // valeur saisie + prime fixe
    case rawTimes       // valeur saisie * multiplicateur
    var id: String { rawValue }
}

struct FigureRule: Codable, Hashable {
    var mode: BottomRuleMode
    var fixedValue: Int     // utilisé pour fixed (valeur), ou pour rawPlusFixed (prime)
    var multiplier: Int     // utilisé pour rawTimes (>=1)
    var tooltip: String?
    
    init(mode: BottomRuleMode = .raw, fixedValue: Int = 0, multiplier: Int = 1, tooltip: String? = nil) {
        self.mode = mode
        self.fixedValue = fixedValue
        self.multiplier = max(1, multiplier)
        self.tooltip = tooltip
    }
}

private func defaultFigureHelpText(
    for key: ScoreHelpKey,
    rule: FigureRule
) -> String? {
    let diceDescription: String
    switch key {
    case .carre:
        diceDescription = "les quatre dés constituant le Carré"
    case .brelan, .chance, .full, .yams:
        diceDescription = "les cinq dés"
    case .suite, .petiteSuite:
        diceDescription = "les dés constituant la suite"
    default:
        return nil
    }

    switch rule.mode {
    case .fixed:
        return "La figure rapporte une valeur fixe de \(rule.fixedValue) points lorsqu’elle est réalisée."
    case .raw:
        return "Additionnez \(diceDescription)."
    case .rawPlusFixed:
        return "Additionnez \(diceDescription), puis ajoutez une prime de \(rule.fixedValue) points."
    case .rawTimes:
        return "Additionnez \(diceDescription), puis multipliez le résultat par \(rule.multiplier)."
    }
}
enum SuiteBigMode: String, Codable, CaseIterable, Identifiable {
    case singleFixed   // une valeur fixe pour n’importe quelle grande suite
    case splitFixed    // valeur fixe pour 1–5 et valeur fixe pour 2–6
    var id: String { rawValue }
}

enum ExtraYamsBonusMode: String, Codable, CaseIterable, Identifiable {
    case disabled
    case single
    case multiple

    var id: String { rawValue }

    var label: String {
        switch self {
        case .disabled: return "Non"
        case .single: return "Oui, unique"
        case .multiple: return "Oui, multiple"
        }
    }
}

enum BuiltInNotationID: String, Codable, CaseIterable, Identifiable {
    // La valeur persistée reste inchangée pour transformer sans doublon
    // le prototype « Yahtzee standard » déjà installé en « Standard ».
    case standard = "yamsheet.yahtzee-standard.v1"

    var id: String { rawValue }
}

/// Dates de référence utilisées uniquement lorsque l'ancienne version ne
/// connaissait pas encore la date réelle de création d'une notation.
enum NotationCreationDatePolicy {
    static let legacyV1 = Date(timeIntervalSince1970: 1_780_272_000)

    static func fallback(
        sourceAppVersion: String,
        exportedAt: Date
    ) -> Date {
        let majorVersion = Int(sourceAppVersion.split(separator: ".").first ?? "")
        return majorVersion == 1 ? legacyV1 : exportedAt
    }
}

enum BottomScoreField: String, Codable, CaseIterable, Identifiable {
    case brelan
    case chance
    case full
    case suite
    case petiteSuite
    case carre
    case yams

    var id: String { rawValue }
}

/// Organisation visible d'une notation.
///
/// Cette valeur reste optionnelle dans les modèles persistés et les snapshots :
/// une partie ou une notation créée avant la V2 conserve donc toutes ses sections.
struct NotationVisibility: Codable, Hashable {
    var upperSectionEnabled: Bool
    var middleSectionEnabled: Bool
    var bottomSectionEnabled: Bool
    var brelanEnabled: Bool
    var fullEnabled: Bool
    var suiteEnabled: Bool
    var carreEnabled: Bool
    var yamsEnabled: Bool

    init(
        upperSectionEnabled: Bool = true,
        middleSectionEnabled: Bool = true,
        bottomSectionEnabled: Bool = true,
        brelanEnabled: Bool = true,
        fullEnabled: Bool = true,
        suiteEnabled: Bool = true,
        carreEnabled: Bool = true,
        yamsEnabled: Bool = true
    ) {
        self.upperSectionEnabled = upperSectionEnabled
        self.middleSectionEnabled = middleSectionEnabled
        self.bottomSectionEnabled = bottomSectionEnabled
        self.brelanEnabled = brelanEnabled
        self.fullEnabled = fullEnabled
        self.suiteEnabled = suiteEnabled
        self.carreEnabled = carreEnabled
        self.yamsEnabled = yamsEnabled
    }

    static let allVisible = NotationVisibility()

    func isEnabled(_ field: BottomScoreField) -> Bool {
        guard bottomSectionEnabled else { return false }
        switch field {
        case .brelan: return brelanEnabled
        case .chance, .petiteSuite: return true
        case .full: return fullEnabled
        case .suite: return suiteEnabled
        case .carre: return carreEnabled
        case .yams: return yamsEnabled
        }
    }
}

enum ScoreHelpKey: String, Codable, CaseIterable, Identifiable {
    case sectionUpper
    case ones
    case twos
    case threes
    case fours
    case fives
    case sixes
    case sectionMiddle
    case max
    case min
    case sectionBottom
    case brelan
    case chance
    case full
    case suite
    case petiteSuite
    case carre
    case yams
    case extraYams

    var id: String { rawValue }
}

// Les règles compactées (snapshot) qu’on figera sur Game
struct NotationSnapshot: Codable {
    // Nom + tooltips globaux
    var name: String
    var comment: String? = nil
    var tooltipUpper: String?
    var tooltipMiddle: String?
    var tooltipBottom: String?
    
    // Section haute
    var upperBonusThreshold: Int
    var upperBonusValue: Int
    
    // Section milieu
    var middleMode: MiddleRuleMode
    var middleBonusSumThreshold: Int  // utilisé seulement si .bonusGate
    var middleBonusValue: Int         // utilisé seulement si .bonusGate
    var middleInvalidPairMode: MiddleInvalidPairMode? = nil

    /// Les parties créées avant l'ajout de cette option utilisaient déjà Max + Min.
    var resolvedMiddleInvalidPairMode: MiddleInvalidPairMode {
        middleInvalidPairMode ?? .keepSum
    }
    
    // Section basse : règles par figure
    var ruleBrelan: FigureRule
    var ruleChance: FigureRule
    var chanceEnabled: Bool? = nil
    var ruleFull: FigureRule
    var ruleSuite: FigureRule
    var rulePetiteSuite: FigureRule
    var smallStraightEnabled: Bool? = nil
    var ruleCarre: FigureRule
    var ruleYams: FigureRule

    var resolvedSmallStraightEnabled: Bool {
        smallStraightEnabled ?? true
    }

    var resolvedChanceEnabled: Bool {
        chanceEnabled ?? true
    }
    
    // ...
    var suiteBigMode: SuiteBigMode
    var suiteBigFixed: Int
    var suiteBigFixed1to5: Int
    var suiteBigFixed2to6: Int
    // ...
    
    // Bonus Yams supplémentaire (optionnel)
    var extraYamsBonusEnabled: Bool
    var extraYamsBonusValue: Int
    var extraYamsBonusMode: ExtraYamsBonusMode? = nil
    var scoreHelpTexts: [String: String]? = nil
    var visibility: NotationVisibility? = nil
    var scorecardAppearance: ScorecardAppearance? = nil

    var resolvedScorecardAppearance: ScorecardAppearance {
        scorecardAppearance ?? .standard
    }

    var resolvedVisibility: NotationVisibility {
        visibility ?? .allVisible
    }

    var upperSectionIsEnabled: Bool {
        resolvedVisibility.upperSectionEnabled
    }

    var middleSectionIsEnabled: Bool {
        resolvedVisibility.middleSectionEnabled
    }

    var bottomSectionIsEnabled: Bool {
        resolvedVisibility.bottomSectionEnabled
    }

    func isBottomFieldEnabled(_ field: BottomScoreField) -> Bool {
        guard resolvedVisibility.isEnabled(field) else { return false }
        switch field {
        case .chance: return resolvedChanceEnabled
        case .petiteSuite: return resolvedSmallStraightEnabled
        default: return true
        }
    }

    var requiredScoreKeys: [String] {
        var keys: [String] = []
        if upperSectionIsEnabled {
            keys += ["ones", "twos", "threes", "fours", "fives", "sixes"]
        }
        if middleSectionIsEnabled {
            keys += ["max", "min"]
        }
        if bottomSectionIsEnabled {
            if isBottomFieldEnabled(.brelan) { keys.append("brelan") }
            if isBottomFieldEnabled(.chance) { keys.append("chance") }
            if isBottomFieldEnabled(.full) { keys.append("full") }
            if isBottomFieldEnabled(.suite) { keys.append("suite") }
            if isBottomFieldEnabled(.petiteSuite) { keys.append("petiteSuite") }
            if isBottomFieldEnabled(.carre) { keys.append("carre") }
            if isBottomFieldEnabled(.yams) { keys.append("yams") }
        }
        return keys
    }

    var resolvedExtraYamsBonusMode: ExtraYamsBonusMode {
        extraYamsBonusMode ?? (extraYamsBonusEnabled ? .single : .disabled)
    }

    func helpText(for key: ScoreHelpKey) -> String? {
        if key == .max || key == .min {
            return nil
        }

        if key == .sectionMiddle {
            return StatsEngine.middleTooltip(
                mode: middleMode,
                threshold: middleBonusSumThreshold,
                bonus: middleBonusValue,
                invalidPairMode: resolvedMiddleInvalidPairMode
            )
        }

        if let text = normalizedHelpText(scoreHelpTexts?[key.rawValue]) {
            return text
        }

        switch key {
        case .sectionUpper:
            return normalizedHelpText(tooltipUpper)
        case .sectionBottom:
            return normalizedHelpText(tooltipBottom)
        case .brelan:
            return normalizedHelpText(ruleBrelan.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleBrelan)
        case .chance:
            return normalizedHelpText(ruleChance.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleChance)
        case .full:
            return normalizedHelpText(ruleFull.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleFull)
        case .suite:
            return normalizedHelpText(ruleSuite.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleSuite)
        case .petiteSuite:
            return normalizedHelpText(rulePetiteSuite.tooltip)
                ?? defaultFigureHelpText(for: key, rule: rulePetiteSuite)
        case .carre:
            return normalizedHelpText(ruleCarre.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleCarre)
        case .yams:
            return normalizedHelpText(ruleYams.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleYams)
        default:
            return nil
        }
    }

    private func normalizedHelpText(_ text: String?) -> String? {
        let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }
}

@Model
final class Notation {

    // métadonnées
    var name: String = ""
    /// Optionnelle pour conserver la compatibilité avec les bases antérieures.
    var createdAt: Date? = nil
    var comment: String = ""
    var tooltipUpper: String? = nil
    var tooltipMiddle: String? = nil
    var tooltipBottom: String? = nil
    var scoreHelpTextsData: Data? = nil
    var builtInIdentifierRaw: String? = nil
    var visibilityData: Data? = nil
    @Attribute(.externalStorage) var scorecardAppearanceData: Data? = nil
    
    // section haute
    var upperBonusThreshold: Int = 63
    var upperBonusValue: Int = 35
    
    // section milieu
    var middleModeRaw: String = MiddleRuleMode.multiplier.rawValue   // MiddleRuleMode
    var middleBonusSumThreshold: Int = 50
    var middleBonusValue: Int = 30
    var middleInvalidPairModeRaw: String? = nil
    
    // section basse : règles encodées en JSON
    var ruleBrelanData: Data = Data()
    var ruleChanceData: Data = Data()
    var chanceEnabled: Bool? = nil
    var ruleFullData: Data = Data()
    var ruleSuiteData: Data = Data()
    var rulePetiteSuiteData: Data = Data()
    var smallStraightEnabled: Bool? = nil
    var ruleCarreData: Data = Data()
    var ruleYamsData: Data = Data()

    // Spécifique à la grande suite (5 dés)
    var suiteBigModeRaw: String = SuiteBigMode.singleFixed.rawValue
    var suiteBigFixed: Int = 15           // utilisé si .singleFixed
    var suiteBigFixed1to5: Int = 15       // utilisé si .splitFixed (1–5)
    var suiteBigFixed2to6: Int = 20       // utilisé si .splitFixed (2–6)

    var suiteBigMode: SuiteBigMode {
        get { SuiteBigMode(rawValue: suiteBigModeRaw) ?? .singleFixed }
        set { suiteBigModeRaw = newValue.rawValue }
    }
    
    // Bonus Yams en plus
    var extraYamsBonusEnabled: Bool = false
    var extraYamsBonusValue: Int = 0
    var extraYamsBonusModeRaw: String? = nil

    var extraYamsBonusMode: ExtraYamsBonusMode {
        get {
            if let raw = extraYamsBonusModeRaw,
               let mode = ExtraYamsBonusMode(rawValue: raw) {
                return mode
            }
            return extraYamsBonusEnabled ? .single : .disabled
        }
        set {
            extraYamsBonusModeRaw = newValue.rawValue
            extraYamsBonusEnabled = newValue != .disabled
        }
    }
    
    // Helpers d’encodage (statiques pour pouvoir être appelés dans init AVANT que self soit complet)
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static func encRule(_ v: FigureRule) -> Data { (try? encoder.encode(v)) ?? Data() }
    private static func decRule(_ d: Data) -> FigureRule { (try? decoder.decode(FigureRule.self, from: d)) ?? FigureRule() }
    private static func encHelpTexts(_ value: [String: String]) -> Data? {
        try? encoder.encode(value)
    }
    private static func decHelpTexts(_ data: Data?) -> [String: String] {
        guard let data else { return [:] }
        return (try? decoder.decode([String: String].self, from: data)) ?? [:]
    }

    private static func encVisibility(_ value: NotationVisibility) -> Data? {
        try? encoder.encode(value)
    }

    private static func decVisibility(_ data: Data?) -> NotationVisibility {
        guard let data else { return .allVisible }
        return (try? decoder.decode(NotationVisibility.self, from: data)) ?? .allVisible
    }

    private static func encAppearance(_ value: ScorecardAppearance) -> Data? {
        try? encoder.encode(value)
    }

    private static func decAppearance(_ data: Data?) -> ScorecardAppearance {
        guard let data else { return .standard }
        return (try? decoder.decode(ScorecardAppearance.self, from: data)) ?? .standard
    }

    
    // Computed
    var middleMode: MiddleRuleMode {
        get { MiddleRuleMode(rawValue: middleModeRaw) ?? .multiplier }
        set { middleModeRaw = newValue.rawValue }
    }

    var middleInvalidPairMode: MiddleInvalidPairMode {
        get {
            guard let raw = middleInvalidPairModeRaw else { return .keepSum }
            return MiddleInvalidPairMode(rawValue: raw) ?? .keepSum
        }
        set { middleInvalidPairModeRaw = newValue.rawValue }
    }

    var builtInIdentifier: BuiltInNotationID? {
        get { builtInIdentifierRaw.flatMap(BuiltInNotationID.init(rawValue:)) }
        set { builtInIdentifierRaw = newValue?.rawValue }
    }

    var isBuiltIn: Bool { builtInIdentifier != nil }

    var visibility: NotationVisibility {
        get { Self.decVisibility(visibilityData) }
        set { visibilityData = Self.encVisibility(newValue) }
    }

    var scorecardAppearance: ScorecardAppearance {
        get { Self.decAppearance(scorecardAppearanceData) }
        set {
            scorecardAppearanceData = newValue == .standard
                ? nil
                : Self.encAppearance(newValue)
        }
    }
    
    var ruleBrelan: FigureRule {
        get { Self.decRule(ruleBrelanData) }
        set { ruleBrelanData = Self.encRule(newValue) }
    }
    var ruleChance: FigureRule {
        get { Self.decRule(ruleChanceData) }
        set { ruleChanceData = Self.encRule(newValue) }
    }
    var isChanceEnabled: Bool {
        get { chanceEnabled ?? true }
        set { chanceEnabled = newValue }
    }
    var ruleFull: FigureRule {
        get { Self.decRule(ruleFullData) }
        set { ruleFullData = Self.encRule(newValue) }
    }
    var ruleSuite: FigureRule {
        get { Self.decRule(ruleSuiteData) }
        set { ruleSuiteData = Self.encRule(newValue) }
    }
    var rulePetiteSuite: FigureRule {
        get { Self.decRule(rulePetiteSuiteData) }
        set { rulePetiteSuiteData = Self.encRule(newValue) }
    }
    var isSmallStraightEnabled: Bool {
        get { smallStraightEnabled ?? true }
        set { smallStraightEnabled = newValue }
    }
    var ruleCarre: FigureRule {
        get { Self.decRule(ruleCarreData) }
        set { ruleCarreData = Self.encRule(newValue) }
    }
    var ruleYams: FigureRule {
        get { Self.decRule(ruleYamsData) }
        set { ruleYamsData = Self.encRule(newValue) }
    }

    var scoreHelpTexts: [String: String] {
        get { Self.decHelpTexts(scoreHelpTextsData) }
        set { scoreHelpTextsData = newValue.isEmpty ? nil : Self.encHelpTexts(newValue) }
    }

    func helpTextValue(for key: ScoreHelpKey) -> String {
        if key == .max || key == .min {
            return ""
        }

        if key == .sectionMiddle {
            return StatsEngine.middleTooltip(
                mode: middleMode,
                threshold: middleBonusSumThreshold,
                bonus: middleBonusValue,
                invalidPairMode: middleInvalidPairMode
            )
        }

        if let text = normalizedHelpText(scoreHelpTexts[key.rawValue]) {
            return text
        }

        switch key {
        case .sectionUpper:
            return normalizedHelpText(tooltipUpper) ?? ""
        case .sectionBottom:
            return normalizedHelpText(tooltipBottom) ?? ""
        case .brelan:
            return normalizedHelpText(ruleBrelan.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleBrelan)
                ?? ""
        case .chance:
            return normalizedHelpText(ruleChance.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleChance)
                ?? ""
        case .full:
            return normalizedHelpText(ruleFull.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleFull)
                ?? ""
        case .suite:
            return normalizedHelpText(ruleSuite.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleSuite)
                ?? ""
        case .petiteSuite:
            return normalizedHelpText(rulePetiteSuite.tooltip)
                ?? defaultFigureHelpText(for: key, rule: rulePetiteSuite)
                ?? ""
        case .carre:
            return normalizedHelpText(ruleCarre.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleCarre)
                ?? ""
        case .yams:
            return normalizedHelpText(ruleYams.tooltip)
                ?? defaultFigureHelpText(for: key, rule: ruleYams)
                ?? ""
        default:
            return ""
        }
    }

    func setHelpText(_ text: String, for key: ScoreHelpKey) {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        var values = scoreHelpTexts
        if normalized.isEmpty {
            values.removeValue(forKey: key.rawValue)
        } else {
            values[key.rawValue] = text
        }
        scoreHelpTexts = values

        switch key {
        case .sectionUpper:
            tooltipUpper = normalized.isEmpty ? nil : text
        case .sectionMiddle:
            tooltipMiddle = normalized.isEmpty ? nil : text
        case .sectionBottom:
            tooltipBottom = normalized.isEmpty ? nil : text
        case .brelan:
            var rule = ruleBrelan
            rule.tooltip = normalized.isEmpty ? nil : text
            ruleBrelan = rule
        case .chance:
            var rule = ruleChance
            rule.tooltip = normalized.isEmpty ? nil : text
            ruleChance = rule
        case .full:
            var rule = ruleFull
            rule.tooltip = normalized.isEmpty ? nil : text
            ruleFull = rule
        case .suite:
            var rule = ruleSuite
            rule.tooltip = normalized.isEmpty ? nil : text
            ruleSuite = rule
        case .petiteSuite:
            var rule = rulePetiteSuite
            rule.tooltip = normalized.isEmpty ? nil : text
            rulePetiteSuite = rule
        case .carre:
            var rule = ruleCarre
            rule.tooltip = normalized.isEmpty ? nil : text
            ruleCarre = rule
        case .yams:
            var rule = ruleYams
            rule.tooltip = normalized.isEmpty ? nil : text
            ruleYams = rule
        default:
            break
        }
    }

    private func normalizedHelpText(_ text: String?) -> String? {
        let normalized = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return normalized.isEmpty ? nil : normalized
    }

    
    init(
        name: String,
        createdAt: Date? = Date(),
        comment: String = "",
        tooltipUpper: String? = nil,
        tooltipMiddle: String? = nil,
        tooltipBottom: String? = nil,
        upperBonusThreshold: Int = 63,
        upperBonusValue: Int = 35,
        middleMode: MiddleRuleMode = .multiplier,
        middleBonusSumThreshold: Int = 50,
        middleBonusValue: Int = 30,
        middleInvalidPairMode: MiddleInvalidPairMode = .keepSum,
        ruleBrelan: FigureRule = FigureRule(),
        ruleChance: FigureRule = FigureRule(),
        chanceEnabled: Bool = true,
        ruleFull: FigureRule = FigureRule(mode: .rawPlusFixed, fixedValue: 30),
        ruleSuite: FigureRule = FigureRule(mode: .fixed, fixedValue: 15),
        rulePetiteSuite: FigureRule = FigureRule(mode: .fixed, fixedValue: 10),
        smallStraightEnabled: Bool = true,
        ruleCarre: FigureRule = FigureRule(mode: .rawPlusFixed, fixedValue: 40),
        ruleYams: FigureRule = FigureRule(mode: .rawPlusFixed, fixedValue: 50),
        extraYamsBonusEnabled: Bool = false,
        extraYamsBonusValue: Int = 0
    ) {
        self.name = name
        self.createdAt = createdAt
        self.comment = comment
        self.tooltipUpper = tooltipUpper
        self.tooltipMiddle = tooltipMiddle
        self.tooltipBottom = tooltipBottom
        self.upperBonusThreshold = upperBonusThreshold
        self.upperBonusValue = upperBonusValue
        self.middleModeRaw = middleMode.rawValue
        self.middleBonusSumThreshold = middleBonusSumThreshold
        self.middleBonusValue = middleBonusValue
        self.middleInvalidPairModeRaw = middleInvalidPairMode.rawValue
        self.ruleBrelanData = Self.encRule(ruleBrelan)
        self.ruleChanceData = Self.encRule(ruleChance)
        self.chanceEnabled = chanceEnabled
        self.ruleFullData   = Self.encRule(ruleFull)
        self.ruleSuiteData  = Self.encRule(ruleSuite)
        self.rulePetiteSuiteData = Self.encRule(rulePetiteSuite)
        self.smallStraightEnabled = smallStraightEnabled
        self.ruleCarreData  = Self.encRule(ruleCarre)
        self.ruleYamsData   = Self.encRule(ruleYams)
        self.suiteBigModeRaw = SuiteBigMode.singleFixed.rawValue
        self.suiteBigFixed = 15
        self.suiteBigFixed1to5 = 15
        self.suiteBigFixed2to6 = 20
        
        self.extraYamsBonusEnabled = extraYamsBonusEnabled
        self.extraYamsBonusValue = extraYamsBonusValue
        self.extraYamsBonusModeRaw = nil
    }
    

    
    
    // Snapshot pour figer dans Game
    func snapshot() -> NotationSnapshot {
        NotationSnapshot(
            name: name,
            comment: comment.isEmpty ? nil : comment,
            tooltipUpper: tooltipUpper,
            tooltipMiddle: tooltipMiddle,
            tooltipBottom: tooltipBottom,
            upperBonusThreshold: upperBonusThreshold,
            upperBonusValue: upperBonusValue,
            middleMode: middleMode,
            middleBonusSumThreshold: middleBonusSumThreshold,
            middleBonusValue: middleBonusValue,
            middleInvalidPairMode: middleInvalidPairMode,
            ruleBrelan: ruleBrelan,
            ruleChance: ruleChance,
            chanceEnabled: isChanceEnabled,
            ruleFull: ruleFull,
            ruleSuite: ruleSuite,
            rulePetiteSuite: rulePetiteSuite,
            smallStraightEnabled: isSmallStraightEnabled,
            ruleCarre: ruleCarre,
            ruleYams: ruleYams,
            // ← important : les champs SuiteBig APRÈS ruleYams
            suiteBigMode: suiteBigMode,
            suiteBigFixed: suiteBigFixed,
            suiteBigFixed1to5: suiteBigFixed1to5,
            suiteBigFixed2to6: suiteBigFixed2to6,
            // puis les bonus Yams
            extraYamsBonusEnabled: extraYamsBonusEnabled,
            extraYamsBonusValue: extraYamsBonusValue,
            extraYamsBonusMode: extraYamsBonusMode,
            scoreHelpTexts: scoreHelpTexts,
            visibility: visibility,
            scorecardAppearance: scorecardAppearance
        )
    }

    func duplicate(named duplicateName: String? = nil) -> Notation {
        let copy = Notation(
            name: duplicateName ?? "\(name) - copie",
            comment: comment,
            tooltipUpper: tooltipUpper,
            tooltipMiddle: tooltipMiddle,
            tooltipBottom: tooltipBottom,
            upperBonusThreshold: upperBonusThreshold,
            upperBonusValue: upperBonusValue,
            middleMode: middleMode,
            middleBonusSumThreshold: middleBonusSumThreshold,
            middleBonusValue: middleBonusValue,
            middleInvalidPairMode: middleInvalidPairMode,
            ruleBrelan: ruleBrelan,
            ruleChance: ruleChance,
            chanceEnabled: isChanceEnabled,
            ruleFull: ruleFull,
            ruleSuite: ruleSuite,
            rulePetiteSuite: rulePetiteSuite,
            smallStraightEnabled: isSmallStraightEnabled,
            ruleCarre: ruleCarre,
            ruleYams: ruleYams,
            extraYamsBonusEnabled: extraYamsBonusMode != .disabled,
            extraYamsBonusValue: extraYamsBonusValue
        )
        copy.suiteBigMode = suiteBigMode
        copy.suiteBigFixed = suiteBigFixed
        copy.suiteBigFixed1to5 = suiteBigFixed1to5
        copy.suiteBigFixed2to6 = suiteBigFixed2to6
        copy.extraYamsBonusMode = extraYamsBonusMode
        copy.scoreHelpTexts = scoreHelpTexts
        copy.visibility = visibility
        copy.scorecardAppearance = scorecardAppearance
        copy.builtInIdentifier = nil
        return copy
    }

}

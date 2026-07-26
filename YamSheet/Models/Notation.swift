//
//  Notation.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import Foundation
import SwiftData

// Règle pour la section du milieu
enum MiddleRuleMode: String, Codable, CaseIterable, Identifiable {
    case multiplier      // (Max - Min) * (#As)
    case bonusGate       // si Max > Min ET Max+Min >= seuil => +bonus
    var id: String { rawValue }
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

    var resolvedExtraYamsBonusMode: ExtraYamsBonusMode {
        extraYamsBonusMode ?? (extraYamsBonusEnabled ? .single : .disabled)
    }

    func helpText(for key: ScoreHelpKey) -> String? {
        if let text = normalizedHelpText(scoreHelpTexts?[key.rawValue]) {
            return text
        }

        switch key {
        case .sectionUpper:
            return normalizedHelpText(tooltipUpper)
        case .sectionMiddle:
            return normalizedHelpText(tooltipMiddle)
        case .sectionBottom:
            return normalizedHelpText(tooltipBottom)
        case .brelan:
            return normalizedHelpText(ruleBrelan.tooltip)
        case .chance:
            return normalizedHelpText(ruleChance.tooltip)
        case .full:
            return normalizedHelpText(ruleFull.tooltip)
        case .suite:
            return normalizedHelpText(ruleSuite.tooltip)
        case .petiteSuite:
            return normalizedHelpText(rulePetiteSuite.tooltip)
        case .carre:
            return normalizedHelpText(ruleCarre.tooltip)
        case .yams:
            return normalizedHelpText(ruleYams.tooltip)
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
    var tooltipUpper: String? = nil
    var tooltipMiddle: String? = nil
    var tooltipBottom: String? = nil
    var scoreHelpTextsData: Data? = nil
    
    // section haute
    var upperBonusThreshold: Int = 63
    var upperBonusValue: Int = 35
    
    // section milieu
    var middleModeRaw: String = MiddleRuleMode.multiplier.rawValue   // MiddleRuleMode
    var middleBonusSumThreshold: Int = 50
    var middleBonusValue: Int = 30
    
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

    
    // Computed
    var middleMode: MiddleRuleMode {
        get { MiddleRuleMode(rawValue: middleModeRaw) ?? .multiplier }
        set { middleModeRaw = newValue.rawValue }
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
        if let text = normalizedHelpText(scoreHelpTexts[key.rawValue]) {
            return text
        }

        switch key {
        case .sectionUpper:
            return normalizedHelpText(tooltipUpper) ?? ""
        case .sectionMiddle:
            return normalizedHelpText(tooltipMiddle) ?? ""
        case .sectionBottom:
            return normalizedHelpText(tooltipBottom) ?? ""
        case .brelan:
            return normalizedHelpText(ruleBrelan.tooltip) ?? ""
        case .chance:
            return normalizedHelpText(ruleChance.tooltip) ?? ""
        case .full:
            return normalizedHelpText(ruleFull.tooltip) ?? ""
        case .suite:
            return normalizedHelpText(ruleSuite.tooltip) ?? ""
        case .petiteSuite:
            return normalizedHelpText(rulePetiteSuite.tooltip) ?? ""
        case .carre:
            return normalizedHelpText(ruleCarre.tooltip) ?? ""
        case .yams:
            return normalizedHelpText(ruleYams.tooltip) ?? ""
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
        tooltipUpper: String? = nil,
        tooltipMiddle: String? = nil,
        tooltipBottom: String? = nil,
        upperBonusThreshold: Int = 63,
        upperBonusValue: Int = 35,
        middleMode: MiddleRuleMode = .multiplier,
        middleBonusSumThreshold: Int = 50,
        middleBonusValue: Int = 30,
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
        self.tooltipUpper = tooltipUpper
        self.tooltipMiddle = tooltipMiddle
        self.tooltipBottom = tooltipBottom
        self.upperBonusThreshold = upperBonusThreshold
        self.upperBonusValue = upperBonusValue
        self.middleModeRaw = middleMode.rawValue
        self.middleBonusSumThreshold = middleBonusSumThreshold
        self.middleBonusValue = middleBonusValue
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
            tooltipUpper: tooltipUpper,
            tooltipMiddle: tooltipMiddle,
            tooltipBottom: tooltipBottom,
            upperBonusThreshold: upperBonusThreshold,
            upperBonusValue: upperBonusValue,
            middleMode: middleMode,
            middleBonusSumThreshold: middleBonusSumThreshold,
            middleBonusValue: middleBonusValue,
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
            scoreHelpTexts: scoreHelpTexts
        )
    }

}

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
    var ruleFull: FigureRule
    var ruleSuite: FigureRule
    var rulePetiteSuite: FigureRule
    var ruleCarre: FigureRule
    var ruleYams: FigureRule
    
    // ...
    var suiteBigMode: SuiteBigMode
    var suiteBigFixed: Int
    var suiteBigFixed1to5: Int
    var suiteBigFixed2to6: Int
    // ...
    
    // Bonus Yams supplémentaire (optionnel)
    var extraYamsBonusEnabled: Bool
    var extraYamsBonusValue: Int
}

@Model
final class Notation {

    // métadonnées
    var name: String = ""
    var tooltipUpper: String? = nil
    var tooltipMiddle: String? = nil
    var tooltipBottom: String? = nil
    
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
    var ruleFullData: Data = Data()
    var ruleSuiteData: Data = Data()
    var rulePetiteSuiteData: Data = Data()
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
    
    // Helpers d’encodage (statiques pour pouvoir être appelés dans init AVANT que self soit complet)
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()
    private static func encRule(_ v: FigureRule) -> Data { (try? encoder.encode(v)) ?? Data() }
    private static func decRule(_ d: Data) -> FigureRule { (try? decoder.decode(FigureRule.self, from: d)) ?? FigureRule() }

    
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
    var ruleCarre: FigureRule {
        get { Self.decRule(ruleCarreData) }
        set { ruleCarreData = Self.encRule(newValue) }
    }
    var ruleYams: FigureRule {
        get { Self.decRule(ruleYamsData) }
        set { ruleYamsData = Self.encRule(newValue) }
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
        ruleFull: FigureRule = FigureRule(mode: .rawPlusFixed, fixedValue: 30),
        ruleSuite: FigureRule = FigureRule(mode: .fixed, fixedValue: 15),
        rulePetiteSuite: FigureRule = FigureRule(mode: .fixed, fixedValue: 10),
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
        self.ruleFullData   = Self.encRule(ruleFull)
        self.ruleSuiteData  = Self.encRule(ruleSuite)
        self.rulePetiteSuiteData = Self.encRule(rulePetiteSuite)
        self.ruleCarreData  = Self.encRule(ruleCarre)
        self.ruleYamsData   = Self.encRule(ruleYams)
        self.suiteBigModeRaw = SuiteBigMode.singleFixed.rawValue
        self.suiteBigFixed = 15
        self.suiteBigFixed1to5 = 15
        self.suiteBigFixed2to6 = 20
        
        self.extraYamsBonusEnabled = extraYamsBonusEnabled
        self.extraYamsBonusValue = extraYamsBonusValue
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
            ruleFull: ruleFull,
            ruleSuite: ruleSuite,
            rulePetiteSuite: rulePetiteSuite,
            ruleCarre: ruleCarre,
            ruleYams: ruleYams,
            // ← important : les champs SuiteBig APRÈS ruleYams
            suiteBigMode: suiteBigMode,
            suiteBigFixed: suiteBigFixed,
            suiteBigFixed1to5: suiteBigFixed1to5,
            suiteBigFixed2to6: suiteBigFixed2to6,
            // puis les bonus Yams
            extraYamsBonusEnabled: extraYamsBonusEnabled,
            extraYamsBonusValue: extraYamsBonusValue
        )
    }

}



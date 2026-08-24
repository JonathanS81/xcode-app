//
//  Game+TurnEngine.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//


import Foundation

enum FigureKind {
    case brelan, chance, full, suiteBig, petiteSuite, carre, yams
}

struct StatsEngine {
    //helper
    static func extraYamsBonusAmount(sc: Scorecard, game: Game, col: Int) -> Int {
        guard game.enableExtraYamsBonus,                        // partie
              game.notation.isBottomFieldEnabled(.yams),
              game.notation.extraYamsBonusValue > 0,            // notation (0 = off)
              game.extraYamsBonusMode != .disabled else {
            return 0
        }
        let awarded = sc.extraYamsAwardsCount(col: col)
        let effectiveCount = game.extraYamsBonusMode == .single
            ? min(1, awarded)
            : awarded
        return effectiveCount * game.notation.extraYamsBonusValue
    }

    // -1 => non rempli ; 0 => barré ; sinon valeur
    static func norm(_ v: Int) -> Int { max(0, v) }

    // MARK: - Upper
    static func upperTotal(sc: Scorecard, game: Game, col: Int) -> Int {
        guard game.notation.upperSectionIsEnabled else { return 0 }
        let u = [
            sc.ones[col], sc.twos[col], sc.threes[col],
            sc.fours[col], sc.fives[col], sc.sixes[col]
        ].map(norm).reduce(0, +)
        let bonus = (u >= game.notation.upperBonusThreshold) ? game.notation.upperBonusValue : 0
        return u + bonus
    }

    // MARK: - Middle
    static func middleTotal(sc: Scorecard, game: Game, col: Int) -> Int {
        guard game.notation.middleSectionIsEnabled else { return 0 }
        let maxV = norm(sc.maxVals[col])
        let minV = norm(sc.minVals[col])
        return middleScore(
            maxValue: maxV,
            minValue: minV,
            aces: norm(sc.ones[col]),
            mode: game.notation.middleMode,
            threshold: game.notation.middleBonusSumThreshold,
            bonus: game.notation.middleBonusValue,
            invalidPairMode: game.notation.resolvedMiddleInvalidPairMode
        )
    }

    static func middleScore(
        maxValue: Int,
        minValue: Int,
        aces: Int,
        mode: MiddleRuleMode,
        threshold: Int,
        bonus: Int,
        invalidPairMode: MiddleInvalidPairMode
    ) -> Int {
        switch mode {
        case .multiplier:
            guard maxValue > minValue else { return 0 }
            return (maxValue - minValue) * aces
        case .bonusGate:
            let sum = maxValue + minValue
            guard maxValue > minValue else {
                return invalidPairMode == .zeroSection ? 0 : sum
            }
            return sum + middleBonusAmount(
                maxValue: maxValue,
                minValue: minValue,
                threshold: threshold,
                bonus: bonus
            )
        }
    }

    static func middleBonusAmount(
        maxValue: Int,
        minValue: Int,
        threshold: Int,
        bonus: Int
    ) -> Int {
        guard maxValue > minValue,
              maxValue + minValue >= threshold else { return 0 }
        return bonus
    }

    // MARK: - Bottom helpers
    private static func applyFigureRule(_ raw: Int, rule: FigureRule) -> Int {
        if raw <= 0 { return 0 } // 0 => barré, -1 => vide
        switch rule.mode {
        case .raw:           return raw
        case .fixed:         return rule.fixedValue
        case .rawPlusFixed:  return raw + rule.fixedValue
        case .rawTimes:      return raw * max(1, rule.multiplier)
        }
    }

    private static func val(_ arr: [Int], _ col: Int) -> Int {
        guard col >= 0, col < arr.count else { return 0 }
        let v = arr[col]
        return v >= 0 ? v : 0
    }

    /// Score pour la grande suite: on utilise la valeur **stockée**, pas un mapping 15/20
    static func suiteScore(sc: Scorecard, col: Int) -> Int {
        return val(sc.suite, col)
    }

    /// Score pour la petite suite: idem, valeur **stockée** (0 ou la valeur définie dans la Notation)
    static func petiteSuiteScore(sc: Scorecard, col: Int) -> Int {
        return val(sc.petiteSuite, col)
    }

    static func bottomTotal(sc: Scorecard, game: Game, col: Int) -> Int {
        let n = game.notation
        guard n.bottomSectionIsEnabled else { return 0 }

        let brelan       = n.isBottomFieldEnabled(.brelan)
                            ? applyFigureRule(sc.brelan[col],    rule: n.ruleBrelan)
                            : 0
        let chance       = n.isBottomFieldEnabled(.chance)
                            ? applyFigureRule(sc.chance[col],    rule: n.ruleChance)
                            : 0
        let full         = n.isBottomFieldEnabled(.full)
                            ? applyFigureRule(sc.full[col],      rule: n.ruleFull)
                            : 0

        // Les valeurs de Suite/Petite suite sont désormais *déjà finales* (0 ou valeur de la Notation)
        let suite        = n.isBottomFieldEnabled(.suite) ? suiteScore(sc: sc, col: col) : 0
        let petiteSuite  = n.isBottomFieldEnabled(.petiteSuite)
                            ? petiteSuiteScore(sc: sc, col: col)
                            : 0

        let carre        = n.isBottomFieldEnabled(.carre)
                            ? applyFigureRule(sc.carre[col],     rule: n.ruleCarre)
                            : 0
        let yams         = n.isBottomFieldEnabled(.yams)
                            ? applyFigureRule(sc.yams[col],      rule: n.ruleYams)
                            : 0

        // Prime centralisée ici : valeur unitaire × nombre d'attributions autorisées.
        let extra        = extraYamsBonusAmount(sc: sc, game: game, col: col)

        return brelan + chance + full + suite + petiteSuite + carre + yams + extra
    }

    static func total(sc: Scorecard, game: Game, col: Int) -> Int {
        upperTotal(sc: sc, game: game, col: col)
        + middleTotal(sc: sc, game: game, col: col)
        + bottomTotal(sc: sc, game: game, col: col)
    }

    // MARK: - Tooltips
    static func middleTooltip(
        mode: MiddleRuleMode,
        threshold: Int,
        bonus: Int,
        invalidPairMode: MiddleInvalidPairMode = .keepSum
    ) -> String {
        switch mode {
        case .multiplier:
            return "Multiplicateur : (Max − Min) × nombre d’As. Si Max ≤ Min, la section vaut 0."
        case .bonusGate:
            let invalidText = invalidPairMode == .zeroSection
                ? "la section vaut 0"
                : "Max + Min est conservé sans bonus"
            return "Bonus au 50 : si Max > Min et Max + Min ≥ \(threshold), +\(bonus). Si Max ≤ Min, \(invalidText)."
        }
    }

    static func figureTooltip(notation n: NotationSnapshot, figure: FigureKind) -> String {
        func desc(_ r: FigureRule) -> String {
            switch r.mode {
            case .raw:           return "Somme saisie."
            case .fixed:         return "Valeur fixe : \(r.fixedValue)."
            case .rawPlusFixed:  return "Somme saisie + prime fixe \(r.fixedValue)."
            case .rawTimes:      return "Somme saisie × multiplicateur \(max(1, r.multiplier))."
            }
        }
        switch figure {
        case .brelan:      return "Brelan — " + desc(n.ruleBrelan)
        case .chance:      return "Chance — " + desc(n.ruleChance)
        case .full:        return "Full — " + desc(n.ruleFull)
        case .carre:       return "Carré — " + desc(n.ruleCarre)
        case .yams:
            let base = "Yams — " + desc(n.ruleYams)
            switch n.resolvedExtraYamsBonusMode {
            case .disabled:
                return base
            case .single:
                return base + " (+\(n.extraYamsBonusValue), une seule prime supplémentaire)"
            case .multiple:
                return base + " (+\(n.extraYamsBonusValue) pour chaque Yams après le premier)"
            }
        case .suiteBig:
            switch n.suiteBigMode {
            case .singleFixed:
                return "Suite (5 dés) — Valeur fixe : \(n.suiteBigFixed). (1–5 ou 2–6)"
            case .splitFixed:
                return "Suite (5 dés) — 1–5 : \(n.suiteBigFixed1to5) ; 2–6 : \(n.suiteBigFixed2to6)."
            }
        case .petiteSuite:
            return "Petite suite (4 dés) — " + desc(n.rulePetiteSuite)
        }
    }
}

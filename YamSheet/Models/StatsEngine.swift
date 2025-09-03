import Foundation

enum FigureKind {
    case brelan, chance, full, suiteBig, petiteSuite, carre, yams
}

struct StatsEngine {
    //helper
    static func extraYamsBonusAmount(sc: Scorecard, game: Game, col: Int) -> Int {
        guard game.enableExtraYamsBonus,                        // partie
              game.notation.extraYamsBonusValue > 0,            // notation (0 = off)
              sc.extraYamsAwarded.indices.contains(col),
              sc.extraYamsAwarded[col] else {
            return 0
        }
        return game.notation.extraYamsBonusValue
    }
    
    
    // -1 => non rempli ; 0 => barré ; sinon valeur
    static func norm(_ v: Int) -> Int { max(0, v) }
    
    

    // MARK: - Upper
    static func upperTotal(sc: Scorecard, game: Game, col: Int) -> Int {
        let u = [
            sc.ones[col], sc.twos[col], sc.threes[col],
            sc.fours[col], sc.fives[col], sc.sixes[col]
        ].map(norm).reduce(0, +)
        let bonus = (u >= game.notation.upperBonusThreshold) ? game.notation.upperBonusValue : 0
        return u + bonus
    }

    // MARK: - Middle
    static func middleTotal(sc: Scorecard, game: Game, col: Int) -> Int {
        let maxV = norm(sc.maxVals[col])
        let minV = norm(sc.minVals[col])
        switch game.notation.middleMode {
        case .multiplier:
            let aces = norm(sc.ones[col]) // #As (0..5)
            return (maxV - minV) * aces
        case .bonusGate:
            var s = maxV + minV
            if maxV > minV && s >= game.notation.middleBonusSumThreshold {
                s += game.notation.middleBonusValue
            }
            return s
        }
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

    private static func suiteBigScore(raw: Int, n: NotationSnapshot) -> Int {
        // Convention d’entrée : 0 = barré, 15 = 1–5, 20 = 2–6
        if raw <= 0 { return 0 }
        switch n.suiteBigMode {
        case .singleFixed:
            return n.suiteBigFixed
        case .splitFixed:
            if raw == 15 { return n.suiteBigFixed1to5 }
            if raw == 20 { return n.suiteBigFixed2to6 }
            // par sécurité, on retourne la valeur "single" si autre
            return n.suiteBigFixed
        }
    }

    static func bottomTotal(sc: Scorecard, game: Game, col: Int) -> Int {
        let n = game.notation

        let brelan       = applyFigureRule(sc.brelan[col],       rule: n.ruleBrelan)
        let chance       = game.enableChance
                            ? applyFigureRule(sc.chance[col],    rule: n.ruleChance)
                            : 0
        let full         = applyFigureRule(sc.full[col],         rule: n.ruleFull)
        let suite        = applyFigureRule(sc.suite[col],        rule: n.ruleSuite)
        let petiteSuite  = game.enableSmallStraight
                            ? applyFigureRule(sc.petiteSuite[col], rule: n.rulePetiteSuite)
                            : 0
        let carre        = applyFigureRule(sc.carre[col],        rule: n.ruleCarre)
        let yams         = applyFigureRule(sc.yams[col],         rule: n.ruleYams)

        // >>> prime centralisée ici, UNE SEULE FOIS
        let extra        = extraYamsBonusAmount(sc: sc, game: game, col: col)

        return brelan + chance + full + suite + petiteSuite + carre + yams + extra
        
    }

    static func total(sc: Scorecard, game: Game, col: Int) -> Int {
        upperTotal(sc: sc, game: game, col: col)
        + middleTotal(sc: sc, game: game, col: col)
        + bottomTotal(sc: sc, game: game, col: col)
    }

    // MARK: - Tooltips
    static func middleTooltip(mode: MiddleRuleMode, threshold: Int, bonus: Int) -> String {
        switch mode {
        case .multiplier:
            return "Multiplier : (Max − Min) × nombre d’As."
        case .bonusGate:
            return "BonusGate : si Max > Min et Max+Min ≥ \(threshold) ⇒ +\(bonus)."
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
            return n.extraYamsBonusEnabled ? base + " (+\(n.extraYamsBonusValue) bonus si Yams)" : base
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


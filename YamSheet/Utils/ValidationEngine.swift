//
//  ValidationEngine.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 31/08/2025.
//

import Foundation

/// Validation & affichage des valeurs saisies dans la feuille
enum ValidationEngine {

    // MARK: - Middle (Max/Min)

    /// [5, 30]
    private static func clamp5to30(_ v: Int) -> Int {
        return max(5, min(30, v))
    }

    /// Max dans [5,30], et cohérence vs Min
    /// - strictGreater: true pour le mode "Seuil Somme" (Max > Min), sinon Max >= Min
    static func sanitizeMiddleMax(_ newMax: Int?, currentMin: Int?, strictGreater: Bool) -> Int {
        guard let raw = newMax else { return -1 }          // -1 = vide
        let clamped = clamp5to30(raw)
        if let minv = currentMin, minv >= 0 {
            if strictGreater {
                // Max > Min
                return max(clamped, min(minv + 1, 30))
            } else {
                // Max >= Min
                return max(clamped, minv)
            }
        }
        return clamped
    }

    /// Min dans [5,30], et cohérence vs Max
    /// - strictGreater: true pour Seuil Somme (Min < Max), sinon Min <= Max
    static func sanitizeMiddleMin(_ newMin: Int?, currentMax: Int?, strictGreater: Bool) -> Int {
        guard let raw = newMin else { return -1 }
        let clamped = clamp5to30(raw)
        if let maxv = currentMax, maxv >= 0 {
            if strictGreater {
                // Min < Max
                return min(clamped, max(maxv - 1, 5))
            } else {
                // Min <= Max
                return min(clamped, maxv)
            }
        }
        return clamped
    }

    // MARK: - Bottom (figures)

    /// Sanitize générique pour les figures "basses"
    /// Règles :
    /// - 0 = barré (toujours autorisé)
    /// - raw            : 5...30
    /// - fixed          : 0 ou valeur fixe (définie dans rule.fixedValue)
    /// - rawPlusFixed   : saisie base 5...30 stockée telle quelle (affichage/calcul ajoutent fixedValue)
    /// - rawTimes       : saisie base 5...30 stockée telle quelle (affichage/calcul multiplient par multiplier)
    static func sanitizeBottom(_ newVal: Int?, rule: FigureRule) -> Int {
        guard let v = newVal else { return -1 }            // -1 = vide
        if v == 0 { return 0 }                             // 0 = barré

        switch rule.mode {
        case .raw:
            return clamp5to30(v)

        case .fixed:
            // si non-zéro, on force sur la valeur fixe définie par la notation
            return rule.fixedValue

        case .rawPlusFixed:
            // on stocke la base (5..30), la prime sera gérée en affichage + calcul
            return clamp5to30(v)

        case .rawTimes:
            // on stocke la base (5..30), le facteur sera géré en affichage + calcul
            return clamp5to30(v)
        }
    }

    /// Texte d'affichage "effectif" (ce que la case doit montrer visuellement)
    /// - raw            : v
    /// - fixed          : rule.fixedValue
    /// - rawPlusFixed   : v + rule.fixedValue   (rule.fixedValue = prime)
    /// - rawTimes       : v * rule.multiplier
    static func displayForBottom(stored v: Int, rule: FigureRule) -> String {
        if v < 0 { return "—" }
        if v == 0 { return "0" }

        switch rule.mode {
        case .raw:
            return String(v)
        case .fixed:
            return String(rule.fixedValue)
        case .rawPlusFixed:
            return String(v + rule.fixedValue)
        case .rawTimes:
            return String(v * max(1, rule.multiplier))
        }
    }

    // MARK: - Yams (5 dés identiques) : valeurs autorisées en fonction de la notation
    // Base pour "raw" = somme des 5 dés (5*face)
    static func allowedYamsValues(notation: Notation) -> Set<Int> {
        let rawBases: [Int] = [5, 10, 15, 20, 25, 30]
        let rule = notation.ruleYams

        switch rule.mode {
        case .raw:
            return Set(rawBases)
        case .fixed:
            return Set([rule.fixedValue])
        case .rawPlusFixed:
            return Set(rawBases.map { $0 + rule.fixedValue })
        case .rawTimes:
            return Set(rawBases.map { $0 * max(1, rule.multiplier) })
        }
    }

    /// CHANCE : toute somme 0..30
    static func sanitizeChance(_ newVal: Int?) -> Int {
        guard let v = newVal else { return -1 }
        return max(0, min(30, v)) // 0 accepté pour "barrer"
    }

    /// YAMS : uniquement valeurs autorisées (ou 0 pour barrer)
    static func sanitizeYams(_ newVal: Int?, notation: Notation) -> Int {
        guard let v = newVal else { return -1 }
        if v == 0 { return 0 }
        let allowed = allowedYamsValues(notation: notation)
        return allowed.contains(v) ? v : -1
    }
}

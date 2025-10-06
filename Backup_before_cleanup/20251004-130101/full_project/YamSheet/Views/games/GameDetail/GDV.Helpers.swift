//
//  GDV.Helpers.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//

import Foundation

enum GDV_Helpers {
    static func dashOr(_ value: Int) -> String { value >= 0 ? String(value) : "—" }
    // On déplacera ici ultérieurement les helpers purs (formatage, validations, etc.)

        // Affichage en cellule (numérique ou "—")
        static func displaySuiteValue(_ v: Int) -> String {
            return v == -1 ? UIStrings.Common.dash : String(v)
        }

        static func displayPetiteSuiteValue(_ v: Int) -> String {
            return v == -1 ? UIStrings.Common.dash : String(v)
        }

        // Optionnel : déplacer aussi la logique "allowed values"
        static func suiteAllowedValues(notation: Notation) -> [Int] {
            switch notation.suiteBigMode {
            case .singleFixed:
                return [0, notation.suiteBigFixed]
            case .splitFixed:
                return [0, notation.suiteBigFixed1to5, notation.suiteBigFixed2to6]
            @unknown default:
                return [0, 15, 20]
            }
        }

        static func petiteSuiteAllowedValues(notation: Notation) -> [Int] {
            return [0, notation.rulePetiteSuite.fixedValue]
        }

        // Libellés du MENU du picker (pas l’affichage dans la cellule)
        static func suiteMenuLabel(_ v: Int, notation: Notation) -> String {
            if v == -1 { return UIStrings.Common.dash }
            if v == 0  { return "0" }
            switch notation.suiteBigMode {
            case .singleFixed:
                return String(v)
            case .splitFixed:
                if v == notation.suiteBigFixed1to5 { return "1 à 5" }
                if v == notation.suiteBigFixed2to6 { return "2 à 6" }
                return String(v)
            @unknown default:
                return String(v)
            }
        }

        static func petiteSuiteMenuLabel(_ v: Int, notation: Notation) -> String {
            if v == -1 { return UIStrings.Common.dash }
            if v == 0  { return "0" }
            return UIStrings.Game.petiteSuite
        }
    
    
    
}

//
//  UIStrings.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import Foundation

enum UIStrings {
    enum Common {
        static let ok         = "OK"
        static let cancel     = "Annuler"
        static let save       = "Enregistrer"
        static let create     = "Créer"
        static let delete     = "Supprimer"
        static let validate   = "Valider"
        static let clear      = "Effacer"
        static let dash       = "—"
        static let creat       = "Créer"
        static let games       = "Parties"
        static let over       = "Terminée"
        static let inprogress       = "En cours"
        static let game       = "Partie"
        static let players     = "Joueurs"
        static let settings     = "Paramètres"
        static let notations    = "Notations"
        static let toadd    = "Ajouter"
        static let stats    = "Stats"
        static let avg    = "Moyenne"
        static let best    = "Meilleur"
        static let worst    = "Pire"
        static let wins    = "Victoires"
        static let losses    = "Défaites"
        static let identity    = "Identité"
        
     
    }
    


    enum Game {
        static let title          = "Feuille de score"

        // Sections
        static let upperSection   = "Section haute"
        static let middleSection  = "Section milieu"
        static let bottomSection  = "Section basse"
        
        //Totals
        static let total1 = "Total 1"
        static let total2 = "Total 2"
        static let total3 = "Total 3"
        static let totalAll = "Total général"

        // Header menu
        static let pause          = "Pause"
        static let resume         = "Reprendre"
        static let finish         = "Terminer"

        // Upper labels
        static let ones   = "As (1)"
        static let twos   = "Deux (2)"
        static let threes = "Trois (3)"
        static let fours  = "Quatre (4)"
        static let fives  = "Cinq (5)"
        static let sixes  = "Six (6)"

        // Middle labels
        static let max    = "Max"
        static let min    = "Min"

        // Bottom labels
        static let brelan       = "Brelan"
        static let chance       = "Chance"
        static let full         = "Full"
        static let carre        = "Carré"
        static let yams         = "Yams"
        static let suite        = "Suite"
        static let petiteSuite  = "Petite suite"

        // Tooltip
        static let tooltipTitle = "Info notation"

        // Picker display
        static let barred0   = "0"
        static let suite15   = "15"
        static let suite20   = "20"
        static let petiteLbl = "Petite suite"
    }

    enum Notation {
        static let tabTitle      = "Notations"
        static let name          = "Nom"
        static let tooltips      = "Tooltips"
        static let tooltipUpper  = "Upper (explication bonus)"
        static let tooltipMiddle = "Milieu (explication règles)"
        static let tooltipBottom = "Basse (explication figures)"
        static let upperSection  = "Section haute"
        static let middleSection = "Section milieu"
        static let bottomRules   = "Section basse — règles"
        static let upperBonusThresholdLabel = "Seuil bonus haut"
        static let upperBonusLabel          = "Bonus haut"
        static let modeLabel                = "Mode"
        static let figureTooltipPlaceholder = "Tooltip (optionnel)"

        //Upper option
        static let upperBonusthresholdLab  = "Seuil bonus haut pouet2"
        static let upperBonusOnlab  = "Seuil bonus haut pouet2"
        
        // Middle options
        static let rulePicker    = "Règle"
        static let thresholdSum  = "Seuil somme (Max+Min)"
        static let bonus         = "Bonus"

        // Bottom figure rows
        static let valueFixed    = "Valeur fixe"
        static let primeFixed    = "Prime fixe"
        static let multiplier    = "Multiplicateur"

        // Suite
        static let bigSuite      = "Grande suite (5 dés)"
        static let suite15Lbl    = "Suite 1–5"
        static let suite20Lbl    = "Suite 2–6"

        // Yams bonus
        static let extraYamsOn   = "Prime Yams supplémentaire"
        static let extraYams     = "Bonus Yams"

        // List hints
        static let listUpperLine = "Haut : Bonus +%d si ≥ %d"
        static let listMiddle    = "Milieu : %@"
        static let listBottom    = "Bas : tapote une figure pour son détail"
        
        // Libellés des modes (section milieu)
        static let middleLabelMultiplier = "Multiplicateur"
        static let middleLabelBonusGate  = "Bonus au 50"
        static func middleLabel(_ mode: MiddleRuleMode) -> String {
            switch mode {
            case .multiplier: return middleLabelMultiplier
            case .bonusGate:  return middleLabelBonusGate
            }
        }

        // Libellés des modes (section basse)
        static let bottomLabelRaw          = "Somme des dés"
        static let bottomLabelFixed        = "Valeur fixe"
        static let bottomLabelRawPlusFixed = "Somme + Prime"
        static let bottomLabelRawTimes     = "Somme × multiplicateur"
        static func bottomLabel(_ mode: BottomRuleMode) -> String {
            switch mode {
            case .raw:          return bottomLabelRaw
            case .fixed:        return bottomLabelFixed
            case .rawPlusFixed: return bottomLabelRawPlusFixed
            case .rawTimes:     return bottomLabelRawTimes
            }
        }
        
        // Libellés des modes de grande suite (5 dés)
        static let suiteModeSingleFixed = "Valeur unique"
        static let suiteModeSplitFixed  = "Valeurs 1–5 / 2–6"
        static func suiteModeLabel(_ mode: SuiteBigMode) -> String {
            switch mode {
            case .singleFixed: return suiteModeSingleFixed
            case .splitFixed:  return suiteModeSplitFixed
            }
        }

    }
    
    enum Player {
        static let name      = "Nom"
        static let surname      = "Surnom"
        static let email      = "Email"
        static let invite      = "Invité"
    }
}


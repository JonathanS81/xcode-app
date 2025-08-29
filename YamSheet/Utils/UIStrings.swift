//
//  UIStrings.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import Foundation

enum UIStrings {
    enum Common {
        static let ok         = "OK pouet"
        static let cancel     = "Annuler pouet"
        static let save       = "Enregistrer pouet"
        static let create     = "Créer pouet"
        static let delete     = "Supprimer pouet"
        static let validate   = "Valider pouet"
        static let clear      = "Effacer pouet"
        static let dash       = "—"
        static let creat       = "Créer pouet"
        static let games       = "Parties pouet"
        static let over       = "Terminée pouet"
        static let inprogress       = "En cours pouet"
        static let game       = "Partie pouet"
        static let players     = "Joueurs pouet"
        static let settings     = "Paramètres pouet"
        static let notations    = "Notations pouet"
        static let toadd    = "Ajouter pouet"
        static let stats    = "Stats pouet"
        static let avg    = "Moyenne pouet"
        static let best    = "Meilleur pouet"
        static let worst    = "Pire pouet"
        static let wins    = "Victoires pouet"
        static let losses    = "Défaites pouet"
        static let identity    = "Identité pouet"
     
    }
    


    enum Game {
        static let title          = "Feuille de score pouet"

        // Sections
        static let upperSection   = "Section haute pouet"
        static let middleSection  = "Section milieu pouet"
        static let bottomSection  = "Section basse pouet"

        // Header menu
        static let pause          = "Pause pouet"
        static let resume         = "Reprendre pouet"
        static let finish         = "Terminer pouet"

        // Upper labels
        static let ones   = "As (1) pouet"
        static let twos   = "Deux (2) pouet"
        static let threes = "Trois (3) pouet"
        static let fours  = "Quatre (4) pouet"
        static let fives  = "Cinq (5) pouet"
        static let sixes  = "Six (6) pouet"

        // Middle labels
        static let max    = "Max pouet"
        static let min    = "Min pouet"

        // Bottom labels
        static let brelan       = "Brelan pouet"
        static let chance       = "Chance pouet"
        static let full         = "Full pouet"
        static let carre        = "Carré pouet"
        static let yams         = "Yams pouet"
        static let suite        = "Suite pouet"
        static let petiteSuite  = "Petite suite pouet"

        // Tooltip
        static let tooltipTitle = "Info notation pouet"

        // Picker display
        static let barred0   = "Barré (0) pouet"
        static let suite15   = "1–5 pouet"
        static let suite20   = "2–6 pouet"
        static let petiteLbl = "Petite suite pouet"
    }

    enum Notation {
        static let tabTitle      = "Notations pouet"
        static let name          = "Nom pouet"
        static let tooltips      = "Tooltips pouet"
        static let tooltipUpper  = "Upper (explication bonus) pouet"
        static let tooltipMiddle = "Milieu (explication règles) pouet"
        static let tooltipBottom = "Basse (explication figures) pouet"
        static let upperSection  = "Section haute pouet"
        static let middleSection = "Section milieu pouet"
        static let bottomRules   = "Section basse — règles pouet"
        static let upperBonusThresholdLabel = "Seuil bonus haut pouet"
        static let upperBonusLabel          = "Bonus haut pouet"
        static let modeLabel                = "Mode pouet"
        static let figureTooltipPlaceholder = "Tooltip (optionnel) pouet"

        //Upper option
        static let upperBonusthresholdLab  = "Seuil bonus haut pouet2"
        static let upperBonusOnlab  = "Seuil bonus haut pouet2"
        
        // Middle options
        static let rulePicker    = "Règle pouet"
        static let thresholdSum  = "Seuil somme (Max+Min) pouet"
        static let bonus         = "Bonus pouet"

        // Bottom figure rows
        static let valueFixed    = "Valeur fixe pouet"
        static let primeFixed    = "Prime fixe pouet"
        static let multiplier    = "Multiplicateur pouet"

        // Suite
        static let bigSuite      = "Grande suite (5 dés) pouet"
        static let suite15Lbl    = "Suite 1–5 pouet"
        static let suite20Lbl    = "Suite 2–6 pouet"

        // Yams bonus
        static let extraYamsOn   = "Prime Yams supplémentaire pouet"
        static let extraYams     = "Bonus Yams pouet"

        // List hints
        static let listUpperLine = "Haut : Bonus +%d si ≥ %d pouet"
        static let listMiddle    = "Milieu : %@ pouet"
        static let listBottom    = "Bas : tapote une figure pour son détail pouet"
        
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
        static let name      = "Nom pouet"
        static let surname      = "Surnom pouet"
        static let email      = "Email pouet"
        static let invite      = "Invité pouet"
    }
}


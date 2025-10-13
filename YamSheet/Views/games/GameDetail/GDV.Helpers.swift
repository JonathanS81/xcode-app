//
//  GDV.Helpers.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//

import Foundation
import SwiftUI
import UIKit

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
    

    // ===== Helpers ColorData -> Color =====

    private struct RGBA: Codable {
        let r: CGFloat
        let g: CGFloat
        let b: CGFloat
        let a: CGFloat
    }

    /// Essaie de convertir un Data (colorData) en Color.
    /// - Formats supportés :
    ///   1) UIColor archivé via NSKeyedArchiver
    ///   2) JSON encodé {r,g,b,a} (CGFloat/Double)
    ///   3) 4 octets (r,g,b,a) 0...255
    private func colorFromColorData(_ data: Data) -> Color? {
        // 1) UIColor archivé
        if let ui = try? NSKeyedUnarchiver.unarchivedObject(ofClass: UIColor.self, from: data) {
            return Color(ui)
        }
        // 2) JSON RGBA
        if let rgba = try? JSONDecoder().decode(RGBA.self, from: data) {
            return Color(red: rgba.r, green: rgba.g, blue: rgba.b, opacity: rgba.a)
        }
        // 3) 4 octets 0...255
        if data.count == 4 {
            let bytes = [UInt8](data)
            let r = Double(bytes[0]) / 255.0
            let g = Double(bytes[1]) / 255.0
            let b = Double(bytes[2]) / 255.0
            let a = Double(bytes[3]) / 255.0
            return Color(red: r, green: g, blue: b, opacity: a)
        }
        return nil
    }

    /// Couleur fallback stable dérivée de l'UUID (palette hashée)
    private func hashedColor(for id: UUID) -> Color {
        var hasher = Hasher()
        hasher.combine(id)
        let hue = Double(abs(hasher.finalize() % 360)) / 360.0
        return Color(hue: hue, saturation: 0.65, brightness: 0.92)
    }

    /// ✅ Utilise `player.colorData` (Data) → Color, sinon fallback hashé
    /// Couleur du joueur (utilise la computed `Player.color` qui gère le fallback .blue)
    func colorForPlayerID(_ pid: UUID, players: [Player]) -> Color {
        if let p = players.first(where: { $0.id == pid }) {
            return p.color          // ✅ plus besoin de lire colorData
        }
        return .blue                // fallback si jamais non trouvé
    }

    // ===== Le reste de tes helpers peut rester identique =====

    func activePlayerID(game: Game, activeScorecardIndex: Int?) -> UUID? {
        guard let idx = activeScorecardIndex, idx >= 0, idx < game.scorecards.count else { return nil }
        return game.scorecards[idx].playerID
    }

    func cellBackground(
        pid: UUID,
        isFilled: Bool,
        activePlayerID: UUID?,
        players: [Player]
    ) -> some ShapeStyle {
        let base = colorForPlayerID(pid, players: players)
        let isActive = (pid == activePlayerID)
        if isActive {
            return base.opacity(isFilled ? 0.55 : 0.25) // plus foncé si rempli
        } else {
            return Color(.systemGray6)
        }
    }
    
    
}




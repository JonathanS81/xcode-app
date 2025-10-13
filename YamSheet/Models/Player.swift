//
//  Player.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@Model
final class Player {
    // MARK: - Identité (schéma actuel)
    @Attribute(.unique) var id: UUID
    var name: String
    var nickname: String

    // Champs facultatifs (schéma actuel)
    var email: String?
    var favoriteEmoji: String?

    // Couleur persistée (RGBA codée en Data) (schéma actuel)
    var colorData: Data

    // Avatar (stocké hors du fichier principal) (schéma actuel)
    @Attribute(.externalStorage) var avatarImageData: Data?

    // Statut invité (schéma actuel)
    var isGuest: Bool

    // ============================================================
    // MARK: - Compatibilité rétro (ancienne base du 25/09)
    // Ces propriétés *optionnelles* existent uniquement pour permettre
    // à SwiftData d’ouvrir l’ancien store sans migration destructive.
    // Elles ne sont pas utilisées par le code “nouveau”, mais mappent
    // les anciennes colonnes si elles sont présentes.

    /// Anciennes stats persistées côté Player (legacy)
    @Attribute(originalName: "gamesCount")
    var legacy_gamesCount: Int?

    @Attribute(originalName: "yamsCount")
    var legacy_yamsCount: Int?

    @Attribute(originalName: "averageScore")
    var legacy_averageScore: Double?

    @Attribute(originalName: "bestScore")
    var legacy_bestScore: Int?

    @Attribute(originalName: "worstScore")
    var legacy_worstScore: Int?

    @Attribute(originalName: "wins")
    var legacy_wins: Int?

    @Attribute(originalName: "losses")
    var legacy_losses: Int?

    // Si, dans une ancienne révision, le surnom s'appelait "nick", décommente :
    // @Attribute(originalName: "nick")
    // var nickname: String

    // ============================================================

    // MARK: - Init (schéma actuel)
    init(id: UUID = UUID(),
         name: String,
         nickname: String,
         email: String? = nil,
         favoriteEmoji: String? = nil,
         color: Color = .blue,
         avatarImageData: Data? = nil,
         isGuest: Bool = false) {

        self.id = id
        self.name = name
        self.nickname = nickname
        self.email = email
        self.favoriteEmoji = favoriteEmoji
        self.colorData = Player.encode(color)     // encodage RGBA JSON
        self.avatarImageData = avatarImageData
        self.isGuest = isGuest

        // Les champs legacy_* restent nil par défaut (c’est voulu).
    }

    // MARK: - Couleur (computed)
    var color: Color {
        get {
            (try? JSONDecoder().decode(ColorCodable.self, from: colorData))?.color ?? .blue
        }
        set {
            colorData = Player.encode(newValue)
        }
    }

    // MARK: - Helpers
    private static func encode(_ color: Color) -> Data {
        (try? JSONEncoder().encode(ColorCodable(color))) ?? Data()
    }
}

// MARK: - UI Helpers (optionnel)
extension Player {
    /// Initiales pour un avatar monogramme (ex. “JS”)
    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map { String($0) } ?? ""
        let last = parts.dropFirst().first?.first.map { String($0) } ?? ""
        let nickInitial = nickname.first.map { String($0) } ?? ""
        let composed = (first + last)
        return composed.isEmpty ? nickInitial : composed
    }

    /// Image d’avatar si disponible
    var avatarImage: UIImage? {
        guard let data = avatarImageData else { return nil }
        return UIImage(data: data)
    }
}

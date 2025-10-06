//
//  Player.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import SwiftUI
import SwiftData

@Model
final class Player {
    // Identité
    @Attribute(.unique) var id: UUID
    var name: String
    var nickname: String

    // Champs facultatifs
    var email: String?
    var favoriteEmoji: String?

    // Couleur persistée (RGBA codée en Data)
    var colorData: Data

    // Avatar (stocké hors du fichier principal pour éviter de gonfler la DB)
    @Attribute(.externalStorage) var avatarImageData: Data?

    // Statut invité
    var isGuest: Bool

    // MARK: - Init

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
        self.colorData = Player.encode(color)     // encodage RGBA
        self.avatarImageData = avatarImageData
        self.isGuest = isGuest
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
        // Priorité : initiales nom/prénom sinon initiale du surnom
        let composed = (first + last)
        return composed.isEmpty ? nickInitial : composed
    }

    /// Image d’avatar si disponible
    var avatarImage: UIImage? {
        guard let data = avatarImageData else { return nil }
        return UIImage(data: data)
    }
}

//
//  Player.swift
//  YamSheet
//
//  Created by Jonathan Sportiche on 28/08/2025.
//

import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

@Model
final class Player {
    // Identité
    @Attribute(.unique) var id: UUID
    var name: String
    var nickname: String

    // Champs facultatifs
    var email: String?
    var favoriteEmoji: String?

    // ⚠️ Rendre la couleur optionnelle pour migration rétro
    var colorData: Data?        // <- avant : Data
    @Attribute(.externalStorage) var avatarImageData: Data?
    var isGuest: Bool

    // === Compat rétro anciennes stats ===
    @Attribute(originalName: "gamesCount") var legacy_gamesCount: Int?
    @Attribute(originalName: "yamsCount") var legacy_yamsCount: Int?
    @Attribute(originalName: "averageScore") var legacy_averageScore: Double?
    @Attribute(originalName: "bestScore") var legacy_bestScore: Int?
    @Attribute(originalName: "worstScore") var legacy_worstScore: Int?
    @Attribute(originalName: "wins") var legacy_wins: Int?
    @Attribute(originalName: "losses") var legacy_losses: Int?

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
        self.colorData = Player.encode(color)
        self.avatarImageData = avatarImageData
        self.isGuest = isGuest
    }

    // MARK: - Couleur (computed)
    var color: Color {
        get {
            guard let data = colorData,
                  let decoded = try? JSONDecoder().decode(ColorCodable.self, from: data)
            else {
                // fallback si la base ancienne n’avait pas colorData
                return .blue
            }
            return decoded.color
        }
        set {
            colorData = Player.encode(newValue)
        }
    }

    private static func encode(_ color: Color) -> Data {
        (try? JSONEncoder().encode(ColorCodable(color))) ?? Data()
    }
}

// MARK: - UI Helpers
extension Player {
    var initials: String {
        let parts = name.split(separator: " ")
        let first = parts.first?.first.map(String.init) ?? ""
        let last = parts.dropFirst().first?.first.map(String.init) ?? ""
        let nickInitial = nickname.first.map(String.init) ?? ""
        let composed = first + last
        return composed.isEmpty ? nickInitial : composed
    }

    var avatarImage: UIImage? {
        guard let data = avatarImageData else { return nil }
        return UIImage(data: data)
    }
}

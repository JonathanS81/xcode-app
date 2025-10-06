//
//  PlayerEditorView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 30/08/2025.
//

import SwiftUI
import SwiftData

struct PlayerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @Bindable var player: Player


    @State private var draft: PlayerFormView.Draft = .init()

    var body: some View {
        PlayerFormView(draft: $draft, isEditing: true, onValidate: { d in
            player.name = d.name.trimmingCharacters(in: .whitespacesAndNewlines)
            player.nickname = d.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
            player.email = d.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : d.email
            player.favoriteEmoji = d.favoriteEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : d.favoriteEmoji
            player.color = d.preferredColor
            player.avatarImageData = d.avatarImageData
            player.isGuest = d.isGuest
            try? context.save()
            dismiss()
        }, onCancel: {
            dismiss()
        })
        .navigationTitle("Modifier joueur")
        .onAppear {
            draft = PlayerFormView.Draft(
                name: player.name,
                nickname: player.nickname,
                email: player.email ?? "",
                favoriteEmoji: player.favoriteEmoji ?? "",
                //preferredColor: Color(hex: player.preferredColorHex ?? "") ?? .blue,
                preferredColor: player.color,
                isGuest: player.isGuest,
                avatarImageData: player.avatarImageData
            )
        }
    }
}

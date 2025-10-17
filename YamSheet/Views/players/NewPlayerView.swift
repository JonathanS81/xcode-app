//
//  PlayerEditorView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 30/08/2025.
//
import SwiftUI
import SwiftData

struct NewPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var draft = PlayerFormView.Draft()

    /// Callback optionnel déclenché une fois le joueur créé et sauvegardé
    var onCreated: ((Player) -> Void)? = nil

    var body: some View {
        PlayerFormView(
            draft: $draft,
            isEditing: false,
            onValidate: { d in
                // Création du joueur avec le nouveau modèle (couleur directe)
                let p = Player(
                    name: d.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    nickname: d.nickname.trimmingCharacters(in: .whitespacesAndNewlines),
                    email: d.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : d.email,
                    favoriteEmoji: d.favoriteEmoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : d.favoriteEmoji,
                    color: d.preferredColor,
                    avatarImageData: d.avatarImageData,
                    isGuest: d.isGuest
                )
                context.insert(p)
                try? context.save()

                // Notifier l'appelant (NewGameView, etc.)
                onCreated?(p)
                dismiss()
            },
            onCancel: {
                dismiss()
            }
        )
        .navigationTitle("Nouveau joueur")
    }
}

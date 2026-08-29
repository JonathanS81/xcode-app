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
                let displayName = d.displayName.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                // Création du joueur avec le nouveau modèle (couleur directe)
                let p = Player(
                    name: displayName,
                    nickname: displayName,
                    email: d.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : d.email,
                    color: d.preferredColor,
                    avatarImageData: d.avatarImageData
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

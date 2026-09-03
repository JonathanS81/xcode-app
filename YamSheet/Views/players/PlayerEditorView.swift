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
            player.setDisplayName(d.displayName)
            player.email = d.email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : d.email
            player.color = d.preferredColor
            player.avatarImageData = d.avatarImageData
            try? context.save()
            dismiss()
        }, onCancel: {
            dismiss()
        })
        .navigationTitle("Modifier joueur")
        .onAppear {
            draft = PlayerFormView.Draft(
                displayName: player.displayName,
                email: player.email ?? "",
                preferredColor: player.color,
                avatarImageData: player.avatarImageData
            )
        }
    }
}

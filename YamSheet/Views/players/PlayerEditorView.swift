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

    @State private var name: String = ""
    @State private var nickname: String = ""
    @State private var favoriteEmoji: String = ""
    @State private var color: Color = .blue

    var onCreated: ((Player) -> Void)? = nil

    var body: some View {
        Form {
            Section("Identité") {
                TextField("Nom", text: $name)
                TextField("Surnom", text: $nickname)
            }
            Section("Profil") {
                TextField("Emoji favori (optionnel)", text: $favoriteEmoji)
                ColorPicker("Couleur", selection: $color, supportsOpacity: false)
            }
            Section {
                Button {
                    createPlayer()
                } label: {
                    Text("Créer le joueur").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty
                          && name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .navigationTitle("Nouveau joueur")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Annuler") { dismiss() }
            }
        }
    }

    private func createPlayer() {
        let base = nickname.isEmpty ? (name.isEmpty ? "Joueur" : name) : nickname
        // adapte si ton modèle a d'autres champs (avatar, etc.)
        let p = Player(name: name.isEmpty ? base : name,
                       nickname: nickname.isEmpty ? base : nickname)
        // si tu stockes la couleur/emoji dans Player, mappe-les ici
        context.insert(p)
        try? context.save()

        onCreated?(p)
        // On laisse le parent sheet se fermer via onCreated (activeSheet = nil)
        dismiss()
    }
}

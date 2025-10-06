//
//  NewPlayerInlineSheet.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 30/08/2025.
//

import SwiftUI

struct NewPlayerInlineSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var nickname: String = ""
    var onCreate: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Nom du joueurOUOUOU") {
                    TextField("Pseudo", text: $nickname)
                }
                Section {
                    Button("Créer") {
                        guard !nickname.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                        onCreate(nickname.trimmingCharacters(in: .whitespaces))
                        dismiss()
                    }
                    .disabled(nickname.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("Nouveau joueur")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
            }
        }
    }
}

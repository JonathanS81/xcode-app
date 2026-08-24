//
//  NotationEditorView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//
import SwiftUI
import SwiftData

struct NotationEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    var onCreated: ((Notation) -> Void)? = nil

    @State private var local = Notation(name: "Classique")

    var body: some View {
        NavigationStack {
            Form {
                NotationConfigurationSections(notation: local)

                Section {
                    NotationHelpEditor(notation: local)
                } header: {
                    Text("Aides de la feuille de score")
                } footer: {
                    Text("Seules les aides renseignées pourront être affichées pendant une partie.")
                }
            }
            .scrollDismissesKeyboard(.interactively)

            .navigationTitle("Nouvelle notation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        context.insert(local)
                        try? context.save()
                        if let cb = onCreated {
                            cb(local)           // remonte la notation au parent (NewGameView)
                            // on ne dismiss pas ici : NewGameView fermera la sheet
                        } else {
                            dismiss()           // cas d'usage en autonome
                        }
                    }
                    .disabled(local.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

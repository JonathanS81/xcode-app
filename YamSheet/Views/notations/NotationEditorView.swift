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
            }
            .scrollDismissesKeyboard(.interactively)

            .navigationTitle("Nouvelle notation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        context.insert(local)
                        try? context.save()
                        if let onCreated {
                            onCreated(local)
                        } else {
                            dismiss()
                        }
                    }
                    .disabled(local.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

//
//  NotationsListView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import SwiftUI
import SwiftData

struct NotationsListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Notation.name) private var notations: [Notation]
    @State private var showingNew = false
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(notations) { n in
                    NavigationLink(value: n.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(n.name).font(.headline)
                            // Lignes d’info
                            Text("Haut : Bonus +\(n.upperBonusValue) si ≥ \(n.upperBonusThreshold)")
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Milieu : " + StatsEngine.middleTooltip(
                                    mode: MiddleRuleMode(rawValue: n.middleModeRaw) ?? .multiplier,
                                    threshold: n.middleBonusSumThreshold,
                                    bonus: n.middleBonusValue))
                                .font(.caption).foregroundStyle(.secondary)
                            Text("Bas : tapote une figure pour son détail")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete { idx in
                    idx.map { notations[$0] }.forEach(context.delete)
                    try? context.save()
                }
            }
            .navigationTitle(UIStrings.Notation.tabTitle)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Label("Ajouter", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) {
                NotationEditorView()
            }
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let n = notations.first(where: { $0.id == id }) {
                    NotationDetailView(notation: n)
                } else {
                    Text("Introuvable")
                }
            }
        }
    }
}

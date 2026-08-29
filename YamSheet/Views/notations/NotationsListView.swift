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
                ForEach(displayedNotations) { n in
                    NavigationLink(value: n.id) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(n.name).font(.headline)
                                if n.isBuiltIn {
                                    Label("Intégrée", systemImage: "lock.fill")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if !n.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Text(n.comment)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }

                            if n.visibility.upperSectionEnabled {
                                sectionDetail(
                                    "Haut",
                                    "Bonus +\(n.upperBonusValue) si le total atteint \(n.upperBonusThreshold)"
                                )
                            }

                            if n.visibility.middleSectionEnabled {
                                sectionDetail(
                                    "Milieu",
                                    StatsEngine.middleTooltip(
                                        mode: MiddleRuleMode(rawValue: n.middleModeRaw) ?? .multiplier,
                                        threshold: n.middleBonusSumThreshold,
                                        bonus: n.middleBonusValue,
                                        invalidPairMode: n.middleInvalidPairMode
                                    )
                                )
                            }

                            if n.visibility.bottomSectionEnabled {
                                sectionDetail("Bas", bottomSectionDetail(for: n))
                            }
                        }
                    }
                    .listRowBackground(
                        n.builtInIdentifier == .standard
                            ? Color.accentColor.opacity(0.10)
                            : nil
                    )
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            duplicate(n)
                        } label: {
                            Label("Dupliquer", systemImage: "doc.on.doc")
                        }
                        .tint(.accentColor)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if !n.isBuiltIn {
                            Button(role: .destructive) {
                                context.delete(n)
                                try? context.save()
                            } label: {
                                Label("Supprimer", systemImage: "trash")
                            }
                        }
                    }
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

    /// La notation intégrée Standard reste la référence visible en tête de
    /// liste. Les notations personnelles conservent ensuite l'ordre
    /// alphabétique attendu par l'utilisateur.
    private var displayedNotations: [Notation] {
        notations.sorted { lhs, rhs in
            let lhsIsStandard = lhs.builtInIdentifier == .standard
            let rhsIsStandard = rhs.builtInIdentifier == .standard

            if lhsIsStandard != rhsIsStandard {
                return lhsIsStandard
            }

            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func duplicate(_ notation: Notation) {
        context.insert(notation.duplicate())
        try? context.save()
    }

    private func sectionDetail(_ title: String, _ detail: String) -> Text {
        (Text("\(title) : ").fontWeight(.semibold) + Text(detail))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func bottomSectionDetail(for notation: Notation) -> String {
        var categories: [String] = []
        if notation.visibility.brelanEnabled { categories.append("Brelan") }
        if notation.isChanceEnabled { categories.append("Chance") }
        if notation.visibility.fullEnabled { categories.append("Full") }
        if notation.visibility.suiteEnabled { categories.append("Grande suite") }
        if notation.isSmallStraightEnabled { categories.append("Petite suite") }
        if notation.visibility.carreEnabled { categories.append("Carré") }
        if notation.visibility.yamsEnabled { categories.append("Yams") }
        return categories.isEmpty ? "Aucune catégorie active" : categories.joined(separator: " • ")
    }
}

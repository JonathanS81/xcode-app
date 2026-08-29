//
//  NotationDetailView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import SwiftUI
import SwiftData

struct NotationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Bindable var notation: Notation // ← IMPORTANT
    @State private var showDuplicated = false
    
    var body: some View {
        Form {
            if notation.isBuiltIn {
                Section {
                    Label("Modèle intégré protégé", systemImage: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Dupliquez cette notation pour modifier ses règles ou masquer des éléments de la feuille.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Group {
            NotationConfigurationSections(notation: notation)
            }
            .disabled(notation.isBuiltIn)

            Section {
                Button {
                    let copy = notation.duplicate()
                    context.insert(copy)
                    try? context.save()
                    showDuplicated = true
                } label: {
                    Label("Dupliquer et personnaliser", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(notation.name)
        .toolbar {
            if !notation.isBuiltIn {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
        .alert("Copie créée", isPresented: $showDuplicated) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("La nouvelle notation apparaît dans la liste et peut être entièrement personnalisée.")
        }
    }
}

struct FigureRuleRow: View {
    let title: String
    @Binding var rule: FigureRule
    var onModeChanged: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: Binding(
                get: { rule.mode.rawValue },
                set: { rawValue in
                    let newMode = BottomRuleMode(rawValue: rawValue) ?? .raw
                    guard newMode != rule.mode else { return }
                    rule.mode = newMode
                    onModeChanged?()
                }
            )) {
                ForEach(BottomRuleMode.allCases) { mode in
                    Text(UIStrings.Notation.bottomLabel(mode))
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)

            if rule.mode == .fixed {
                NotationNumberRow(
                    title: UIStrings.Notation.valueFixed,
                    value: $rule.fixedValue,
                    range: 0...200
                )
            } else if rule.mode == .rawPlusFixed {
                NotationNumberRow(
                    title: UIStrings.Notation.primeFixed,
                    value: $rule.fixedValue,
                    range: 0...200
                )
            } else if rule.mode == .rawTimes {
                NotationNumberRow(
                    title: UIStrings.Notation.multiplier,
                    value: $rule.multiplier,
                    range: 1...10
                )
            }

        }
        .animation(.default, value: rule.mode)
    }
}

struct OptionalFigureRuleBlock: View {
    let toggleTitle: String
    let scoreTitle: String
    @Binding var isEnabled: Bool
    @Binding var rule: FigureRule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(toggleTitle, isOn: $isEnabled)

            if isEnabled {
                FigureRuleRow(title: scoreTitle, rule: $rule)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.default, value: isEnabled)
    }
}

struct BigSuiteRuleBlock: View {
    @Binding var modeRaw: String
    @Binding var singleValue: Int
    @Binding var value1to5: Int
    @Binding var value2to6: Int

    private var mode: SuiteBigMode {
        SuiteBigMode(rawValue: modeRaw) ?? .singleFixed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Notation", selection: $modeRaw) {
                Text(UIStrings.Notation.suiteModeLabel(.singleFixed))
                    .tag(SuiteBigMode.singleFixed.rawValue)
                Text(UIStrings.Notation.suiteModeLabel(.splitFixed))
                    .tag(SuiteBigMode.splitFixed.rawValue)
            }
            .pickerStyle(.menu)

            if mode == .singleFixed {
                valueRow(
                    title: UIStrings.Notation.valueFixed,
                    value: $singleValue
                )
            } else {
                valueRow(
                    title: UIStrings.Notation.suite15Lbl,
                    value: $value1to5
                )
                valueRow(
                    title: UIStrings.Notation.suite20Lbl,
                    value: $value2to6
                )
            }
        }
        .animation(.default, value: modeRaw)
    }

    private func valueRow(
        title: String,
        value: Binding<Int>
    ) -> some View {
        NotationNumberRow(title: title, value: value, range: 0...100)
    }
}

struct ExtraYamsBonusBlock: View {
    @Binding var mode: ExtraYamsBonusMode
    @Binding var value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Prime de Yams", selection: $mode) {
                ForEach(ExtraYamsBonusMode.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.menu)

            if mode != .disabled {
                NotationNumberRow(
                    title: "Montant par prime",
                    value: $value,
                    range: 0...200
                )
            }

            Text(
                mode == .multiple
                    ? "Chaque Yams après le premier peut recevoir une prime."
                    : "Le premier Yams n’accorde pas de prime."
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .animation(.default, value: mode)
    }
}

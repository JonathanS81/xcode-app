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
    let figure: BottomScoreField
    @Binding var rule: FigureRule
    var onModeChanged: (() -> Void)? = nil

    private struct ScoringOption: Identifiable {
        let mode: BottomRuleMode
        let basis: FigureDiceBasis

        var id: String { "\(mode.rawValue)-\(basis.rawValue)" }
    }

    private var availableOptions: [ScoringOption] {
        if figure == .suite || figure == .petiteSuite {
            return [ScoringOption(mode: .fixed, basis: .fiveDice)]
        }

        let bases: [FigureDiceBasis] = figure.allowsFigureDiceBasis
            ? [.fiveDice, .figureDice]
            : [.fiveDice]
        var options = [ScoringOption(mode: .fixed, basis: .fiveDice)]
        options += bases.map { ScoringOption(mode: .raw, basis: $0) }
        options += bases.map { ScoringOption(mode: .rawPlusFixed, basis: $0) }
        options += bases.map { ScoringOption(mode: .rawTimes, basis: $0) }
        return options
    }

    private var selectedOptionID: String {
        ScoringOption(
            mode: rule.mode,
            basis: rule.resolvedDiceBasis(for: figure)
        ).id
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: Binding(
                get: { selectedOptionID },
                set: { optionID in
                    guard let option = availableOptions.first(where: { $0.id == optionID }) else {
                        return
                    }
                    let oldMode = rule.mode
                    let oldBasis = rule.resolvedDiceBasis(for: figure)
                    guard option.mode != oldMode || option.basis != oldBasis else { return }
                    rule.mode = option.mode
                    rule.diceBasis = option.mode == .fixed ? nil : option.basis
                    onModeChanged?()
                }
            )) {
                ForEach(availableOptions) { option in
                    Text(
                        UIStrings.Notation.bottomLabel(
                            option.mode,
                            basis: option.basis
                        )
                    )
                    .tag(option.id)
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
        .onAppear {
            guard figure == .suite || figure == .petiteSuite,
                  rule.mode != .fixed else { return }
            rule.mode = .fixed
            rule.diceBasis = nil
            onModeChanged?()
        }
    }
}

struct OptionalFigureRuleBlock: View {
    let toggleTitle: String
    let scoreTitle: String
    let figure: BottomScoreField
    @Binding var isEnabled: Bool
    @Binding var rule: FigureRule

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(toggleTitle, isOn: $isEnabled)

            if isEnabled {
                FigureRuleRow(title: scoreTitle, figure: figure, rule: $rule)
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

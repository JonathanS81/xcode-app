//
//  NotationDetailView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/08/2025.
//

import SwiftUI
import SwiftData

struct NotationDetailView: View {
    
 
    @Environment(\.modelContext) private var context
    @Bindable var notation: Notation // ← IMPORTANT
    @State private var showSaved = false
    
    var body: some View {
        Form {
            Section("Nom") {
                TextField("Nom de la notation", text: $notation.name)
            }
            
            Section(UIStrings.Notation.upperSection) {
                Stepper("\(UIStrings.Notation.upperBonusThresholdLabel) : \(notation.upperBonusThreshold)",
                        value: $notation.upperBonusThreshold, in: 0...200)

                Stepper("\(UIStrings.Notation.upperBonusLabel) : \(notation.upperBonusValue)",
                        value: $notation.upperBonusValue, in: 0...200)
            }
            
            Section(UIStrings.Notation.middleSection) {
                Picker(UIStrings.Notation.rulePicker, selection: $notation.middleModeRaw) {
                    Text(UIStrings.Notation.middleLabel(.multiplier)).tag(MiddleRuleMode.multiplier.rawValue)
                    Text(UIStrings.Notation.middleLabel(.bonusGate)).tag(MiddleRuleMode.bonusGate.rawValue)
                }
                Text(
                    StatsEngine.middleTooltip(
                        mode: MiddleRuleMode(rawValue: notation.middleModeRaw) ?? .multiplier,
                        threshold: notation.middleBonusSumThreshold,
                        bonus: notation.middleBonusValue
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                if MiddleRuleMode(rawValue: notation.middleModeRaw) == .bonusGate {
                    Stepper("\(UIStrings.Notation.thresholdSum) : \(notation.middleBonusSumThreshold)",
                            value: $notation.middleBonusSumThreshold, in: 0...200)
                    Stepper("\(UIStrings.Notation.bonus) : \(notation.middleBonusValue)",
                            value: $notation.middleBonusValue, in: 0...200)
                }
            }



            Section("Suites") {
                BigSuiteRuleBlock(
                    modeRaw: $notation.suiteBigModeRaw,
                    singleValue: $notation.suiteBigFixed,
                    value1to5: $notation.suiteBigFixed1to5,
                    value2to6: $notation.suiteBigFixed2to6
                )
                OptionalFigureRuleBlock(
                    toggleTitle: "Activer la petite suite",
                    scoreTitle: "Score petite suite",
                    isEnabled: Binding(
                        get: { notation.isSmallStraightEnabled },
                        set: { notation.isSmallStraightEnabled = $0 }
                    ),
                    rule: $notation.rulePetiteSuite
                )
            }

            Section("Figures") {
                FigureRuleRow(title: "Brelan", rule: $notation.ruleBrelan)
                OptionalFigureRuleBlock(
                    toggleTitle: "Activer la Chance",
                    scoreTitle: "Score Chance",
                    isEnabled: Binding(
                        get: { notation.isChanceEnabled },
                        set: { notation.isChanceEnabled = $0 }
                    ),
                    rule: $notation.ruleChance
                )
                FigureRuleRow(title: "Full", rule: $notation.ruleFull)
                FigureRuleRow(title: "Carré", rule: $notation.ruleCarre)
                FigureRuleRow(title: "Yams", rule: $notation.ruleYams)
                ExtraYamsBonusBlock(
                    mode: Binding(
                        get: { notation.extraYamsBonusMode },
                        set: { notation.extraYamsBonusMode = $0 }
                    ),
                    value: $notation.extraYamsBonusValue
                )
            }

            Section {
                NotationHelpEditor(notation: notation)
            } header: {
                Text("Aides de la feuille de score")
            } footer: {
                Text("Seules les aides renseignées pourront être affichées pendant une partie.")
            }
        }
        .navigationTitle(notation.name)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") {
                    try? context.save()
                    showSaved = true
                }
            }
        }
        .alert("Enregistré ✅", isPresented: $showSaved) {
            Button("OK", role: .cancel) { }
        }
    }
}

struct NotationHelpEditor: View {
    @Bindable var notation: Notation

    var body: some View {
        DisclosureGroup("Section haute") {
            helpField("Aide de la section", key: .sectionUpper)
            helpField("As", key: .ones)
            helpField("Deux", key: .twos)
            helpField("Trois", key: .threes)
            helpField("Quatre", key: .fours)
            helpField("Cinq", key: .fives)
            helpField("Six", key: .sixes)
        }

        DisclosureGroup("Section milieu") {
            helpField("Aide de la section", key: .sectionMiddle)
            helpField("Max", key: .max)
            helpField("Min", key: .min)
        }

        DisclosureGroup("Section basse") {
            helpField("Aide de la section", key: .sectionBottom)
            helpField("Brelan", key: .brelan)
            helpField("Chance", key: .chance)
            helpField("Full", key: .full)
            helpField("Grande suite", key: .suite)
            helpField("Petite suite", key: .petiteSuite)
            helpField("Carré", key: .carre)
            helpField("Yams", key: .yams)
            helpField("Prime Yams supplémentaire", key: .extraYams)
        }
    }

    private func helpBinding(for key: ScoreHelpKey) -> Binding<String> {
        Binding(
            get: { notation.helpTextValue(for: key) },
            set: { notation.setHelpText($0, for: key) }
        )
    }

    private func helpField(_ title: String, key: ScoreHelpKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "Texte d’aide (optionnel)",
                text: helpBinding(for: key),
                axis: .vertical
            )
            .lineLimit(2...4)
        }
        .padding(.vertical, 4)
    }
}



struct FigureRuleRow: View {
    let title: String
    @Binding var rule: FigureRule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker(title, selection: Binding(
                get: { rule.mode.rawValue },
                set: { rule.mode = BottomRuleMode(rawValue: $0) ?? .raw }
            )) {
                ForEach(BottomRuleMode.allCases) { mode in
                    Text(UIStrings.Notation.bottomLabel(mode))
                        .tag(mode.rawValue)
                }
            }
            .pickerStyle(.menu)

            if rule.mode == .fixed {
                HStack {
                    Text(UIStrings.Notation.valueFixed).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CompactWheelPicker(value: $rule.fixedValue,
                                       range: 0...200,
                                       title: UIStrings.Notation.valueFixed)
                }
            } else if rule.mode == .rawPlusFixed {
                HStack {
                    Text(UIStrings.Notation.primeFixed).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CompactWheelPicker(value: $rule.fixedValue,
                                       range: 0...200,
                                       title: UIStrings.Notation.primeFixed)
                }
            } else if rule.mode == .rawTimes {
                HStack {
                    Text(UIStrings.Notation.multiplier).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CompactWheelPicker(value: $rule.multiplier,
                                       range: 1...10,
                                       title: UIStrings.Notation.multiplier,
                                       display: { "×\($0)" })
                }
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
            Picker(UIStrings.Notation.bigSuite, selection: $modeRaw) {
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
        HStack {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            CompactWheelPicker(
                value: value,
                range: 0...100,
                title: title
            )
        }
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
                HStack {
                    Text("Montant par prime")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    CompactWheelPicker(
                        value: $value,
                        range: 0...200,
                        title: "Montant par prime"
                    )
                }
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

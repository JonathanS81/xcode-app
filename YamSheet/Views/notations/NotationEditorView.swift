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

    @State private var local = Notation(
        name: "Classique",
        tooltipUpper: "Atteignez le seuil pour gagner le bonus.",
        tooltipMiddle: nil, // non édité : affiché via StatsEngine.middleTooltip
        tooltipBottom: "Chaque figure peut être calculée différemment."
    )

    var body: some View {
        NavigationStack {
            Form {
                // Nom
                Section(UIStrings.Notation.name) {
                    TextField(UIStrings.Notation.name, text: $local.name)
                }

                // Tooltips : Upper & Bottom éditables ; Middle est affiché en lecture seule plus bas
                Section(UIStrings.Notation.tooltips) {
                    TextField(UIStrings.Notation.tooltipUpper, text: Binding(
                        get: { local.tooltipUpper ?? "" },
                        set: { local.tooltipUpper = $0 }
                    ))
                    TextField(UIStrings.Notation.tooltipBottom, text: Binding(
                        get: { local.tooltipBottom ?? "" },
                        set: { local.tooltipBottom = $0 }
                    ))
                }

                // Section haute
                Section(UIStrings.Notation.upperSection) {
                    Stepper("\(UIStrings.Notation.upperBonusThresholdLabel) : \(local.upperBonusThreshold)",
                            value: $local.upperBonusThreshold, in: 0...200)
                    Stepper("\(UIStrings.Notation.upperBonusLabel) : \(local.upperBonusValue)",
                            value: $local.upperBonusValue, in: 0...200)
                }

                // Section milieu (tooltip non éditable + champs conditionnels)
                Section(UIStrings.Notation.middleSection) {
                    Picker(UIStrings.Notation.rulePicker, selection: $local.middleModeRaw) {
                        ForEach(MiddleRuleMode.allCases) { m in
                            Text(m.rawValue).tag(m.rawValue)
                        }
                    }

                    // Tooltip auto selon le mode choisi (non éditable)
                    Text(
                        StatsEngine.middleTooltip(
                            mode: MiddleRuleMode(rawValue: local.middleModeRaw) ?? .multiplier,
                            threshold: local.middleBonusSumThreshold,
                            bonus: local.middleBonusValue
                        )
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                    if MiddleRuleMode(rawValue: local.middleModeRaw) == .bonusGate {
                        Stepper("\(UIStrings.Notation.thresholdSum) : \(local.middleBonusSumThreshold)",
                                value: $local.middleBonusSumThreshold, in: 0...200)
                        Stepper("\(UIStrings.Notation.bonus) : \(local.middleBonusValue)",
                                value: $local.middleBonusValue, in: 0...200)
                    }
                }

                // Section basse — Grande suite (5 dés)
                Section(UIStrings.Notation.bigSuite) {
                    Picker(UIStrings.Notation.modeLabel, selection: $local.suiteBigModeRaw) {
                        ForEach(SuiteBigMode.allCases) { m in
                            Text(m.rawValue).tag(m.rawValue)
                        }
                    }

                    if local.suiteBigMode == .singleFixed {
                        HStack {
                            Text(UIStrings.Notation.valueFixed).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            CompactWheelPicker(value: $local.suiteBigFixed,
                                               range: 0...100,
                                               title: UIStrings.Notation.valueFixed)
                        }
                    } else {
                        HStack {
                            Text(UIStrings.Notation.suite15Lbl).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            CompactWheelPicker(value: $local.suiteBigFixed1to5,
                                               range: 0...100,
                                               title: UIStrings.Notation.suite15Lbl)
                        }
                        HStack {
                            Text(UIStrings.Notation.suite20Lbl).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            CompactWheelPicker(value: $local.suiteBigFixed2to6,
                                               range: 0...100,
                                               title: UIStrings.Notation.suite20Lbl)
                        }
                    }
                }

                // Section basse — Règles des figures
                Section(UIStrings.Notation.bottomRules) {
                    FigureRuleRow(title: "Brelan",       rule: $local.ruleBrelan)
                    FigureRuleRow(title: "Chance",       rule: $local.ruleChance)
                    FigureRuleRow(title: "Full",         rule: $local.ruleFull)
                    FigureRuleRow(title: "Petite suite", rule: $local.rulePetiteSuite)
                    FigureRuleRow(title: "Carré",        rule: $local.ruleCarre)
                    FigureRuleRow(title: "Yams",         rule: $local.ruleYams)

                    Toggle(UIStrings.Notation.extraYamsOn, isOn: $local.extraYamsBonusEnabled)
                    HStack {
                        Text(UIStrings.Notation.extraYams).font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        CompactWheelPicker(value: $local.extraYamsBonusValue,
                                           range: 0...200,
                                           title: UIStrings.Notation.extraYams)
                            .opacity(local.extraYamsBonusEnabled ? 1 : 0.5)
                            .allowsHitTesting(local.extraYamsBonusEnabled)
                    }
                }

                // Tooltip bas (affichage)
                if let tip = local.tooltipBottom, !tip.isEmpty {
                    Section {
                        Text(tip).font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }

            .navigationTitle("Nouvelle notation")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") {
                        context.insert(local)
                        try? context.save()
                        dismiss()
                    }
                }
            }
        }
    }
}

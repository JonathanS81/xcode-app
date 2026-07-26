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
                // Nom
                Section(UIStrings.Notation.name) {
                    TextField(UIStrings.Notation.name, text: $local.name)
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
                        Text(UIStrings.Notation.middleLabel(.multiplier)).tag(MiddleRuleMode.multiplier.rawValue)
                        Text(UIStrings.Notation.middleLabel(.bonusGate)).tag(MiddleRuleMode.bonusGate.rawValue)
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

                Section("Suites") {
                    BigSuiteRuleBlock(
                        modeRaw: $local.suiteBigModeRaw,
                        singleValue: $local.suiteBigFixed,
                        value1to5: $local.suiteBigFixed1to5,
                        value2to6: $local.suiteBigFixed2to6
                    )
                    OptionalFigureRuleBlock(
                        toggleTitle: "Activer la petite suite",
                        scoreTitle: "Score petite suite",
                        isEnabled: Binding(
                            get: { local.isSmallStraightEnabled },
                            set: { local.isSmallStraightEnabled = $0 }
                        ),
                        rule: $local.rulePetiteSuite
                    )
                }

                Section("Figures") {
                    FigureRuleRow(title: "Brelan", rule: $local.ruleBrelan)
                    OptionalFigureRuleBlock(
                        toggleTitle: "Activer la Chance",
                        scoreTitle: "Score Chance",
                        isEnabled: Binding(
                            get: { local.isChanceEnabled },
                            set: { local.isChanceEnabled = $0 }
                        ),
                        rule: $local.ruleChance
                    )
                    FigureRuleRow(title: "Full", rule: $local.ruleFull)
                    FigureRuleRow(title: "Carré", rule: $local.ruleCarre)
                    FigureRuleRow(title: "Yams", rule: $local.ruleYams)
                    ExtraYamsBonusBlock(
                        mode: Binding(
                            get: { local.extraYamsBonusMode },
                            set: { local.extraYamsBonusMode = $0 }
                        ),
                        value: $local.extraYamsBonusValue
                    )
                }

                Section {
                    NotationHelpEditor(notation: local)
                } header: {
                    Text("Aides de la feuille de score")
                } footer: {
                    Text("Seules les aides renseignées pourront être affichées pendant une partie.")
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

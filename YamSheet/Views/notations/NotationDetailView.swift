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
    @Bindable var notation: Notation
    @State private var showSaved = false
    
    var body: some View {
        Form {
            Section("Nom") {
                TextField("Nom de la notation", text: $notation.name)
            }
            
            Section(UIStrings.Notation.tooltips) {
                TextField(UIStrings.Notation.tooltipUpper, text: Binding(
                    get: { notation.tooltipUpper ?? "" },
                    set: { notation.tooltipUpper = $0 }
                ))
                TextField(UIStrings.Notation.tooltipMiddle, text: Binding(
                    get: { notation.tooltipMiddle ?? "" },
                    set: { notation.tooltipMiddle = $0 }
                ))
                TextField(UIStrings.Notation.tooltipBottom, text: Binding(
                    get: { notation.tooltipBottom ?? "" },
                    set: { notation.tooltipBottom = $0 }
                ))
            }
            
            Section(UIStrings.Notation.upperSection) {
                Stepper("\(UIStrings.Notation.upperBonusThresholdLabel) : \(notation.upperBonusThreshold)",
                        value: $notation.upperBonusThreshold, in: 0...200)

                Stepper("\(UIStrings.Notation.upperBonusLabel) : \(notation.upperBonusValue)",
                        value: $notation.upperBonusValue, in: 0...200)

                if let tip = notation.tooltipUpper, !tip.isEmpty {
                    Text(tip).font(.footnote).foregroundStyle(.secondary)
                }
            }
            
            Section(UIStrings.Notation.middleSection) {
                Picker(UIStrings.Notation.rulePicker, selection: $notation.middleModeRaw) {
                    ForEach(MiddleRuleMode.allCases) { m in
                        Text(m.rawValue).tag(m.rawValue)
                    }
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



            
            Section("Section basse — règles") {
                FigureRuleRow(title: "Brelan", rule: $notation.ruleBrelan)
                FigureRuleRow(title: "Chance", rule: $notation.ruleChance)
                FigureRuleRow(title: "Full", rule: $notation.ruleFull)

                // Grande suite (5 dés) — config dédiée
                Section(UIStrings.Notation.bigSuite) {
                    Picker(UIStrings.Notation.modeLabel, selection: $notation.suiteBigModeRaw) {
                        ForEach(SuiteBigMode.allCases) { m in
                            Text(m.rawValue).tag(m.rawValue)
                        }
                    }

                    if notation.suiteBigMode == .singleFixed {
                        HStack {
                            Text(UIStrings.Notation.valueFixed).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            CompactWheelPicker(value: $notation.suiteBigFixed,
                                               range: 0...100,
                                               title: UIStrings.Notation.valueFixed)
                        }
                    } else {
                        HStack {
                            Text(UIStrings.Notation.suite15Lbl).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            CompactWheelPicker(value: $notation.suiteBigFixed1to5,
                                               range: 0...100,
                                               title: UIStrings.Notation.suite15Lbl)
                        }
                        HStack {
                            Text(UIStrings.Notation.suite20Lbl).font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            CompactWheelPicker(value: $notation.suiteBigFixed2to6,
                                               range: 0...100,
                                               title: UIStrings.Notation.suite20Lbl)
                        }
                    }
                }




                // Petite suite (4 dés) : on garde FigureRule (.fixed recommandé)
                FigureRuleRow(title: "Petite suite", rule: $notation.rulePetiteSuite)

                
                
                FigureRuleRow(title: "Carré", rule: $notation.ruleCarre)
                FigureRuleRow(title: "Yams", rule: $notation.ruleYams)
                Toggle("Prime Yams supplémentaire", isOn: $notation.extraYamsBonusEnabled)
                Stepper("Bonus Yams +\(notation.extraYamsBonusValue)", value: $notation.extraYamsBonusValue, in: 0...200)
                    .disabled(!notation.extraYamsBonusEnabled)
                if let tip = notation.tooltipBottom, !tip.isEmpty {
                    Text(tip).font(.footnote).foregroundStyle(.secondary)
                }
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



struct FigureRuleRow: View {
    let title: String
    @Binding var rule: FigureRule

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Picker("", selection: Binding(
                    get: { rule.mode.rawValue },
                    set: { rule.mode = BottomRuleMode(rawValue: $0) ?? .raw }
                )) {
                    ForEach(BottomRuleMode.allCases) { m in
                        Text(m.rawValue).tag(m.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            // raw -> rien
            if rule.mode == .fixed {
                HStack {
                    Text("Valeur fixe").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CompactWheelPicker(value: $rule.fixedValue,
                                       range: 0...200,
                                       title: "Valeur fixe")
                }
            } else if rule.mode == .rawPlusFixed {
                HStack {
                    Text("Prime fixe").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CompactWheelPicker(value: $rule.fixedValue,
                                       range: 0...200,
                                       title: "Prime fixe")
                }
            } else if rule.mode == .rawTimes {
                HStack {
                    Text("Multiplicateur").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    CompactWheelPicker(value: $rule.multiplier,
                                       range: 1...10,
                                       title: "Multiplicateur",
                                       display: { "×\($0)" })
                }
            }

            TextField("Tooltip (optionnel)", text: Binding(
                get: { rule.tooltip ?? "" },
                set: { rule.tooltip = $0 }
            ))
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .animation(.default, value: rule.mode)
    }
}




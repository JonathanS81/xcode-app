import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @State private var local: AppSettings = AppSettings()

    var body: some View {
        Form {
            Section(UIStrings.Game.upperSection) {
                Stepper(UIStrings.Notation.upperBonusThresholdLabel+" : \(local.upperBonusThreshold)",
                        value: $local.upperBonusThreshold, in: 0...200)
                Stepper(UIStrings.Notation.upperBonusLabel+" : \(local.upperBonusValue)",
                        value: $local.upperBonusValue, in: 0...200)
            }
            Section(UIStrings.Game.bottomSection) {
                Toggle("Petite suite activée", isOn: $local.enableSmallStraight)
                Stepper("Score petite suite : \(local.smallStraightScore)",
                        value: $local.smallStraightScore, in: 0...100)
                    .disabled(!local.enableSmallStraight)
            }
            Section("App") {
                Toggle("Mode sombre (préférence)", isOn: $local.darkMode)
            }
        }
        .navigationTitle("Réglages")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Enregistrer") { save() }
            }
        }
        .onAppear {
            let s = settings.first ?? AppSettings()
            if settings.isEmpty { context.insert(s) }
            local = s
        }
        .onDisappear {
            save()
        }
    }

    private func save() {
        if let s = settings.first {
            s.upperBonusThreshold = local.upperBonusThreshold
            s.upperBonusValue = local.upperBonusValue
            s.enableSmallStraight = local.enableSmallStraight
            s.smallStraightScore = local.smallStraightScore
            s.darkMode = local.darkMode
            try? context.save()
        } else {
            context.insert(local)
            try? context.save()
        }
    }
}


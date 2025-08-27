import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @State private var local: AppSettings = AppSettings()

    var body: some View {
        Form {
            Section("Section haute") {
                Stepper("Seuil bonus haut : \(local.upperBonusThreshold)", value: $local.upperBonusThreshold, in: 0...200)
                Stepper("Bonus haut : \(local.upperBonusValue)", value: $local.upperBonusValue, in: 0...200)
            }
            Section("Section milieu") {
                Picker("Mode", selection: $local.middleModeRaw) {
                    ForEach(MiddleMode.allCases) { m in
                        Text(m.rawValue).tag(m.rawValue)
                    }
                }
            }
            Section("Section basse") {
                Picker("Mode", selection: $local.bottomModeRaw) {
                    ForEach(BottomMode.allCases) { b in
                        Text(b.rawValue).tag(b.rawValue)
                    }
                }
                Toggle("Petite suite activée", isOn: $local.enableSmallStraight)
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
            s.darkMode = local.darkMode
            s.middleModeRaw = local.middleModeRaw
            s.bottomModeRaw = local.bottomModeRaw
            try? context.save()
        } else {
            context.insert(local)
            try? context.save()
        }
    }
}

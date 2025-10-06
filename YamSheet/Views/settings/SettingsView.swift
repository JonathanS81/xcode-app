import SwiftUI
import SwiftData



struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query private var settings: [AppSettings]
    @State private var local: AppSettings = AppSettings()
#if DEBUG
    @State private var showDebugSheet = false
#endif
    
    @AppStorage("tintLight") private var tintLight: Double = 0.25   // cellules vides
    @AppStorage("tintDark")  private var tintDark:  Double = 0.65   // cellules remplies

    

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
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Teinte claire")
                        Spacer()
                        Text(String(format: "%.2f", tintLight))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $tintLight, in: 0...1, step: 0.01)
                    
                    HStack {
                        Text("Teinte foncée")
                        Spacer()
                        Text(String(format: "%.2f", tintDark))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $tintDark, in: 0...1, step: 0.01)
                    
                    // Prévisualisation rapide
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(tintLight))
                            .frame(width: 48, height: 20)
                            .overlay(Text("clair").font(.caption))
                        
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.accentColor.opacity(max(tintDark, tintLight)))
                            .frame(width: 48, height: 20)
                            .overlay(Text("foncé").font(.caption))
                    }
                    .padding(.top, 4)
                }
                .onChange(of: tintDark) { _, newVal in
                    if newVal < tintLight { tintDark = tintLight }
                }
#if DEBUG
                // Affichage du Debug Settings :
                // 1) NavigationLink (si SettingsView est dans un NavigationStack)
                //NavigationLink("Mode Debug") {
                   // DebugSettingsView()
                //}
                // 2) Fallback : bouton qui ouvre la vue en feuille au cas où il n'y a pas de NavigationStack
                Button {
                    showDebugSheet = true
                } label: {
                    Label("Mode Debug (feuille)", systemImage: "ladybug.fill")
                }
#endif
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
#if DEBUG
        .sheet(isPresented: $showDebugSheet) {
            NavigationStack {
                DebugSettingsView()
            }
        }
#endif
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


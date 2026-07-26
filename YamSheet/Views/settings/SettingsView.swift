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

    // Positionnement des colonnes (0=fixedAll, 1=fixedUpTo4ElsePin, 2=alwaysPinActive)
    @AppStorage("columnRecenterMode") private var columnRecenterModeRaw: Int = 1

    private var installedVersion: String {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "—"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String

        guard let build, !build.isEmpty else {
            return "Version \(version)"
        }
        return "Version \(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Text(installedVersion)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .listRowBackground(Color.clear)

                Section("Feuille de score") {
                    Toggle(
                        "Afficher les aides de notation",
                        isOn: Binding(
                            get: { local.showsScoreHelp },
                            set: { newValue in
                                local.showsScoreHelp = newValue
                                save()
                            }
                        )
                    )

                    Text("Affiche une icône d’information uniquement pour les sections et les lignes dont l’aide a été renseignée dans la notation.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Position des colonnes", selection: $columnRecenterModeRaw) {
                            Text("Colonnes fixes").tag(0)
                            Text("Fixes jusqu’à 4 joueurs").tag(1)
                            Text("Toujours colonne du joueur actif en 1re").tag(2)
                        }
                        .pickerStyle(.segmented)

                        // Aide contextuelle
                        Group {
                            if columnRecenterModeRaw == 0 {
                                Text("Les colonnes ne bougent jamais, quel que soit le nombre de joueurs.")
                            } else if columnRecenterModeRaw == 1 {
                                Text("Jusqu’à 4 joueurs : colonnes fixes. À partir de 5 : le joueur actif est affiché en première colonne.")
                            } else {
                                Text("Toujours : la colonne du joueur actif est affichée en première.")
                            }
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Personnalisation de l’interface") {
                    Toggle("Mode sombre", isOn: $local.darkMode)
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
                    Button {
                        showDebugSheet = true
                    } label: {
                        Label("Mode Debug (feuille)", systemImage: "ladybug.fill")
                    }
#endif
                }

                Section("Données") {
                    NavigationLink {
                        DataTransferView()
                    } label: {
                        Label(
                            "Exporter ou importer",
                            systemImage: "arrow.up.arrow.down.circle"
                        )
                    }
                }

                Section {
                    Button("Enregistrer") {
                        save()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Paramètres")
            .onAppear {
                let s = settings.first ?? AppSettings()
                if settings.isEmpty { context.insert(s) }
                local = s
            }
            .onChange(of: local.darkMode) {
                save()
            }
            .onDisappear {
                save()
            }
#if DEBUG
            .sheet(isPresented: $showDebugSheet) {
                NavigationStack {
                    //DebugSettingsView()
                }
            }
#endif
        }
    }

    private func save() {
        if let s = settings.first {
            s.darkMode = local.darkMode
            s.showsScoreHelp = local.showsScoreHelp
            try? context.save()
        } else {
            context.insert(local)
            try? context.save()
        }
    }
}

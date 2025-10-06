//
//  DebugSettingsView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/10/2025.
//

#if DEBUG
import SwiftUI
import SwiftData

struct DebugSettingsView: View {
    @AppStorage(DebugKeys.debugMode)   private var debugMode: Bool = false
    @AppStorage(DebugKeys.verboseLogs) private var verboseLogs: Bool = true
    @AppStorage(DebugKeys.autoSeed)    private var autoSeed: Bool = true

    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                Toggle("Activer le mode Debug", isOn: $debugMode)
            } footer: {
                Text("Le mode Debug n’est disponible qu’en build DEBUG. En production, ces options sont inactives.")
            }

            if debugMode {
                Section("Options Debug") {
                    Toggle("Logs verbeux (DLog)", isOn: $verboseLogs)
                    Toggle("Seed auto au lancement", isOn: $autoSeed)
                }

                Section("Actions") {
                    Button("Wipe + Seed de démo") {
                        wipeAllData(context)
                        DevSeed.seedIfNeeded(context)
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Debug")
    }

    private func wipeAllData(_ ctx: ModelContext) {
        do {
            let allPlayers = try ctx.fetch(FetchDescriptor<Player>())
            let allGames   = try ctx.fetch(FetchDescriptor<Game>())
            allPlayers.forEach { ctx.delete($0) }
            allGames.forEach { ctx.delete($0) }
            try ctx.save()
        } catch {
            print("Wipe error: \(error)")
        }
    }
}
#endif

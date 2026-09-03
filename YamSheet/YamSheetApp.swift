//
//  YamSheetApp.swift
//  YamSheet
//

import SwiftUI
import SwiftData

@main
struct YamSheetApp: App {
    @StateObject private var statsStore: StatsStore

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([AppSettings.self, Player.self, Game.self, Scorecard.self, Notation.self])
       
        do {
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent("YamSheet.store")

            // === DEBUG DIAGNOSTIC ===
            let fm = FileManager.default
            print("📍 Tentative d’ouverture de la base :", url.path)
            print("📦 Fichier existe ?", fm.fileExists(atPath: url.path))
            let contents = try? fm.contentsOfDirectory(atPath: docs.path)
            print("📂 Contenu du dossier Documents:", contents ?? [])
            // ==========================

            let config = ModelConfiguration(url: url)
            let container = try ModelContainer(for: schema, configurations: config)

            // Vérifie les settings existants
            let context = ModelContext(container)
            if (try? context.fetch(FetchDescriptor<AppSettings>()))?.isEmpty ?? true {
                context.insert(AppSettings())
                try? context.save()
            }

            // Les deux notations de référence sont également installées lors
            // d'une mise à jour, sans modifier les notations créées par l'utilisateur.
            try BuiltInNotations.installIfNeeded(in: context)

            return container
        }catch {
            print("⚠️ Container error: \(error) → mémoire.")
            let mem = ModelConfiguration(isStoredInMemoryOnly: true)
            let container = try! ModelContainer(for: schema, configurations: mem)
            let context = ModelContext(container)
            context.insert(AppSettings())
            try? BuiltInNotations.installIfNeeded(in: context)
            return container
        }
    }()

    init() {
        _statsStore = StateObject(wrappedValue: StatsStore())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(statsStore)
        }
        .modelContainer(sharedModelContainer)
    }
}

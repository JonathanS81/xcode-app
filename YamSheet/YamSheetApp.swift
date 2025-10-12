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
            print("🗂️ SwiftData @", url.path)   // debug
            let config = ModelConfiguration(url: url)
            let container = try ModelContainer(for: schema, configurations: config)

            // Settings par défaut si absent (idempotent)
            let context = ModelContext(container)
            if (try? context.fetch(FetchDescriptor<AppSettings>()))?.isEmpty ?? true {
                context.insert(AppSettings())
                try? context.save()
            }
            return container
        } catch {
            print("⚠️ Container error: \(error) → mémoire.")
            let mem = ModelConfiguration(isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: mem)
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

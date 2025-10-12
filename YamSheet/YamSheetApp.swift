//
//  YamSheetApp.swift
//  YamSheet
//

import SwiftUI
import SwiftData

@main
struct YamSheetApp: App {

    // MARK: - ModelContainer unifié (App Group + migration depuis Documents)
    private let container: ModelContainer = {
        // 1) Tente une migration (copie) de l'ancienne DB (Documents) vers l'App Group si besoin
        StorePaths.migrateIfNeeded()

        // 2) Construit le container à l’URL unique et stable
        //    ⚠️ Liste tous tes @Model ici pour bâtir le schema
        let schema = Schema([
            Player.self,
            Game.self,
            Scorecard.self,
            Notation.self,
            AppSettings.self
        ])

        let config = ModelConfiguration(schema: schema, url: StorePaths.storeURL())

        // (Debug) trace l’endroit exact du store la 1re fois
        StorePaths.logStoreLocation()

        // 3) Un seul container partagé pour toute l’app
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                // -> On injecte le context *unique* dans la hiérarchie
                .modelContext(container.mainContext)
        }
        // Tu peux aussi injecter au niveau Scene (équivalent, mais évite de réinjecter ailleurs)
        .modelContainer(container)
        .onChange(of: scenePhase) { _, newPhase in
            // Sauvegarde prudente quand on passe en arrière-plan
            if newPhase == .inactive || newPhase == .background {
                Task { @MainActor in
                    try? container.mainContext.save()
                }
            }
        }
    }
}

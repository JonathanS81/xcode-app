import SwiftUI
import SwiftData

@main
struct YamSheetApp: App {
    var sharedModelContainer: ModelContainer = {
       
        let schema = Schema([AppSettings.self, Player.self, Game.self, Scorecard.self, Notation.self])
        // Choose a fixed on-disk store URL so we can clean it up if incompatible.
        let storeURL = URL.documentsDirectory.appending(path: "YamSheet.store")
        let diskConfig = ModelConfiguration(url: storeURL)
        // 1) Try disk store
        do {
            let container = try ModelContainer(for: schema, configurations: diskConfig)
            // Bootstrap default settings once
            let context = ModelContext(container)
          if (try? context.fetch(FetchDescriptor<AppSettings>()))?.isEmpty ?? true {
                context.insert(AppSettings())
                try? context.save()
            }
            return container
        } catch {
            // 2) Self-heal: delete the on-disk store then retry once.
            print("SwiftData disk container failed: \(error). Attempting to delete store and retry…")
            do {
                try? FileManager.default.removeItem(at: storeURL)
                let container = try ModelContainer(for: schema, configurations: diskConfig)
                let context = ModelContext(container)
                if (try? context.fetch(FetchDescriptor<AppSettings>()))?.isEmpty ?? true {
                    context.insert(AppSettings())
                    try? context.save()
                }
                return container
            } catch {
                // 3) Fallback: in-memory
                print("Disk retry failed: \(error). Falling back to in-memory container.")
                let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
                let memoryContainer = try! ModelContainer(for: schema, configurations: memoryConfig)
                return memoryContainer
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}

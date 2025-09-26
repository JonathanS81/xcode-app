import SwiftUI
import SwiftData

@main
struct YamSheetApp: App {
    @StateObject private var statsStore: StatsStore

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([AppSettings.self, Player.self, Game.self, Scorecard.self, Notation.self])
        do {
            // ✅ Reuse the legacy/custom on-disk location so existing data is found on device
            let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let url = docs.appendingPathComponent("YamSheet.store")
            let config = ModelConfiguration(url: url)

            let container = try ModelContainer(for: schema, configurations: config)

            // Bootstrap default settings once (idempotent)
            let context = ModelContext(container)
            if (try? context.fetch(FetchDescriptor<AppSettings>()))?.isEmpty ?? true {
                context.insert(AppSettings())
                try? context.save()
            }
            return container
        } catch {
            print("SwiftData custom container failed: \(error). Falling back to in-memory container.")
            let memoryConfig = ModelConfiguration(isStoredInMemoryOnly: true)
            let memoryContainer = try! ModelContainer(for: schema, configurations: memoryConfig)
            return memoryContainer
        }
    }()

    init() {
        // Inject the SwiftData context into StatsStore so it can fetch existing data
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

import Foundation
import SwiftData

struct SampleData {
    static func ensureSamples(_ context: ModelContext) {
        let playersCount = (try? context.fetch(FetchDescriptor<Player>()))?.count ?? 0
        if playersCount == 0 {
            context.insert(Player(name: "Alice Dupont", nickname: "Ali"))
            context.insert(Player(name: "Bruno Martin", nickname: "Bru"))
            context.insert(Player(name: "Chloé Petit", nickname: "Clo"))
            try? context.save()
        }
    }
}

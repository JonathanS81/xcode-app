import SwiftUI
import SwiftData

struct PlayersListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Player.name) private var players: [Player]
    @State private var showingNew = false

    private var sortedPlayers: [Player] {
        players.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName)
                == .orderedAscending
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sortedPlayers) { p in
                    NavigationLink(value: p.id) {
                        Text(p.displayName).bold()
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { sortedPlayers[$0] }.forEach(context.delete)
                    try? context.save()
                }
            }
            .navigationTitle(UIStrings.Common.players)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Label(UIStrings.Common.toadd, systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewPlayerView()
            }
            .navigationDestination(for: UUID.self) { id in
                if let p = sortedPlayers.first(where: { $0.id == id }) {
                    PlayerDetailView(player: p)
                } else {
                    Text("Introuvable")
                }
            }
        }
    }
}

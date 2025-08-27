import SwiftUI
import SwiftData

struct PlayersListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Player.name) private var players: [Player]
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(players) { p in
                    NavigationLink(value: p.id) {
                        VStack(alignment: .leading) {
                            Text(p.name).bold()
                            Text(p.nickname).foregroundStyle(.secondary).font(.caption)
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { players[$0] }.forEach(context.delete)
                    try? context.save()
                }
            }
            .navigationTitle("Joueurs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingNew = true } label: { Label("Ajouter", systemImage: "plus") }
                }
            }
            .sheet(isPresented: $showingNew) {
                NewPlayerView()
            }
            .navigationDestination(for: UUID.self) { id in
                if let p = players.first(where: { $0.id == id }) {
                    PlayerDetailView(player: p)
                } else {
                    Text("Introuvable")
                }
            }
        }
    }
}

import SwiftUI
import SwiftData

struct GamesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Game.createdAt, order: .reverse) private var games: [Game]
    @State private var showingNewGame = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(games) { game in
                    NavigationLink(value: game.id) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(UIStrings.Common.game+" "+UIStrings.Common.dash+"  \(game.createdAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.headline)
                            Text(game.comment).foregroundStyle(.secondary)
                            HStack {
                               // Label("\(game.columns) colonne(s)", systemImage: "square.grid.3x1.folder.fill.badge.plus")
                                Spacer()
                                Text(game.status == .completed ? UIStrings.Common.over : UIStrings.Common.inprogress)
                                    .font(.caption).padding(6).background(game.status == .completed ? .green.opacity(0.15) : .blue.opacity(0.15)).clipShape(Capsule())
                            }.font(.caption)
                        }
                    }
                }
                .onDelete { indexSet in
                    indexSet.map { games[$0] }.forEach(context.delete)
                    try? context.save()
                }
            }
            .navigationTitle(UIStrings.Common.games)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingNewGame = true
                    } label: {
                        Label("Nouvelle partie", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingNewGame) {
                NewGameView()
                    .presentationDetents([.large])
            }
            .navigationDestination(for: UUID.self) { id in
                if let game = games.first(where: { $0.id == id }) {
                    GameDetailView(game: game)
                } else {
                    Text("Partie introuvable")
                }
            }
            .task {
                SampleData.ensureSamples(context)
            }
        }
    }
}

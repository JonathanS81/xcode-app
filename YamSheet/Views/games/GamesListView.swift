import SwiftUI
import SwiftData

struct GamesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Game.createdAt, order: .reverse) private var games: [Game]
    @State private var showingNewGame = false

    // Filtre : Actives (en cours + en pause) / Terminées
    enum Filter: String, CaseIterable, Identifiable {
        case active    = "Actives"
        case completed = "Terminées"
        var id: String { rawValue }
    }
    @State private var filter: Filter = .active

    private var filteredGames: [Game] {
        games.filter { g in
            switch filter {
            case .active:
                return g.statusOrDefault == .inProgress || g.statusOrDefault == .paused
            case .completed:
                return g.statusOrDefault == .completed
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("Filtre", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                // Liste filtrée
                if filteredGames.isEmpty {
                    ContentUnavailableView(
                        "Aucune partie",
                        systemImage: "rectangle.on.rectangle.slash",
                        description: Text("Change le filtre ou crée une nouvelle partie.")
                    )
                    .padding()
                } else {
                    List {
                        ForEach(filteredGames) { game in
                            NavigationLink(value: game.id) {
                                row(for: game)
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.map { filteredGames[$0] }.forEach(context.delete)
                            try? context.save()
                        }
                    }
                    .listStyle(.insetGrouped)
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
                    Text("Partie introuvable").foregroundStyle(.secondary)
                }
            }
            .task {
#if DEBUG && targetEnvironment(simulator)
                DevSeed.seedIfNeeded(context)
                //SampleData.ensureSamples(context)
            #endif
            }
        }
    }

    // MARK: - Helpers (Players & Location)
    private func participantNicknames(for game: Game) -> String {
        let ids = game.participantIDs
        guard !ids.isEmpty else { return "—" }
        // Fetch only players whose id is in participantIDs
        let descriptor = FetchDescriptor<Player>()
        let players: [Player] = (try? context.fetch(descriptor)) ?? []
        let map: [UUID: Player] = Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
        let names: [String] = ids.compactMap { pid in
            if let p = map[pid] {
                let nick = p.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
                return nick.isEmpty ? p.name : nick
            }
            return nil
        }
        return names.joined(separator: ", ")
    }

    /// Placeholder pour un futur champ `location` dans `Game`.
    /// Retourne nil tant que le modèle ne stocke pas explicitement la géolocalisation.
    private func gameLocation(for game: Game) -> String? {
        return nil
    }

    // MARK: - Row
    @ViewBuilder
    private func row(for game: Game) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Titre = nom de la partie (ou fallback)
            Text(game.name.isEmpty ? UIStrings.Common.game : game.name)
                .font(.headline)

            // Date (toujours visible)
            Text(game.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Participants (surnoms ou noms)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "person.2")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(participantNicknames(for: game))
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            // Géolocalisation (si disponible un jour)
            if let loc = gameLocation(for: game) {
                HStack(spacing: 6) {
                    Image(systemName: "mappin.and.ellipse")
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                    Text(loc)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            // Badge de statut aligné à droite
            HStack { Spacer(); statusBadge(for: game.statusOrDefault) }
                .font(.caption)
        }
        .padding(.vertical, 6)
    }

    // MARK: - Status badge
    @ViewBuilder
    private func statusBadge(for status: GameStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .inProgress: return ("En cours", .blue)
            case .paused:     return ("En pause", .orange)
            case .completed:  return ("Terminée", .green)
            }
        }()

        Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }
}


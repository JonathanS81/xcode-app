import SwiftUI
import SwiftData

struct GamesListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Game.createdAt, order: .reverse) private var games: [Game]
    @Query(sort: \Player.nickname) private var players: [Player]

    @State private var showingNewGame = false
    @State private var searchText = ""
    @State private var selectedPlayerID: UUID?
    @State private var navigationPath: [UUID] = []

    enum Filter: String, CaseIterable, Identifiable {
        case active = "Actives"
        case completed = "Historique"

        var id: String { rawValue }
    }

    @State private var filter: Filter = .active

    private struct DisplaySnapshot {
        let active: [Game]
        let completed: [Game]
        let recentCompleted: [Game]
        let monthlyArchives: [GamesMonthArchive]
    }

    private var playersByID: [UUID: Player] {
        Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
    }

    private func selectedPlayerName(
        playersByID: [UUID: Player]
    ) -> String {
        guard let selectedPlayerID,
              let player = playersByID[selectedPlayerID] else {
            return "Tous les joueurs"
        }
        return GamesListFormatting.displayName(for: player)
    }

    private func makeDisplaySnapshot(
        playersByID: [UUID: Player]
    ) -> DisplaySnapshot {
        let query = searchText.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        var active: [Game] = []
        var completed: [Game] = []

        for game in games where matchesCurrentFilters(
            game,
            playersByID: playersByID,
            query: query
        ) {
            switch game.statusOrDefault {
            case .inProgress, .paused:
                active.append(game)
            case .completed:
                completed.append(game)
            }
        }

        completed.sort {
            GamesListFormatting.archiveDate(for: $0)
                > GamesListFormatting.archiveDate(for: $1)
        }

        let cutoff = recentCutoff
        let recentCompleted = completed.filter {
            GamesListFormatting.archiveDate(for: $0) >= cutoff
        }
        let olderGames = completed.filter {
            GamesListFormatting.archiveDate(for: $0) < cutoff
        }
        let grouped = Dictionary(grouping: olderGames) {
            GamesListFormatting.monthStart(
                for: GamesListFormatting.archiveDate(for: $0)
            )
        }

        let monthlyArchives = grouped
            .map { GamesMonthArchive(monthStart: $0.key, games: $0.value) }
            .sorted { $0.monthStart > $1.monthStart }

        return DisplaySnapshot(
            active: active,
            completed: completed,
            recentCompleted: recentCompleted,
            monthlyArchives: monthlyArchives
        )
    }

    private var recentCutoff: Date {
        Calendar.current.date(
            byAdding: .day,
            value: -30,
            to: Calendar.current.startOfDay(for: Date())
        ) ?? Date.distantPast
    }

    var body: some View {
        let playerLookup = playersByID
        let display = makeDisplaySnapshot(playersByID: playerLookup)
        let playerName = selectedPlayerName(playersByID: playerLookup)

        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                Picker("Filtre", selection: $filter) {
                    ForEach(Filter.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                .pickerStyle(.segmented)
                .padding([.horizontal, .top])

                searchField
                playerFilter(selectedPlayerName: playerName)

                switch filter {
                case .active:
                    activeGamesContent(
                        games: display.active,
                        playersByID: playerLookup
                    )
                case .completed:
                    historyContent(
                        snapshot: display,
                        playersByID: playerLookup
                    )
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
                        .id(game.id)
                } else {
                    Text("Partie introuvable")
                        .foregroundStyle(.secondary)
                }
            }
            .task {
#if DEBUG && targetEnvironment(simulator)
                DevSeed.seedIfNeeded(context)
#endif
            }
            .onReceive(NotificationCenter.default.publisher(for: .openGameFromList)) { notification in
                guard let gameID = notification.object as? UUID else { return }

                // Une première partie peut encore être affichée dans la feuille
                // « Nouvelle partie ». On ferme d'abord cette feuille, puis on
                // ouvre la revanche dans la navigation principale.
                let navigationDelay = showingNewGame ? 0.30 : 0.05
                showingNewGame = false

                // Laisse également à SwiftData le temps de publier la nouvelle
                // partie dans la requête avant de remplacer l'écran courant.
                DispatchQueue.main.asyncAfter(deadline: .now() + navigationDelay) {
                    navigationPath = [gameID]
                }
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Partie ou joueur", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Effacer la recherche")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(Color.secondary.opacity(0.10))
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.top, 10)
    }

    private func playerFilter(
        selectedPlayerName: String
    ) -> some View {
        Menu {
            Button {
                selectedPlayerID = nil
            } label: {
                if selectedPlayerID == nil {
                    Label("Tous les joueurs", systemImage: "checkmark")
                } else {
                    Text("Tous les joueurs")
                }
            }

            if !players.isEmpty {
                Divider()
            }

            ForEach(players) { player in
                Button {
                    selectedPlayerID = player.id
                } label: {
                    if selectedPlayerID == player.id {
                        Label(
                            GamesListFormatting.displayName(for: player),
                            systemImage: "checkmark"
                        )
                    } else {
                        Text(GamesListFormatting.displayName(for: player))
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                Text(selectedPlayerName)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
            }
            .font(.subheadline)
            .foregroundStyle(.primary)
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(Color.secondary.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .accessibilityLabel("Filtrer par joueur, sélection actuelle : \(selectedPlayerName)")
    }

    @ViewBuilder
    private func activeGamesContent(
        games: [Game],
        playersByID: [UUID: Player]
    ) -> some View {
        if games.isEmpty {
            emptyState(
                title: hasActiveFilters ? "Aucun résultat" : "Aucune partie active",
                description: hasActiveFilters
                    ? "Modifie la recherche ou le joueur sélectionné."
                    : "Crée une nouvelle partie pour commencer."
            )
        } else {
            List {
                Section {
                    ForEach(games) { game in
                        gameLink(for: game, playersByID: playersByID)
                    }
                    .onDelete { offsets in
                        delete(offsets, from: games)
                    }
                } header: {
                    listHeader(
                        title: "Parties actives",
                        count: games.count
                    )
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    @ViewBuilder
    private func historyContent(
        snapshot: DisplaySnapshot,
        playersByID: [UUID: Player]
    ) -> some View {
        if snapshot.completed.isEmpty {
            emptyState(
                title: hasActiveFilters ? "Aucun résultat" : "Aucune partie terminée",
                description: hasActiveFilters
                    ? "Modifie la recherche ou le joueur sélectionné."
                    : "Les parties terminées apparaîtront ici."
            )
        } else {
            List {
                if !snapshot.recentCompleted.isEmpty {
                    Section {
                        ForEach(snapshot.recentCompleted) { game in
                            gameLink(for: game, playersByID: playersByID)
                        }
                        .onDelete { offsets in
                            delete(offsets, from: snapshot.recentCompleted)
                        }
                    } header: {
                        listHeader(
                            title: "30 derniers jours",
                            count: snapshot.recentCompleted.count
                        )
                    }
                }

                if !snapshot.monthlyArchives.isEmpty {
                    Section("Archives") {
                        ForEach(snapshot.monthlyArchives) { archive in
                            NavigationLink {
                                GamesArchiveMonthView(
                                    monthStart: archive.monthStart,
                                    selectedPlayerID: selectedPlayerID,
                                    initialSearchText: searchText
                                )
                            } label: {
                                HStack {
                                    Label(
                                        GamesListFormatting.monthTitle(
                                            for: archive.monthStart
                                        ),
                                        systemImage: "calendar"
                                    )
                                    Spacer()
                                    Text(
                                        "\(archive.games.count) "
                                            + (archive.games.count > 1 ? "parties" : "partie")
                                    )
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var hasActiveFilters: Bool {
        selectedPlayerID != nil
            || !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func matchesCurrentFilters(
        _ game: Game,
        playersByID: [UUID: Player],
        query: String
    ) -> Bool {
        if let selectedPlayerID,
           !game.participantIDs.contains(selectedPlayerID) {
            return false
        }

        guard !query.isEmpty else { return true }

        if game.name.localizedCaseInsensitiveContains(query) {
            return true
        }

        return GamesListFormatting
            .participantNames(for: game, playersByID: playersByID)
            .contains { $0.localizedCaseInsensitiveContains(query) }
    }

    private func gameLink(
        for game: Game,
        playersByID: [UUID: Player]
    ) -> some View {
        NavigationLink(value: game.id) {
            GameListRow(
                game: game,
                participantNames: GamesListFormatting.participantNames(
                    for: game,
                    playersByID: playersByID
                )
            )
        }
    }

    private func delete(_ offsets: IndexSet, from displayedGames: [Game]) {
        offsets
            .compactMap { displayedGames.indices.contains($0) ? displayedGames[$0] : nil }
            .forEach(context.delete)
        try? context.save()
    }

    private func listHeader(title: String, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text("\(count)")
                .monospacedDigit()
        }
    }

    private func emptyState(title: String, description: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: "rectangle.on.rectangle.slash",
            description: Text(description)
        )
        .padding()
    }
}

struct GamesMonthArchive: Identifiable {
    let monthStart: Date
    let games: [Game]

    var id: Date { monthStart }
}

enum GamesListFormatting {
    static func displayName(for player: Player) -> String {
        let nickname = player.nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if !nickname.isEmpty { return nickname }

        let name = player.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Joueur" : name
    }

    static func participantNames(
        for game: Game,
        playersByID: [UUID: Player]
    ) -> [String] {
        game.participantIDs.compactMap { id in
            playersByID[id].map(displayName(for:))
        }
    }

    static func archiveDate(for game: Game) -> Date {
        game.endedAt ?? game.createdAt
    }

    static func monthStart(for date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: date)
        return calendar.date(from: components) ?? calendar.startOfDay(for: date)
    }

    static func monthTitle(for date: Date) -> String {
        date
            .formatted(.dateTime.month(.wide).year().locale(Locale.current))
            .capitalized
    }
}

struct GameListRow: View {
    let game: Game
    let participantNames: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(game.name.isEmpty ? UIStrings.Common.game : game.name)
                .font(.headline)

            Text(
                GamesListFormatting.archiveDate(for: game)
                    .formatted(date: .abbreviated, time: .shortened)
            )
            .font(.subheadline)
            .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: "person.2")
                    .imageScale(.small)
                    .foregroundStyle(.secondary)
                Text(participantNames.isEmpty ? "—" : participantNames.joined(separator: ", "))
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack {
                Spacer()
                statusBadge
            }
        }
        .padding(.vertical, 6)
    }

    private var statusBadge: some View {
        let appearance: (text: String, color: Color) = {
            switch game.statusOrDefault {
            case .inProgress:
                return ("En cours", .blue)
            case .paused:
                return ("En pause", .orange)
            case .completed:
                return ("Terminée", .green)
            }
        }()

        return Text(appearance.text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(appearance.color.opacity(0.15))
            .clipShape(Capsule())
    }
}

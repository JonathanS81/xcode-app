import SwiftUI
import SwiftData

struct GamesArchiveMonthView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Game.createdAt, order: .reverse) private var games: [Game]
    @Query(sort: \Player.nickname) private var players: [Player]

    let monthStart: Date
    let selectedPlayerID: UUID?

    @State private var searchText: String

    init(
        monthStart: Date,
        selectedPlayerID: UUID?,
        initialSearchText: String = ""
    ) {
        self.monthStart = monthStart
        self.selectedPlayerID = selectedPlayerID
        _searchText = State(initialValue: initialSearchText)
    }

    private var playersByID: [UUID: Player] {
        Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
    }

    private var monthEnd: Date {
        Calendar.current.date(byAdding: .month, value: 1, to: monthStart)
            ?? Date.distantFuture
    }

    private var filteredGames: [Game] {
        games
            .filter { game in
                let date = GamesListFormatting.archiveDate(for: game)
                guard game.statusOrDefault == .completed,
                      date >= monthStart,
                      date < monthEnd else {
                    return false
                }

                if let selectedPlayerID,
                   !game.participantIDs.contains(selectedPlayerID) {
                    return false
                }

                let query = searchText.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
                guard !query.isEmpty else { return true }

                if game.name.localizedCaseInsensitiveContains(query) {
                    return true
                }

                return GamesListFormatting
                    .participantNames(for: game, playersByID: playersByID)
                    .contains { $0.localizedCaseInsensitiveContains(query) }
            }
            .sorted {
                GamesListFormatting.archiveDate(for: $0)
                    > GamesListFormatting.archiveDate(for: $1)
            }
    }

    var body: some View {
        Group {
            if filteredGames.isEmpty {
                ContentUnavailableView(
                    "Aucune partie",
                    systemImage: "calendar.badge.exclamationmark",
                    description: Text("Aucune partie ne correspond à cette recherche.")
                )
            } else {
                List {
                    Section {
                        ForEach(filteredGames) { game in
                            NavigationLink(value: game.id) {
                                GameListRow(
                                    game: game,
                                    participantNames: GamesListFormatting
                                        .participantNames(
                                            for: game,
                                            playersByID: playersByID
                                        )
                                )
                            }
                        }
                        .onDelete(perform: delete)
                    } header: {
                        HStack {
                            Text(GamesListFormatting.monthTitle(for: monthStart))
                            Spacer()
                            Text("\(filteredGames.count)")
                                .monospacedDigit()
                        }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle(GamesListFormatting.monthTitle(for: monthStart))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Partie ou joueur")
    }

    private func delete(_ offsets: IndexSet) {
        offsets
            .compactMap { filteredGames.indices.contains($0) ? filteredGames[$0] : nil }
            .forEach(context.delete)
        try? context.save()
    }
}

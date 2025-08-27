import SwiftUI
import SwiftData

struct NewGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query(sort: \Player.name) private var players: [Player]
    @Query private var settings: [AppSettings]

    @State private var selected: Set<UUID> = []
    @State private var columns: Int = 1
    @State private var comment: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Joueurs") {
                    if players.isEmpty {
                        Text("Aucun joueur. Ajoutez des joueurs depuis l'onglet Joueurs.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(players) { p in
                            Toggle(isOn: Binding(
                                get: { selected.contains(p.id) },
                                set: { newVal in
                                    if newVal { selected.insert(p.id) } else { selected.remove(p.id) }
                                })) {
                                    VStack(alignment: .leading) {
                                        Text(p.name).bold()
                                        Text(p.nickname).foregroundStyle(.secondary).font(.caption)
                                    }
                                }
                        }
                    }
                }
                Section("Options") {
                    Stepper("Colonnes : \(columns)", value: $columns, in: 1...3)
                    TextField("Commentaire", text: $comment)
                }
            }
            .navigationTitle("Nouvelle partie")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { createGame() }.disabled(selected.isEmpty)
                }
            }
        }
    }

    private func createGame() {
        let appSettings = settings.first ?? AppSettings()
        if settings.isEmpty {
            context.insert(appSettings)
        }
        let game = Game(settings: appSettings, columns: columns, comment: comment)
        // Create scorecards
        for pid in selected {
            let sc = Scorecard(playerID: pid, columns: columns)
            sc.game = game
            context.insert(sc)
        }
        context.insert(game)
        do {
            try context.save()
        } catch {
            print("Error saving game: \(error)")
        }
        dismiss()
    }
}

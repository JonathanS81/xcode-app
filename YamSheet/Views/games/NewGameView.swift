import SwiftUI
import SwiftData

// Une seule source de vérité pour la feuille présentée
private enum CreationSheet: Identifiable {
    case newPlayer
    case newNotation
    var id: Int { hashValue }
}

struct NewGameView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    // Données
    @Query(sort: \Player.nickname) private var players: [Player]
    @Query(sort: \Notation.name)  private var notations: [Notation]
    @Query                       private var settings: [AppSettings]

    // Sélections
    @State private var selectedPlayerIDs: Set<Player.ID> = []
    @State private var selectedNotationID: Notation.ID? = nil

    // Options
    @State private var enableChance: Bool = true
    @State private var enableSmallStraight: Bool = true
    @State private var comment: String = ""
    @State private var gameName: String = ""

    // Navigation directe vers la partie créée
    @State private var createdGame: Game? = nil

    // Feuille modale unique
    @State private var activeSheet: CreationSheet?

    // Helpers
    private var selectedNotation: Notation? {
        notations.first(where: { $0.id == selectedNotationID }) ?? notations.first
    }
    private var defaultGameName: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "fr_FR")
        df.dateFormat = "dd/MM/yyyy"
        return "Nom \(df.string(from: Date()))"
    }

    var body: some View {
        NavigationStack {
            Form {
                // --- NOM EN PREMIER ---
                Section("Nom de la partie") {
                    TextField("Nom :", text: $gameName)
                        .textInputAutocapitalization(.words)
                }

                // --- JOUEURS (interrupteurs isOn) ---
                Section("Joueurs") {
                    if players.isEmpty {
                        Text("Aucun joueur.").foregroundStyle(.secondary)
                    } else {
                        ForEach(players) { p in
                            Toggle(isOn: Binding(
                                get: { selectedPlayerIDs.contains(p.id) },
                                set: { isOn in
                                    if isOn { selectedPlayerIDs.insert(p.id) }
                                    else     { selectedPlayerIDs.remove(p.id) }
                                }
                            )) {
                                Text(p.nickname)
                            }
                        }
                    }
                    Button {
                        activeSheet = .newPlayer
                    } label: {
                        Label("Nouveau joueur", systemImage: "plus.circle")
                    }
                }

                // --- NOTATION ---
                Section("Notation") {
                    if notations.isEmpty {
                        Text("Aucune notation. Créez-en une.").foregroundStyle(.secondary)
                    } else {
                        Picker("Choisir une notation", selection: Binding(
                            get: { selectedNotationID ?? notations.first?.id },
                            set: { selectedNotationID = $0 }
                        )) {
                            ForEach(notations) { n in
                                Text(n.name).tag(n.id as Notation.ID?)
                            }
                        }
                    }
                    Button {
                        activeSheet = .newNotation
                    } label: {
                        Label("Créer une notation", systemImage: "plus.square.on.square")
                    }
                }

                // --- OPTIONS ---
                Section("Options") {
                    Toggle("Inclure Chance", isOn: $enableChance)
                    Toggle("Activer Petite suite", isOn: $enableSmallStraight)
                    TextField("Commentaire", text: $comment)
                }

                // --- ACTION (gros bouton plein) ---
                Section {
                    Button {
                        createGame()
                    } label: {
                        Text("Créer la partie")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selectedPlayerIDs.isEmpty || selectedNotation == nil)
                }
            }
            .navigationTitle("Nouvelle partie")
            .navigationDestination(item: $createdGame) { g in
                GameDetailView(game: g)
                    .navigationBarBackButtonHidden(true) // pas de “Back”
            }
            .onAppear {
                if gameName.isEmpty { gameName = defaultGameName }
                if selectedNotationID == nil { selectedNotationID = notations.first?.id }
            }
            // --- FEUILLE MODALE UNIQUE ---
            .sheet(item: $activeSheet) { which in
                switch which {
                case .newPlayer:
                    // ► VERSION COMPLÈTE du formulaire joueur
                    NavigationStack {
                        PlayerEditorView { newPlayer in
                            // auto-sélectionner le nouveau joueur
                            selectedPlayerIDs.insert(newPlayer.id)
                            activeSheet = nil
                        }
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)

                case .newNotation:
                    // ► Utilise NotationEditorView avec callback de création
                    NavigationStack {
                        NotationEditorView(onCreated: { newNotation in
                            // auto-sélectionner la nouvelle notation
                            selectedNotationID = newNotation.id
                            activeSheet = nil
                        })
                        .navigationTitle("Nouvelle notation")
                        // IMPORTANT : plus de bouton "Fermer" redondant ici
                    }
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: - Création de la partie
    private func createGame() {
        guard let notation = selectedNotation else { return }
        let chosenPlayers = players.filter { selectedPlayerIDs.contains($0.id) }
        guard !chosenPlayers.isEmpty else { return }

        // Nom final
        let nameToUse = gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultGameName
            : gameName

        // Récupère/Crée AppSettings
        let appSettings: AppSettings = {
            if let s = settings.first { return s }
            let s = AppSettings()
            context.insert(s)
            return s
        }()

        // Snapshot de la notation (si Game attend un NotationSnapshot)
        let snapshot = notation.snapshot()

        // IMPORTANT : utilise l'init réel de Game
        let game = Game(settings: appSettings, notation: snapshot, columns: 1, comment: comment)

        // Nom + options par partie
        game.name = nameToUse
        game.enableChance = enableChance
        game.enableSmallStraight = enableSmallStraight

        // Scorecards pour chaque joueur
        for p in chosenPlayers {
            let sc = Scorecard(playerID: p.id, columns: 1)
            sc.game = game
            context.insert(sc)
        }

        // Sauvegarde & navigation directe vers la feuille (sans retour)
        context.insert(game)
        try? context.save()

        activeSheet = nil
        createdGame = game
    }
}


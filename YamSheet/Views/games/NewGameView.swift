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
    private let gameNameMaxLength = 40

    // Données
    @Query(sort: \Player.nickname) private var players: [Player]
    @Query(sort: \Notation.name)  private var notations: [Notation]
    @Query                       private var games: [Game]
    @Query                       private var settings: [AppSettings]

    // Sélections
    @State private var selectedPlayerIDs: Set<UUID> = []
    @State private var selectedNotationID: Notation.ID? = nil
    @State private var showsAllPlayers = false
    @FocusState private var isGameNameFocused: Bool

    // Options
    @State private var comment: String = ""
    @State private var gameName: String = ""

    // Navigation directe vers la partie créée
    @State private var createdGame: Game? = nil

    // Payload pour présenter la feuille d'ordre avec les joueurs déjà calculés.
    private struct OrderPayload: Identifiable { let id = UUID(); let players: [Player] }
    @State private var orderPayload: OrderPayload? = nil

    // Feuille modale unique
    @State private var activeSheet: CreationSheet?

    // Helpers
    private var selectedNotation: Notation? {
        notations.first(where: { $0.id == selectedNotationID }) ?? notations.first
    }
    private var playersByActivity: [Player] {
        var countsByPlayerID: [UUID: Int] = [:]
        for game in games {
            for playerID in Set(game.participantIDs) {
                countsByPlayerID[playerID, default: 0] += 1
            }
        }

        return players.sorted { lhs, rhs in
            let lhsCount = countsByPlayerID[lhs.id, default: 0]
            let rhsCount = countsByPlayerID[rhs.id, default: 0]
            if lhsCount != rhsCount { return lhsCount > rhsCount }
            return lhs.nickname.localizedCaseInsensitiveCompare(rhs.nickname) == .orderedAscending
        }
    }
    private var displayedPlayers: [Player] {
        showsAllPlayers ? playersByActivity : Array(playersByActivity.prefix(5))
    }
    private var hiddenPlayersCount: Int {
        max(0, playersByActivity.count - displayedPlayers.count)
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
                Section {
                    TextField(
                        "Nom :",
                        text: Binding(
                            get: { gameName },
                            set: { gameName = String($0.prefix(gameNameMaxLength)) }
                        )
                    )
                        .textInputAutocapitalization(.words)
                        .focused($isGameNameFocused)
                } header: {
                    HStack {
                        Text("Nom de la partie")
                        Spacer()
                        Text("\(gameName.count)/\(gameNameMaxLength)")
                            .monospacedDigit()
                            .foregroundStyle(
                                gameName.count == gameNameMaxLength
                                    ? Color.orange
                                    : Color.secondary
                            )
                    }
                }

                // --- JOUEURS (interrupteurs isOn) ---
                Section("Joueurs") {
                    if players.isEmpty {
                        Text("Aucun joueur.").foregroundStyle(.secondary)
                    } else {
                        ForEach(displayedPlayers) { p in
                            Toggle(isOn: Binding(
                                get: { selectedPlayerIDs.contains(p.id) },
                                set: { isOn in
                                    isGameNameFocused = false
                                    if isOn { selectedPlayerIDs.insert(p.id) }
                                    else     { selectedPlayerIDs.remove(p.id) }
                                }
                            )) {
                                Text(p.nickname)
                            }
                        }

                        if hiddenPlayersCount > 0 {
                            Button {
                                isGameNameFocused = false
                                showsAllPlayers = true
                            } label: {
                                Label(
                                    "Voir plus (\(hiddenPlayersCount))",
                                    systemImage: "chevron.down"
                                )
                            }
                            .buttonStyle(.borderless)
                        } else if showsAllPlayers && playersByActivity.count > 5 {
                            Button {
                                isGameNameFocused = false
                                showsAllPlayers = false
                            } label: {
                                Label("Voir moins", systemImage: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    Button {
                        isGameNameFocused = false
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
                            set: {
                                isGameNameFocused = false
                                selectedNotationID = $0
                            }
                        )) {
                            ForEach(notations) { n in
                                Text(n.name).tag(n.id as Notation.ID?)
                            }
                        }
                    }
                    Button {
                        isGameNameFocused = false
                        activeSheet = .newNotation
                    } label: {
                        Label("Créer une notation", systemImage: "plus.square.on.square")
                    }
                }

                // --- RÉCAPITULATIF DE LA NOTATION ---
                Section("Détails de la notation") {
                    if let notation = selectedNotation {
                        if !notation.comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(notation.comment)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        LabeledContent(
                            "Chance",
                            value: notation.visibility.isEnabled(.chance) && notation.isChanceEnabled
                                ? "Activée"
                                : "Désactivée"
                        )
                        LabeledContent(
                            "Petite suite",
                            value: notation.visibility.isEnabled(.petiteSuite) && notation.isSmallStraightEnabled
                                ? "Activée"
                                : "Désactivée"
                        )
                        LabeledContent(
                            "Prime Yams supplémentaire",
                            value: notation.visibility.isEnabled(.yams)
                                ? notation.extraYamsBonusMode.label
                                : "Désactivée"
                        )
                    }
                }
                .simultaneousGesture(TapGesture().onEnded {
                    isGameNameFocused = false
                })

                Section("Commentaire de la partie") {
                    TextField("Commentaire", text: $comment)
                }
                .simultaneousGesture(TapGesture().onEnded {
                    isGameNameFocused = false
                })

                // --- ACTION (gros bouton plein) ---
                Section {
                    Button {
                        isGameNameFocused = false
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
            .scrollDismissesKeyboard(.interactively)
            .background {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isGameNameFocused = false
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
                    NavigationStack {
                        NewPlayerView(onCreated: { newPlayer in
                            // auto-sélectionner le nouveau joueur
                            selectedPlayerIDs.insert(newPlayer.id)
                            showsAllPlayers = true
                            activeSheet = nil
                        })
                        .navigationTitle("Nouveau joueur")
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
            // === Feuille d'ordre des joueurs (basée sur un payload pour éviter un tableau vide) ===
            .fullScreenCover(item: $orderPayload) { payload in
                OrderSetupSheet(
                    players: payload.players,
                    idFor: { $0.id },
                    nameFor: { $0.nickname },
                    onConfirm: { orderedIDs in
                        finalizeGame(with: orderedIDs)
                    }
                )
                .interactiveDismissDisabled(true) // empêche le swipe-down qui ramènerait à l’écran précédent
            }
            .overlay {
                // Rideau plein écran pour éviter de revoir brièvement le formulaire
                if orderPayload != nil || createdGame != nil {
                    Color(.systemBackground).ignoresSafeArea()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .closeToGamesList)) { _ in
            // Ferme la feuille de création si on termine/mete en pause depuis GameDetailView
            dismiss()
        }
    }

    // MARK: - Création de la partie
    private func createGame() {
        guard let _ = selectedNotation else { return }
        let chosenPlayers = players.filter { selectedPlayerIDs.contains($0.id) }
        guard !chosenPlayers.isEmpty else { return }

        // Prépare un payload non optionnel pour la feuille d'ordre (évite un écran vide)
        orderPayload = OrderPayload(players: chosenPlayers)
    }

    /// Crée et enregistre la partie après validation de l'ordre des joueurs
    private func finalizeGame(with orderedIDs: [UUID]) {
        // 1) Récupère/Crée AppSettings
        let appSettings: AppSettings = {
            if let s = settings.first { return s }
            let s = AppSettings()
            context.insert(s)
            return s
        }()

        // 2) Récupère la notation sélectionnée (ou la première existante)
        guard let notation = selectedNotation ?? notations.first else { return }
        let snapshot = notation.snapshot()

        // 3) Nom final
        let nameToUse = gameName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? defaultGameName
            : gameName

        // 4) Instancie Game
        let game = Game(settings: appSettings, notation: snapshot, columns: 1, comment: comment)
        game.name = nameToUse
        game.enableChance = snapshot.isBottomFieldEnabled(.chance)
        game.enableSmallStraight = snapshot.isBottomFieldEnabled(.petiteSuite)
        game.smallStraightScore = snapshot.rulePetiteSuite.fixedValue
        game.enableExtraYamsBonus = snapshot.isBottomFieldEnabled(.yams)
            && snapshot.resolvedExtraYamsBonusMode != .disabled
        game.requiredNotationKeys = snapshot.requiredScoreKeys
        game.participantIDs = orderedIDs
        game.turnOrder = orderedIDs
        game.currentTurnIndex = 0

        // 5) Insère d'abord la partie afin que toutes les relations SwiftData
        // soient établies entre des objets appartenant au même contexte.
        context.insert(game)

        // 6) Scorecards
        for pid in orderedIDs {
            let sc = Scorecard(playerID: pid, columns: 1)
            context.insert(sc)
            sc.game = game
        }

        // 7) Sauvegarde et navigation
        try? context.save()

        // ⚑ Déclenche la navigation SANS animation (évite tout flash sous la cover)
        let noAnim = Transaction(animation: nil)
        withTransaction(noAnim) {
            createdGame = game
        }

        // ⚑ Puis ferme la cover juste après (on garde un micro-délai)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            orderPayload = nil
        }
    }
}

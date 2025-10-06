//
//  DebugSettingsView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/10/2025.
//

#if DEBUG
import SwiftUI
import SwiftData


struct DebugSettingsView: View {
    @AppStorage(DebugKeys.debugMode)   private var debugMode: Bool = false
    @AppStorage(DebugKeys.verboseLogs) private var verboseLogs: Bool = true
    @AppStorage(DebugKeys.autoSeed)    private var autoSeed: Bool = true
    @State private var showEndGameDemo = false
    @Environment(\.modelContext) private var context

    var body: some View {
        Form {
            Section {
                Toggle("Activer le mode Debug", isOn: $debugMode)
            } footer: {
                Text("Le mode Debug n’est disponible qu’en build DEBUG. En production, ces options sont inactives.")
            }
            Section("Démo fin de partie") {
                Button {
                    showEndGameDemo = true
                } label: {
                    Label("Afficher l’animation de fin", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
            }

            if debugMode {
                Section("Options Debug") {
                    Toggle("Logs verbeux (DLog)", isOn: $verboseLogs)
                    Toggle("Seed auto au lancement", isOn: $autoSeed)
                }

                Section("Actions") {
                    Button("Wipe + Seed de démo") {
                        wipeAllData(context)
                        DevSeed.seedIfNeeded(context)
                    }
                    .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Debug")
        .sheet(isPresented: $showEndGameDemo) {
            NavigationStack {
                // ====== CHOISIS UNE DES 2 VARIANTES CI-DESSOUS ======

                // ✅ Variante 1 (la plus simple) :
                // Si ton EndGameCongratsView n’exige **aucune dépendance** (ex: lit le contexte)
                // EndGameCongratsView()

                // ✅ Variante 2 : si ta vue attend un "Game" (le plus courant)
                DebugEndGameDemoView()
                    .navigationTitle("Démo fin de partie")
            }
        }
    }

    private func wipeAllData(_ ctx: ModelContext) {
        do {
            let allPlayers = try ctx.fetch(FetchDescriptor<Player>())
            let allGames   = try ctx.fetch(FetchDescriptor<Game>())
            allPlayers.forEach { ctx.delete($0) }
            allGames.forEach { ctx.delete($0) }
            try ctx.save()
        } catch {
            print("Wipe error: \(error)")
        }
    }
}

/// Construit un Game de démonstration et affiche EndGameCongratsView
struct DebugEndGameDemoView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let game = makeDemoGame(context: context) {
            // Construire la liste d’entrées à partir du jeu de démo
            let entries: [EndGameCongratsView.Entry] = game.participantIDs.compactMap { pid in
                guard let player = try? context.fetch(FetchDescriptor<Player>(predicate: #Predicate { $0.id == pid })).first else { return nil }
                let score = totalScore(for: pid, in: game)
                return EndGameCongratsView.Entry(name: player.nickname.isEmpty ? player.name : player.nickname, score: score)
            }
            .sorted { $0.score > $1.score }

            // Appel correct de ta vue
            EndGameCongratsView(
                gameName: game.comment.isEmpty ? "Démo de fin" : game.comment,
                entries: entries,
                dismiss: { dismiss() }
            )
        } else {
            ContentUnavailableView(
                "Aucun joueur de démo",
                systemImage: "person.crop.circle.badge.questionmark",
                description: Text("Ajoute au moins un joueur ou active le Seed.")
            )
        }
    }

    /// Calcul rapide du score total pour un joueur
    private func totalScore(for playerID: UUID, in game: Game) -> Int {
        guard let sc = game.scorecards.first(where: { $0.playerID == playerID }) else { return 0 }
        let fields: [Data] = [
            sc.onesData, sc.twosData, sc.threesData, sc.foursData, sc.fivesData, sc.sixesData,
            sc.maxValsData, sc.minValsData, sc.brelanData, sc.fullData, sc.carreData,
            sc.chanceData, sc.suiteData, sc.petiteSuiteData, sc.yamsData
        ]
        return fields.compactMap { data -> Int? in
            guard let arr = try? JSONDecoder().decode([Int].self, from: data) else { return nil }
            return arr.first
        }.reduce(0, +)
    }

    /// Fabrique un Game avec 2–4 joueurs et un gagnant, sans polluer la base
    private func makeDemoGame(context: ModelContext) -> Game? {
        let players = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        guard !players.isEmpty else { return nil }

        let group = Array(players.shuffled().prefix(Int.random(in: 2...4)))
        let pids  = group.map { $0.id }

        let settings = AppSettings()
        let notation = NotationSnapshot(
            name: "Par défaut",
            tooltipUpper: "",
            tooltipMiddle: "",
            tooltipBottom: "",
            upperBonusThreshold: settings.upperBonusThreshold,
            upperBonusValue: settings.upperBonusValue,
            middleMode: .multiplier,
            middleBonusSumThreshold: 50,
            middleBonusValue: 30,
            ruleBrelan: FigureRule(mode: .raw),
            ruleChance: FigureRule(mode: .raw),
            ruleFull: FigureRule(mode: .rawPlusFixed, fixedValue: 30),
            ruleSuite: FigureRule(mode: .fixed, fixedValue: 0),
            rulePetiteSuite: FigureRule(mode: .fixed, fixedValue: settings.enableSmallStraight ? settings.smallStraightScore : 0),
            ruleCarre: FigureRule(mode: .rawPlusFixed, fixedValue: 40),
            ruleYams: FigureRule(mode: .rawPlusFixed, fixedValue: 50),
            suiteBigMode: .splitFixed,
            suiteBigFixed: 0,
            suiteBigFixed1to5: 15,
            suiteBigFixed2to6: 20,
            extraYamsBonusEnabled: false,
            extraYamsBonusValue: 0
        )

        let columns = 1
        var scorecards: [Scorecard] = []
        for pl in group {
            let sc = Scorecard(playerID: pl.id, columns: columns)
            sc.onesData         = encode([1])[0]
            sc.twosData         = encode([2])[0]
            sc.threesData       = encode([3])[0]
            sc.foursData        = encode([4])[0]
            sc.fivesData        = encode([5])[0]
            sc.sixesData        = encode([6])[0]
            sc.maxValsData      = encode([Int.random(in: 18...30)])[0]
            sc.minValsData      = encode([Int.random(in: 5...15)])[0]
            sc.brelanData       = encode([Int.random(in: 10...25)])[0]
            sc.fullData         = encode([30])[0]
            sc.carreData        = encode([Int.random(in: 12...30)])[0]
            sc.chanceData       = encode([Int.random(in: 12...30)])[0]
            sc.suiteData        = encode([20])[0]
            sc.petiteSuiteData  = encode([settings.enableSmallStraight ? settings.smallStraightScore : 0])[0]
            sc.yamsData         = encode([0])[0]
            sc.extraYamsAwarded = [false]
            scorecards.append(sc)
        }

        let g = Game(settings: settings, notation: notation, columns: columns, comment: "Démo fin")
        g.participantIDs = pids
        g.scorecards = scorecards
        g.statusRaw = GameStatus.completed.rawValue
        return g
    }

    private func encode(_ values: [Int]) -> [Data] {
        [ (try? JSONEncoder().encode(values)) ?? Data() ]
    }
}
#endif


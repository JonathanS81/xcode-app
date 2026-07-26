//
//  DevSeed.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 29/09/2025.
//

#if DEBUG && targetEnvironment(simulator)
import SwiftUI
import SwiftData

/// Seed de démo (DEBUG) : joueurs + parties complétées
enum DevSeed {
    static func seedIfNeeded(_ context: ModelContext) {
        // 0) Si on a déjà des données, on ne fait rien
        let existingPlayers = (try? context.fetch(FetchDescriptor<Player>())) ?? []
        let existingGames   = (try? context.fetch(FetchDescriptor<Game>())) ?? []
        guard existingPlayers.isEmpty && existingGames.isEmpty else { return }

        // 1) Joueurs
        let players: [Player] = [
            Player(name: "Alice Martin",   nickname: "Alice", email: "alice@example.com",  favoriteEmoji: "🦊", color: .orange),
            Player(name: "Benoît Leroy",   nickname: "Ben",   email: "ben@example.com",    favoriteEmoji: "🐻", color: .blue),
            Player(name: "Chloé Bernard",  nickname: "Chloé", email: "chloe@example.com",  favoriteEmoji: "🦋", color: .pink),
            Player(name: "David Nguyen",   nickname: "David", email: "david@example.com",  favoriteEmoji: "🐯", color: .green),
            Player(name: "Emma Dupont",    nickname: "Emma",  email: "emma@example.com",   favoriteEmoji: "🦄", color: .purple),
            Player(name: "Farid Karim",    nickname: "Farid", email: "farid@example.com",  favoriteEmoji: "🐼", color: .teal),
        ]
        players.forEach { context.insert($0) }

        // 2) Settings + Notation défaut
        // 🔧 Si AppSettings() n'existe pas, remplace par ton fetch ou init custom
        let settings = AppSettings()
        let notation = makeDefaultNotation(from: settings)

        // 3) Parties complétées
        let gamesCount = 12
        for i in 0..<gamesCount {
            let columns = 1

            // Groupe 2–5 joueurs
            let group = Array(players.shuffled().prefix(Int.random(in: 2...5)))
            let pids  = group.map { $0.id }

            // Scorecards (colonne unique = index 0)
            var scorecards: [Scorecard] = []
            for pl in group {
                var sc = Scorecard(playerID: pl.id, columns: columns)

                // Section haute
                set(sc: &sc, key: \.onesData,   values: [randomUpper(face: 1)])
                set(sc: &sc, key: \.twosData,   values: [randomUpper(face: 2)])
                set(sc: &sc, key: \.threesData, values: [randomUpper(face: 3)])
                set(sc: &sc, key: \.foursData,  values: [randomUpper(face: 4)])
                set(sc: &sc, key: \.fivesData,  values: [randomUpper(face: 5)])
                set(sc: &sc, key: \.sixesData,  values: [randomUpper(face: 6)])

                // Section milieu (Max/Min)
                set(sc: &sc, key: \.maxValsData, values: [Int.random(in: 18...30)])
                set(sc: &sc, key: \.minValsData, values: [Int.random(in: 5...15)])

                // Section basse
                set(sc: &sc, key: \.brelanData, values: [Bool.random() ? Int.random(in: 12...25) : 0])
                set(sc: &sc, key: \.chanceData, values: [Int.random(in: 12...30)])
                set(sc: &sc, key: \.fullData,   values: [Bool.random() ? notation.ruleFull.fixedValue : 0])
                set(sc: &sc, key: \.carreData,  values: [Int.random(in: 4...30)]) // carré : 4…30

                // Grande suite (split 1–5 / 2–6 / barré) selon ta notation
                let pick = Int.random(in: 0...2)
                let suiteVal: Int = {
                    switch pick {
                    case 0: return 0
                    case 1: return notation.suiteBigFixed1to5
                    default: return notation.suiteBigFixed2to6
                    }
                }()
                set(sc: &sc, key: \.suiteData, values: [suiteVal])

                // Petite suite
                set(sc: &sc, key: \.petiteSuiteData, values: [settings.enableSmallStraight ? settings.smallStraightScore : 0])

                // Yams + prime
                let yamsOK = Bool.random() && Bool.random()
                let yamsScore = yamsOK ? notation.ruleYams.fixedValue : 0
                set(sc: &sc, key: \.yamsData, values: [yamsScore])
                sc.extraYamsAwarded = [ yamsOK && notation.extraYamsBonusEnabled && Bool.random() ]

                scorecards.append(sc)
            }

            // Game inProgress par défaut via init — on passe en "completed"
            let g = Game(settings: settings, notation: notation, columns: columns, comment: "Partie #\(i+1)")
            
            // 🔗 Liaison aux joueurs/scorecards (adapte les noms si différents dans ton modèle)
            // Ces propriétés existent déjà dans ton code ailleurs, on les affecte donc ici :
            // - participantIDs
            // - scorecards
            // - activePlayerID
            // - statusRaw (pour marquer complétée)
            g.participantIDs = pids
            g.scorecards = scorecards
            g.statusRaw = GameStatus.completed.rawValue

            context.insert(g)
        }

        try? context.save()
        DLog("✅ DevSeed: \(players.count) joueurs / \(gamesCount) parties injectées")
    }

    // MARK: - Notation par défaut (basée sur ce que tu as partagé)
    private static func makeDefaultNotation(from s: AppSettings) -> NotationSnapshot {
        NotationSnapshot(
            name: "Par défaut",
            tooltipUpper: "Atteindre \(s.upperBonusThreshold) en haut donne +\(s.upperBonusValue).",
            tooltipMiddle: "Multiplier : (Max − Min) × nombre d’As.",
            tooltipBottom: "Figures calculées selon la saisie (somme/prime).",
            upperBonusThreshold: s.upperBonusThreshold,
            upperBonusValue: s.upperBonusValue,
            middleMode: .multiplier,
            middleBonusSumThreshold: 50,
            middleBonusValue: 30,
            // Règles
            ruleBrelan: FigureRule(mode: .raw),
            ruleChance: FigureRule(mode: .raw),
            ruleFull: FigureRule(mode: .rawPlusFixed, fixedValue: 30),
            ruleSuite: FigureRule(mode: .fixed, fixedValue: 0), // non utilisé avec SuiteBig
            rulePetiteSuite: FigureRule(mode: .fixed, fixedValue: s.enableSmallStraight ? s.smallStraightScore : 0),
            smallStraightEnabled: s.enableSmallStraight,
            ruleCarre: FigureRule(mode: .rawPlusFixed, fixedValue: 40),
            ruleYams: FigureRule(mode: .rawPlusFixed, fixedValue: 50),
            // Grande suite en split
            suiteBigMode: .splitFixed,
            suiteBigFixed: 0,
            suiteBigFixed1to5: 15,
            suiteBigFixed2to6: 20,
            // Bonus yams sup
            extraYamsBonusEnabled: false,
            extraYamsBonusValue: 0
        )
    }

    // MARK: - Utilitaires d'encodage pour Scorecard.*Data
    private static func encodeJSON<T: Encodable>(_ value: T) -> Data {
        (try? JSONEncoder().encode(value)) ?? Data()
    }
    private static func set(sc: inout Scorecard, key: WritableKeyPath<Scorecard, Data>, values: [Int]) {
        sc[keyPath: key] = encodeJSON(values)
    }
    private static func randomUpper(face: Int) -> Int {
        // -1 = vide, 0 = barré, sinon multiple de face (on évite -1 pour nourrir les stats)
        if Bool.random() { return 0 }
        return face * Int.random(in: 1...3)
    }
}
#endif

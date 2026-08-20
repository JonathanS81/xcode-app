//
//  GameDetailView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 06/09/2025.
//

import SwiftUI
import SwiftData

fileprivate enum ColumnRecenterMode: Int {
    case fixedAll          = 0  // 1) colonnes toujours fixes
    case fixedUpTo4ElsePin = 1  // 2) fixes si ≤4, sinon on recentre (actif en première)
    case alwaysPinActive   = 2  // 3) toujours recentrer (actif en première)
}

struct GameDetailView: View {
    // Accès aux joueurs pour récupérer leur couleur
    @Query private var allPlayers: [Player]
    @Query private var appSettings: [AppSettings]

    // Couleur pour un playerID
    private func colorForPlayerID(_ id: UUID?) -> Color {
        guard let id, let p = allPlayers.first(where: { $0.id == id }) else { return .accentColor }
        return p.color
    }
    
    @AppStorage("columnRecenterMode") private var columnRecenterModeRaw: Int = ColumnRecenterMode.fixedUpTo4ElsePin.rawValue

    private var columnMode: ColumnRecenterMode {
        ColumnRecenterMode(rawValue: columnRecenterModeRaw) ?? .fixedUpTo4ElsePin
    }

    // Si tu as un tableau d’IDs affichés (ex. displayPlayerIDs), utilitaire par index
    private func colorForColumnIndex(_ idx: Int, in ids: [UUID]) -> Color {
        guard idx >= 0 && idx < ids.count else { return .accentColor }
        return colorForPlayerID(ids[idx])
    }

    // Réglages fins des contrastes (persistés dans les Réglages)
    @AppStorage("tintLight") private var tintLight: Double = 0.25  // cellules vides (colonne active)
    @AppStorage("tintDark")  private var tintDark:  Double = 0.65  // cellules remplies (colonne active)

    // MARK: - Active column tint helpers (local)
    /// ID du joueur actif courant
    private func _activePID() -> UUID? {
        return game.activePlayerID
    }

    /// Teinte de fond quand on ne sait pas encore si la case est remplie
    private func columnTint(pid: UUID) -> some ShapeStyle {
        let base = colorForPlayerID(pid)
        guard _activePID() == pid else { return Color(.systemGray6) }
        return base.opacity(tintLight)
    }

    /// Teinte de fond en fonction de l’état (vide/rempli) pour la colonne active
    private func columnTint(pid: UUID, isFilled: Bool) -> some ShapeStyle {
        let base = colorForPlayerID(pid)
        guard _activePID() == pid else { return Color(.systemGray6) }
        return base.opacity(isFilled ? max(tintDark, tintLight) : tintLight)
    }
    
    
    // MARK: - Env & Model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Bindable var game: Game

    // MARK: - UI State
    @State private var showTip = false
    @State private var tipTitle = UIStrings.Game.tooltipTitle
    @State private var tipText = ""
    @State private var showRevokeYams = false
    @State private var revokePlayerIdx: Int? = nil
    @State private var showEndGameSheet = false
    @State private var showOrderSheet = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showCongrats = false
    @State private var endGameEntries: [EndGameCongratsView.Entry] = []
    @State private var turnStartFilledKeysByPlayer: [UUID: Set<String>] = [:]
    @State private var turnStartScoreValuesByPlayer: [UUID: [String: Int]] = [:]
    @State private var turnStartDeclaredYamsByPlayer: [UUID: [String: Bool]] = [:]
    @State private var turnStartExtraYamsSourcesByPlayer: [UUID: [String: String]] = [:]
    @State private var turnStartExtraYamsAwardsByPlayer: [UUID: [String: [String]]] = [:]
    @State private var turnStartExtraYamsAwardedByPlayer: [UUID: [Bool]] = [:]
    @State private var currentTurnScoreKeyByPlayer: [UUID: String] = [:]

    // MARK: - Columns (multi-colonnes plus tard)
    private var scoreColumnIndex: Int { 0 }

    // MARK: - Layout
    private let outerHPadding: CGFloat = 32    // .padding(.horizontal) 16+16
    private let labelColumnWidth: CGFloat = 110
    private let perColumnOuterPad: CGFloat = 4 // padding(.horizontal,2) visuel sur colonnes
    private let safetyGutter: CGFloat = 8      // marge anti-rognage

   /* /// IDs des joueurs à afficher (actif d’abord)
    private var displayPlayerIDs: [UUID] {
        var seen = Set<UUID>(), ids: [UUID] = []
        if let active = game.activePlayerID,
           game.scorecards.contains(where: { $0.playerID == active }) {
            ids.append(active); seen.insert(active)
        }
        for id in game.turnOrder where !seen.contains(id) {
            if game.scorecards.contains(where: { $0.playerID == id }) { ids.append(id); seen.insert(id) }
        }
        for sc in game.scorecards where !seen.contains(sc.playerID) {
            ids.append(sc.playerID); seen.insert(sc.playerID)
        }
        return ids
    } */
    
    /// Ordre de base : turnOrder → participantIDs → ordre des scorecards
    private var basePlayerIDs: [UUID] {
        let scIDs = game.scorecards.map { $0.playerID }
        let scSet = Set(scIDs)

        let order = game.turnOrder.filter { scSet.contains($0) }
        if !order.isEmpty { return order }

        let participants = game.participantIDs.filter { scSet.contains($0) }
        if !participants.isEmpty { return participants }

        return scIDs
    }

    /// Applique éventuellement le "recentrement" (actif en premier) selon le mode
    private var displayPlayerIDs: [UUID] {
        let base = basePlayerIDs
        guard let active = game.activePlayerID, base.contains(active) else {
            return base
        }

        switch columnMode {
        case .fixedAll:
            // 1) Jamais de déplacement
            return base

        case .fixedUpTo4ElsePin:
            // 2) Si ≤ 4 joueurs : fixe, sinon actif d’abord
            guard base.count >= 5 else { return base }
            return [active] + base.filter { $0 != active }

        case .alwaysPinActive:
            // 3) Toujours actif d’abord (comportement initial)
            return [active] + base.filter { $0 != active }
        }
    }
    

    /// Largeur mini d'une colonne joueur, calculée pour que 1–4 joueurs tiennent sans scroll.
    /// Bornée 50..64 pour conserver la lisibilité.
    private var minCellWidth: CGFloat {
        let n = max(1, min(4, displayPlayerIDs.count)) // calcule pour 1..4
        let screenW = UIScreen.main.bounds.width
        let available = max(0,
            screenW
            - outerHPadding
            - labelColumnWidth
            - safetyGutter
            - CGFloat(n) * perColumnOuterPad
        )
        let perCol = floor(available / CGFloat(n))
        return max(50, min(64, perCol))
    }

    /// Padding interne dynamique (on serre à 4 joueurs)
    private var cellPadding: CGFloat {
        switch displayPlayerIDs.count {
        case 0,1: return 8
        case 2:   return 7
        case 3:   return 5
        case 4:   return 2
        default:  return 8
        }
    }

    /// Police proportionnelle à la largeur de colonne
    private var cellFont: Font {
        let sz = max(13, min(17, minCellWidth * 0.32))
        return .system(size: sz)
    }
    private var badgeFont: Font {
        let sz = max(10, min(12, minCellWidth * 0.28))
        return .system(size: sz)
    }
    
    // Hauteurs normalisées pour aligner labels (gauche) et cellules (droite)
    private let cellRowHeight: CGFloat = 36      // chaque cellule / total
    private let headerRowHeight: CGFloat = 28    // ligne "Section haute / milieu / basse"
    private let namesHeaderHeight: CGFloat = 26  // bandeau des noms (chips de colonnes)
    private let namesHeaderBottom: CGFloat = 2   // marge sous ce bandeau


    // MARK: - Participants & Order
    private var participants: [Player] {
        let byId = Dictionary(uniqueKeysWithValues: allPlayers.map { ($0.id, $0) })
        return game.participantIDs.compactMap { byId[$0] }
    }

    private var orderedPlayers: [Player] {
        let byId = Dictionary(uniqueKeysWithValues: participants.map { ($0.id, $0) })
        let inOrder = game.turnOrder.compactMap { byId[$0] }
        return inOrder.isEmpty ? participants : inOrder
    }

    private var activeScorecardIndex: Int? {
        guard let pid = game.activePlayerID else { return nil }
        return game.scorecards.firstIndex(where: { $0.playerID == pid })
    }

    /// index de scorecard par id joueur
    private var scorecardIndexByPlayerID: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: game.scorecards.enumerated().map { ($0.element.playerID, $0.offset) })
    }

    // “Au tour de …”
    private var activePlayerName: String {
        if let pid = game.activePlayerID,
           let p = allPlayers.first(where: { $0.id == pid }) {
            return p.nickname
        }
        return "—"
    }

    // MARK: - Tour par tour
    private func isCellEnabled(for playerID: UUID) -> Bool {
        guard game.statusOrDefault == .inProgress else { return false }
        return game.activePlayerID == playerID
    }

    /// nb de cases remplies (toutes sections)
    private func currentFillableCount(for playerID: UUID) -> Int {
        guard let sc = game.scorecards.first(where: { $0.playerID == playerID }) else { return 0 }
        let i = scoreColumnIndex
        func f(_ a: [Int]) -> Int { (i < a.count && a[i] >= 0) ? 1 : 0 }
        var c = 0
        // haute
        c += f(sc.ones); c += f(sc.twos); c += f(sc.threes)
        c += f(sc.fours); c += f(sc.fives); c += f(sc.sixes)
        // milieu
        c += f(sc.maxVals); c += f(sc.minVals)
        // basse
        c += f(sc.brelan)
        if game.enableChance { c += f(sc.chance) }
        c += f(sc.full)
        c += f(sc.suite)
        if game.enableSmallStraight { c += f(sc.petiteSuite) }
        c += f(sc.carre)
        c += f(sc.yams)
        return c
    }

    private func ensureTurnSnapshotInitialized() {
        if let pid = game.activePlayerID {
            let count = currentFillableCount(for: pid)
            game.beginTurnSnapshot(for: pid, fillableCount: count)
            if let sc = game.scorecards.first(where: { $0.playerID == pid }) {
                if turnStartFilledKeysByPlayer[pid] == nil {
                    turnStartFilledKeysByPlayer[pid] = filledScoreKeys(for: sc)
                }
                if turnStartScoreValuesByPlayer[pid] == nil {
                    turnStartScoreValuesByPlayer[pid] = scoreSnapshot(for: sc)
                }
                if turnStartDeclaredYamsByPlayer[pid] == nil {
                    turnStartDeclaredYamsByPlayer[pid] = sc.declaredYams
                    turnStartExtraYamsSourcesByPlayer[pid] = sc.extraYamsSources
                    turnStartExtraYamsAwardsByPlayer[pid] = sc.extraYamsAwards
                    turnStartExtraYamsAwardedByPlayer[pid] = sc.extraYamsAwarded
                }
            }
        }
    }

    private var trackedScoreKeys: [String] {
        var keys = [
            "ones", "twos", "threes", "fours", "fives", "sixes",
            "max", "min", "brelan"
        ]
        if game.enableChance { keys.append("chance") }
        keys.append(contentsOf: ["full", "suite"])
        if game.enableSmallStraight { keys.append("petiteSuite") }
        keys.append(contentsOf: ["carre", "yams"])
        return keys
    }

    private func scoreSnapshot(for sc: Scorecard) -> [String: Int] {
        Dictionary(uniqueKeysWithValues: trackedScoreKeys.map {
            ($0, scoreValue(for: $0, in: sc))
        })
    }

    private func turnEvaluation(for playerID: UUID) -> TurnChangePolicy.Evaluation {
        guard let sc = game.scorecards.first(where: { $0.playerID == playerID }) else {
            return TurnChangePolicy.evaluate(start: [:], current: [:])
        }
        let current = scoreSnapshot(for: sc)
        let start = turnStartScoreValuesByPlayer[playerID] ?? current
        return TurnChangePolicy.evaluate(start: start, current: current)
    }

    private func canEditScoreCell(for playerID: UUID, label: String) -> Bool {
        guard isCellEnabled(for: playerID) else { return false }
        return turnEvaluation(for: playerID).canEdit(storageKey(for: label))
    }

    private var hasReachedTurnChangeLimit: Bool {
        guard let playerID = game.activePlayerID else { return false }
        return turnEvaluation(for: playerID).changedKeys.count
            >= TurnChangePolicy.maximumChangedCells
    }

    private func commitTurnSnapshot(for playerID: UUID) {
        guard let sc = game.scorecards.first(where: { $0.playerID == playerID }) else { return }
        turnStartFilledKeysByPlayer[playerID] = filledScoreKeys(for: sc)
        turnStartScoreValuesByPlayer[playerID] = scoreSnapshot(for: sc)
        turnStartDeclaredYamsByPlayer[playerID] = sc.declaredYams
        turnStartExtraYamsSourcesByPlayer[playerID] = sc.extraYamsSources
        turnStartExtraYamsAwardsByPlayer[playerID] = sc.extraYamsAwards
        turnStartExtraYamsAwardedByPlayer[playerID] = sc.extraYamsAwarded
        currentTurnScoreKeyByPlayer[playerID] = nil
    }

    private func restoreScoreValue(_ value: Int, for key: String, in sc: Scorecard) {
        let column = scoreColumnIndex

        func restoring(_ values: [Int]) -> [Int] {
            var result = values
            if column >= result.count {
                result.append(contentsOf: Array(repeating: -1, count: column - result.count + 1))
            }
            result[column] = value
            return result
        }

        switch key {
        case "ones": sc.ones = restoring(sc.ones)
        case "twos": sc.twos = restoring(sc.twos)
        case "threes": sc.threes = restoring(sc.threes)
        case "fours": sc.fours = restoring(sc.fours)
        case "fives": sc.fives = restoring(sc.fives)
        case "sixes": sc.sixes = restoring(sc.sixes)
        case "max": sc.maxVals = restoring(sc.maxVals)
        case "min": sc.minVals = restoring(sc.minVals)
        case "brelan": sc.brelan = restoring(sc.brelan)
        case "chance": sc.chance = restoring(sc.chance)
        case "full": sc.full = restoring(sc.full)
        case "suite": sc.suite = restoring(sc.suite)
        case "petiteSuite": sc.petiteSuite = restoring(sc.petiteSuite)
        case "carre": sc.carre = restoring(sc.carre)
        case "yams": sc.yams = restoring(sc.yams)
        default: break
        }
    }

    private func undoCurrentTurnChanges() {
        guard let playerID = game.activePlayerID,
              let sc = game.scorecards.first(where: { $0.playerID == playerID }),
              let startScores = turnStartScoreValuesByPlayer[playerID] else { return }

        for key in trackedScoreKeys {
            restoreScoreValue(startScores[key] ?? -1, for: key, in: sc)
        }
        sc.declaredYams = turnStartDeclaredYamsByPlayer[playerID] ?? [:]
        sc.extraYamsSources = turnStartExtraYamsSourcesByPlayer[playerID] ?? [:]
        sc.extraYamsAwards = turnStartExtraYamsAwardsByPlayer[playerID] ?? [:]
        sc.extraYamsAwarded = turnStartExtraYamsAwardedByPlayer[playerID]
            ?? Array(repeating: false, count: sc.columns)
        currentTurnScoreKeyByPlayer[playerID] = nil
        try? context.save()
    }

    private func filledScoreKeys(for sc: Scorecard) -> Set<String> {
        let i = scoreColumnIndex
        func filled(_ values: [Int]) -> Bool {
            values.indices.contains(i) && values[i] >= 0
        }

        var keys: Set<String> = []
        if filled(sc.ones) { keys.insert("ones") }
        if filled(sc.twos) { keys.insert("twos") }
        if filled(sc.threes) { keys.insert("threes") }
        if filled(sc.fours) { keys.insert("fours") }
        if filled(sc.fives) { keys.insert("fives") }
        if filled(sc.sixes) { keys.insert("sixes") }
        if filled(sc.maxVals) { keys.insert("max") }
        if filled(sc.minVals) { keys.insert("min") }
        if filled(sc.brelan) { keys.insert("brelan") }
        if game.enableChance, filled(sc.chance) { keys.insert("chance") }
        if filled(sc.full) { keys.insert("full") }
        if filled(sc.suite) { keys.insert("suite") }
        if game.enableSmallStraight, filled(sc.petiteSuite) { keys.insert("petiteSuite") }
        if filled(sc.carre) { keys.insert("carre") }
        if filled(sc.yams) { keys.insert("yams") }
        return keys
    }

    private var currentTurnScoreKey: String? {
        guard let pid = game.activePlayerID,
              let sc = game.scorecards.first(where: { $0.playerID == pid }) else { return nil }
        if let tracked = currentTurnScoreKeyByPlayer[pid],
           scoreValue(for: tracked, in: sc) >= 0 {
            return tracked
        }

        let start = turnStartScoreValuesByPlayer[pid] ?? scoreSnapshot(for: sc)
        let current = scoreSnapshot(for: sc)
        let added = trackedScoreKeys.filter {
            (start[$0] ?? -1) < 0 && (current[$0] ?? -1) >= 0
        }
        return added.count == 1 ? added.first : nil
    }

    private func scoreValue(for key: String, in sc: Scorecard) -> Int {
        let i = scoreColumnIndex
        func value(_ values: [Int]) -> Int {
            values.indices.contains(i) ? values[i] : -1
        }
        switch key {
        case "ones": return value(sc.ones)
        case "twos": return value(sc.twos)
        case "threes": return value(sc.threes)
        case "fours": return value(sc.fours)
        case "fives": return value(sc.fives)
        case "sixes": return value(sc.sixes)
        case "max": return value(sc.maxVals)
        case "min": return value(sc.minVals)
        case "brelan": return value(sc.brelan)
        case "chance": return value(sc.chance)
        case "full": return value(sc.full)
        case "suite": return value(sc.suite)
        case "petiteSuite": return value(sc.petiteSuite)
        case "carre": return value(sc.carre)
        case "yams": return value(sc.yams)
        default: return -1
        }
    }

    private var canShowNextButton: Bool {
        guard game.statusOrDefault == .inProgress, let pid = game.activePlayerID else { return false }
        return turnEvaluation(for: pid).canEndTurn
    }

    private var requiredCellsCountPerPlayer: Int {
        var n = 13
        if game.enableChance { n += 1 }
        if game.enableSmallStraight { n += 1 }
        return n
    }

    private var canChangePlayerByTap: Bool {
        guard game.statusOrDefault == .inProgress, let pid = game.activePlayerID else { return false }
        let now = currentFillableCount(for: pid)
        let start = game.lastFilledCountByPlayer[pid] ?? now
        return (now - start) >= 1
    }

    private func requiredFilledCount(for sc: Scorecard) -> Int {
        let i = scoreColumnIndex
        func f(_ a: [Int]) -> Int { (i < a.count && a[i] >= 0) ? 1 : 0 }
        var c = 0
        c += f(sc.ones); c += f(sc.twos); c += f(sc.threes)
        c += f(sc.fours); c += f(sc.fives); c += f(sc.sixes)
        c += f(sc.maxVals); c += f(sc.minVals)
        c += f(sc.brelan)
        if game.enableChance { c += f(sc.chance) }
        c += f(sc.full)
        c += f(sc.suite)
        if game.enableSmallStraight { c += f(sc.petiteSuite) }
        c += f(sc.carre)
        c += f(sc.yams)
        return c
    }

    private func isGameCompletedNow() -> Bool {
        game.scorecards.allSatisfy { requiredFilledCount(for: $0) >= requiredCellsCountPerPlayer }
    }

    // MARK: - Actions
    private func onNextPlayerTapped() {
        hideKeyboard() // commit NumericRow si focus

        guard let pid = game.activePlayerID else { return }
        let countNow = currentFillableCount(for: pid)
        game.beginTurnSnapshot(for: pid, fillableCount: countNow)
        guard turnEvaluation(for: pid).canEndTurn else {
            alertMessage = "Le tour doit ajouter exactement une case et ne peut modifier plus de trois cases."
            showAlert = true
            return
        }
        commitTurnSnapshot(for: pid)
        game.endTurnCommit(for: pid, fillableCount: countNow)
        game.advanceToNextPlayer()

        if isGameCompletedNow() {
            game.statusOrDefault = .completed
            game.endedAt = Date()
            let ranking: [(String, Int)] = orderedPlayers
                .map { ($0.nickname, totalScore(for: $0.id)) }
                .sorted { $0.1 > $1.1 }

            if scenePhase != .active {
                NotificationManager.postEndGame(
                    winnerName: ranking.first?.0 ?? "—",
                    gameName: game.name,
                    rankings: ranking
                )
            } else {
                endGameEntries = ranking.map { .init(name: $0.0, score: $0.1) }
                showCongrats = true
            }
        }
        try? context.save()
    }

    private func pauseAndGoHome() {
        let didAdvance = endTurnIfExactlyOneFilledAndAdvance()
        markAutoAdvanceOnPause(didAdvance)
        game.statusOrDefault = .paused
        try? context.save()
        NotificationCenter.default.post(name: .closeToGamesList, object: game.id)
        DispatchQueue.main.async { dismiss() }
    }

    private func finishNowAndGoHome() {
        game.statusOrDefault = .completed
        game.endedAt = Date()
        try? context.save()
        NotificationCenter.default.post(name: .closeToGamesList, object: game.id)
        DispatchQueue.main.async { dismiss() }
    }

    private func endTurnIfExactlyOneFilledAndAdvance() -> Bool {
        guard game.statusOrDefault == .inProgress, let pid = game.activePlayerID else { return false }
        let now = currentFillableCount(for: pid)
        guard turnEvaluation(for: pid).canEndTurn else { return false }

        commitTurnSnapshot(for: pid)
        game.endTurnCommit(for: pid, fillableCount: now)
        game.advanceToNextPlayer()
        ensureTurnSnapshotInitialized()
        return true
    }

    private func markAutoAdvanceOnPause(_ didAdvance: Bool) {
        let key = "autoAdvanceOnPause.\(game.id.uuidString)"
        UserDefaults.standard.set(didAdvance, forKey: key)
    }

    private func consumeAutoAdvanceOnPauseFlag() -> Bool {
        let key = "autoAdvanceOnPause.\(game.id.uuidString)"
        let did = UserDefaults.standard.bool(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        return did
    }

    // MARK: - Apparence cellules
    private func isActiveIndex(_ idx: Int) -> Bool {
        guard let pid = game.activePlayerID else { return false }
        return game.scorecards[idx].playerID == pid
    }

    private func cellBackground(col: Int, isOpen: Bool) -> Color {
        if isActiveIndex(col) {
            return isOpen ? Color.blue.opacity(0.12) : Color.green.opacity(0.12)
        } else {
            return Color.gray.opacity(0.08)
        }
    }

    // MARK: - Manquants utiles
    private func finishGameAndGoHome() {
        game.statusOrDefault = .completed
        game.endedAt = Date()
        try? context.save()
        NotificationCenter.default.post(name: .closeToGamesList, object: game.id)
        showCongrats = false
        DispatchQueue.main.async { dismiss() }
    }

    private func autoPauseIfNeeded(reason: String) {
        guard game.statusOrDefault == .inProgress else { return }
        let didAdvance = endTurnIfExactlyOneFilledAndAdvance()
        markAutoAdvanceOnPause(didAdvance)
        game.statusOrDefault = .paused
        try? context.save()
        #if DEBUG
        DLog("[GameDetailView] Auto-pause (\(reason)) • didAdvance=\(didAdvance)")
        #endif
    }

    private func revokeExtraYams(for playerIdx: Int) {
        game.scorecards[playerIdx].removeExtraYamsAward(
            col: scoreColumnIndex,
            source: currentTurnScoreKey
        )
        try? context.save()
    }

    private func setActivePlayer(_ pid: UUID) {
        guard game.statusOrDefault == .inProgress else { return }
        guard let current = game.activePlayerID else { return }
        if current == pid { return }

        let now = currentFillableCount(for: current)
        guard turnEvaluation(for: current).canEndTurn else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            alertMessage = "Le tour doit ajouter exactement une case et ne peut modifier plus de trois cases."
            showAlert = true
            return
        }
        commitTurnSnapshot(for: current)
        game.endTurnCommit(for: current, fillableCount: now)
        game.jumpTo(playerID: pid)
        ensureTurnSnapshotInitialized()
    }
    
    // MARK: - Header moderne
    private var activeIndexForChips: Int? {
        guard let aid = game.activePlayerID else { return nil }
        return orderedPlayers.firstIndex(where: { $0.id == aid })
    }

    private var statusSubtitle: String? {
        switch game.statusOrDefault {
        case .inProgress: return "À \(activePlayerName) de jouer"
        case .paused:     return "Partie en pause"
        case .completed:  return "Partie terminée"
        }
    }

    @ViewBuilder
    private func modernHeader() -> some View {
        GDV_Header(title: UIStrings.Game.title, subtitle: statusSubtitle)
       /* GDV_PlayerChips(
            players: orderedPlayers.map { $0.nickname },
            activeIndex: activeIndexForChips
        )*/
        .frame(maxWidth: .infinity, alignment: .leading)
    }


    // MARK: - Body
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                modernHeader()
                turnActionsControl()
                grid()
            }
            .padding(.horizontal)
        }
        .sheet(isPresented: $showEndGameSheet) {
            let entries: [EndGameSheet.Entry] = orderedPlayers
                .map { p in EndGameSheet.Entry(playerID: p.id, name: p.nickname, score: totalScore(for: p.id)) }
                .sorted { $0.score > $1.score }
            EndGameSheet(entries: entries) { showEndGameSheet = false }
        }
        .sheet(isPresented: $showOrderSheet) {
            OrderSetupSheet(
                players: participants,
                idFor: { $0.id },
                nameFor: { $0.nickname },
                onConfirm: { ids in
                    game.setTurnOrder(ids); try? context.save()
                }
            )
        }
        .sheet(isPresented: $showCongrats) {
            EndGameCongratsView(
                gameName: game.name,
                entries: endGameEntries,
                dismiss: { finishGameAndGoHome() }
            )
        }
        .onAppear {
            NotificationManager.requestAuthorizationIfNeeded()
            if game.turnOrder.isEmpty && orderedPlayers.count >= 2 { showOrderSheet = true }
            ensureTurnSnapshotInitialized()

            if game.statusOrDefault == .paused {
                let didAdvance = consumeAutoAdvanceOnPauseFlag()
                game.statusOrDefault = .inProgress
                try? context.save()
                alertMessage = didAdvance
                    ? "Le tour précédent a été validé. À \(activePlayerName) de jouer !"
                    : "À \(activePlayerName) de jouer !"
                showAlert = true
            }
        }
        .onChange(of: game.activePlayerID) { _, _ in
            ensureTurnSnapshotInitialized()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { autoPauseIfNeeded(reason: "scenePhase=\(phase)") }
        }
        .onDisappear { autoPauseIfNeeded(reason: "onDisappear") }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        .navigationTitle(game.name.isEmpty ? UIStrings.Common.game : game.name)
        .toolbar {
/*#if DEBUG
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Button("Debug • Terminer maintenant (popup)") {
                        debugFillAllRequiredAndComplete(showNotification: false)
                    }
                    Button("Debug • Terminer avec notification") {
                        NotificationManager.requestAuthorizationIfNeeded()
                        debugFillAllRequiredAndComplete(showNotification: true)
                    }
                } label: { Image(systemName: "ladybug.fill") }
            }
#endif */
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if canShowNextButton {
                        Button("Joueur suivant") { onNextPlayerTapped() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Menu {
                        if game.statusOrDefault == .inProgress {
                            Button(UIStrings.Game.pause)  { pauseAndGoHome() }
                            Button(UIStrings.Game.finish) { finishNowAndGoHome() }
                        } else {
                            Text("Partie verrouillée")
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Terminé") { hideKeyboard() }
            }
        }
        .alert(alertMessage, isPresented: $showAlert) { Button(UIStrings.Common.ok, role: .cancel) { } }
        .alert(tipTitle, isPresented: $showTip) {
            Button(UIStrings.Common.ok, role: .cancel) { }
        } message: {
            Text(tipText)
        }
        .confirmationDialog(
            "Annuler la prime Yams supplémentaire ?",
            isPresented: $showRevokeYams,
            titleVisibility: .visible
        ) {
            Button("Annuler la prime", role: .destructive) {
                if let idx = revokePlayerIdx { revokeExtraYams(for: idx) }
                revokePlayerIdx = nil
            }
            Button("Conserver", role: .cancel) { revokePlayerIdx = nil }
        }
    }


    // MARK: - Suite helpers (from NotationSnapshot)
    private func suiteAllowedValuesFromSnapshot() -> [Int] {
        switch game.notation.suiteBigMode {
        case .singleFixed:
            return [0, game.notation.suiteBigFixed]
        case .splitFixed:
            return [0, game.notation.suiteBigFixed1to5, game.notation.suiteBigFixed2to6]
        @unknown default:
            return [0, 15, 20]
        }
    }
    private func suiteMenuLabelFromSnapshot(_ v: Int) -> String {
        if v == -1 { return UIStrings.Common.dash }
        if v == 0  { return "0" }
        switch game.notation.suiteBigMode {
        case .singleFixed:
            return String(v)
        case .splitFixed:
            if v == game.notation.suiteBigFixed1to5 { return "1 à 5" }
            if v == game.notation.suiteBigFixed2to6 { return "2 à 6" }
            return String(v)
        @unknown default:
            return String(v)
        }
    }
    // Petite suite (from NotationSnapshot)
    private func petiteSuiteAllowedValuesFromSnapshot() -> [Int] {
        return [0, game.notation.rulePetiteSuite.fixedValue]
    }
    private func petiteSuiteMenuLabelFromSnapshot(_ v: Int) -> String {
        if v == -1 { return UIStrings.Common.dash }
        if v == 0  { return "0" }
        return UIStrings.Game.petiteSuite
    }

    private func figureAllowedValues(
        rule: FigureRule,
        rawValues: [Int]
    ) -> [Int] {
        switch rule.mode {
        case .fixed:
            return Array(Set([0, rule.fixedValue])).sorted()
        case .raw, .rawPlusFixed, .rawTimes:
            return [0] + rawValues
        }
    }

    private func figureCellLabel(_ value: Int, rule: FigureRule) -> String {
        guard value >= 0 else { return UIStrings.Common.dash }
        return ValidationEngine.displayForBottom(stored: value, rule: rule)
    }

    private func figureMenuLabel(
        _ value: Int,
        name: String,
        rule: FigureRule
    ) -> String {
        if value == -1 { return UIStrings.Common.dash }
        if value == 0 { return "0" }
        if rule.mode == .fixed { return "\(name) réussi — \(rule.fixedValue)" }
        return String(value)
    }

    private func carreAllowedValuesFromSnapshot() -> [Int] {
        figureAllowedValues(
            rule: game.notation.ruleCarre,
            rawValues: [4, 8, 12, 16, 20, 24]
        )
    }

    private func yamsAllowedValuesFromSnapshot() -> [Int] {
        figureAllowedValues(
            rule: game.notation.ruleYams,
            rawValues: [5, 10, 15, 20, 25, 30]
        )
    }

    // MARK: - Grid (≤4 joueurs compact, ≥5 joueurs labels figés + scroll horizontal)
    @ViewBuilder private func grid() -> some View {
        let needsHorizontal = displayPlayerIDs.count >= 5

        if needsHorizontal {
            HStack(alignment: .top, spacing: 0) {
                labelsColumn()
                    .zIndex(1)
                ScrollView(.horizontal, showsIndicators: true) {
                    playersColumnsBody()
                        .frame(minWidth: CGFloat(displayPlayerIDs.count) * (minCellWidth + perColumnOuterPad),
                               alignment: .leading)
                }
            }
        } else {
            VStack(spacing: 8) {
                // Header colonnes (noms)
                HStack(spacing: 0) {
                    Text("").frame(width: labelColumnWidth, alignment: .leading)
                    playersColumnsHeader()
                }

                // Section haute
                sectionHeader(
                    UIStrings.Game.upperSection,
                    detail: upperSectionDetailText
                )
                rowUpper(label: UIStrings.Game.ones,   face: 1, keyPath: \Scorecard.ones)
                rowUpper(label: UIStrings.Game.twos,   face: 2, keyPath: \Scorecard.twos)
                rowUpper(label: UIStrings.Game.threes, face: 3, keyPath: \Scorecard.threes)
                rowUpper(label: UIStrings.Game.fours,  face: 4, keyPath: \Scorecard.fours)
                rowUpper(label: UIStrings.Game.fives,  face: 5, keyPath: \Scorecard.fives)
                rowUpper(label: UIStrings.Game.sixes,  face: 6, keyPath: \Scorecard.sixes)
                totalsRow(label: UIStrings.Game.total1, valueForPlayer: total1Text)

                // Section milieu
                sectionHeader(
                    UIStrings.Game.middleSection,
                    detail: middleSectionDetailText
                )
                rowMaxMin(label: UIStrings.Game.max, keyPath: \Scorecard.maxVals)
                rowMaxMin(label: UIStrings.Game.min, keyPath: \Scorecard.minVals)
                if game.notation.middleMode == .bonusGate {
                    totalsRow(label: "Bonus", valueForPlayer: middleBonusText)
                }
                totalsRow(label: UIStrings.Game.total2, valueForPlayer: total2Text)

                // Section basse
                sectionHeader(UIStrings.Game.bottomSection)
                rowBottom(label: UIStrings.Game.brelan, keyPath: \Scorecard.brelan,
                          validator: { ValidationEngine.sanitizeBottom($0, rule: game.notation.ruleBrelan) },
                          displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleBrelan) })
                if game.enableChance {
                    rowBottom(label: UIStrings.Game.chance, keyPath: \Scorecard.chance,
                              validator: { ValidationEngine.sanitizeBottom($0, rule: game.notation.ruleChance) },
                              displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleChance) })
                }
                rowBottom(label: UIStrings.Game.full, keyPath: \Scorecard.full,
                          validator: { ValidationEngine.sanitizeBottom($0, rule: game.notation.ruleFull) },
                          displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleFull) })

                HStack(spacing: 0) {
                    scoreHelpLabel(UIStrings.Game.suite)
                    pickerRowPlayersOnly(allowedValues: suiteAllowedValuesFromSnapshot(),
                                         label: UIStrings.Game.suite,
                                         valueToText: GDV_Helpers.displaySuiteValue,
                                         keyPath: \.suite)
                }

                if game.enableSmallStraight {
                    HStack(spacing: 0) {
                        scoreHelpLabel(UIStrings.Game.petiteSuite)
                        pickerRowPlayersOnly(allowedValues: petiteSuiteAllowedValuesFromSnapshot(),
                                             label: UIStrings.Game.petiteSuite,
                                             valueToText: GDV_Helpers.displayPetiteSuiteValue,
                                             keyPath: \.petiteSuite)
                    }
                }

                HStack(spacing: 0) {
                    scoreHelpLabel(UIStrings.Game.carre)
                    pickerRowPlayersOnly(
                        allowedValues: carreAllowedValuesFromSnapshot(),
                        label: UIStrings.Game.carre,
                        valueToText: {
                            figureCellLabel($0, rule: game.notation.ruleCarre)
                        },
                        menuValueToText: {
                            figureMenuLabel(
                                $0,
                                name: UIStrings.Game.carre,
                                rule: game.notation.ruleCarre
                            )
                        },
                        showsRawValueBadgeWhenTransformed: true,
                        keyPath: \.carre
                    )
                }

                HStack(spacing: 0) {
                    scoreHelpLabel(UIStrings.Game.yams)
                    pickerRowPlayersOnly(
                        allowedValues: yamsAllowedValuesFromSnapshot(),
                        label: UIStrings.Game.yams,
                        valueToText: {
                            figureCellLabel($0, rule: game.notation.ruleYams)
                        },
                        menuValueToText: {
                            figureMenuLabel(
                                $0,
                                name: UIStrings.Game.yams,
                                rule: game.notation.ruleYams
                            )
                        },
                        showsRawValueBadgeWhenTransformed: true,
                        keyPath: \.yams
                    )
                }

                if extraYamsIsEnabled {
                    HStack(spacing: 0) {
                        scoreHelpLabel("Prime Yams supplémentaire")
                        extraYamsRowPlayersOnly()
                    }
                }

                totalsRow(label: UIStrings.Game.total3, valueForPlayer: total3Text)
                totalsRow(label: UIStrings.Game.totalAll, valueForPlayer: totalAllText)
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Sous-vues (labels figés & colonnes joueurs)
    private var scoreHelpIsEnabled: Bool {
        appSettings.first?.showsScoreHelp ?? true
    }

    private func scoreHelpKey(for label: String) -> ScoreHelpKey? {
        switch label {
        case UIStrings.Game.upperSection: return .sectionUpper
        case UIStrings.Game.ones: return .ones
        case UIStrings.Game.twos: return .twos
        case UIStrings.Game.threes: return .threes
        case UIStrings.Game.fours: return .fours
        case UIStrings.Game.fives: return .fives
        case UIStrings.Game.sixes: return .sixes
        case UIStrings.Game.middleSection: return .sectionMiddle
        case UIStrings.Game.max: return .max
        case UIStrings.Game.min: return .min
        case UIStrings.Game.bottomSection: return .sectionBottom
        case UIStrings.Game.brelan: return .brelan
        case UIStrings.Game.chance: return .chance
        case UIStrings.Game.full: return .full
        case UIStrings.Game.suite: return .suite
        case UIStrings.Game.petiteSuite: return .petiteSuite
        case UIStrings.Game.carre: return .carre
        case UIStrings.Game.yams: return .yams
        case "Prime Yams supplémentaire": return .extraYams
        default: return nil
        }
    }

    @ViewBuilder
    private func scoreHelpLabel(
        _ text: String,
        font: Font = .body,
        width: CGFloat? = nil
    ) -> some View {
        let helpText = scoreHelpKey(for: text).flatMap {
            game.notation.helpText(for: $0)
        }

        HStack(spacing: 5) {
            Text(text)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            if scoreHelpIsEnabled, let helpText {
                Button {
                    tipTitle = text
                    tipText = helpText
                    showTip = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aide pour \(text)")
            }

            Spacer(minLength: 0)
        }
        .font(font)
        .frame(
            width: width ?? labelColumnWidth,
            alignment: .leading
        )
    }

    private var gridViewportWidth: CGFloat {
        max(labelColumnWidth, UIScreen.main.bounds.width - outerHPadding - safetyGutter)
    }

    private var upperSectionDetailText: String {
        "Bonus de \(game.notation.upperBonusValue) au seuil de \(game.notation.upperBonusThreshold)"
    }

    private var middleSectionDetailText: String {
        switch game.notation.middleMode {
        case .multiplier:
            return "Multiplicateur par les As"
        case .bonusGate:
            return "Bonus de \(game.notation.middleBonusValue) au seuil de \(game.notation.middleBonusSumThreshold)"
        }
    }

    private func sectionHeader(
        _ sectionTitle: String,
        detail: String? = nil
    ) -> some View {
        let helpText = scoreHelpKey(for: sectionTitle).flatMap {
            game.notation.helpText(for: $0)
        }
        let fullTitle: Text
        if let detail {
            fullTitle = Text(sectionTitle)
                .font(.headline)
                + Text(" – ")
                .font(.headline)
                + Text(detail)
                .font(.subheadline)
                .fontWeight(.regular)
        } else {
            fullTitle = Text(sectionTitle)
                .font(.headline)
        }

        return HStack(spacing: 5) {
            fullTitle
                .lineLimit(1)
                .layoutPriority(1)

            if scoreHelpIsEnabled, let helpText {
                Button {
                    tipTitle = sectionTitle
                    tipText = helpText
                    showTip = true
                } label: {
                    Image(systemName: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Aide pour \(sectionTitle)")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: headerRowHeight)
    }

    // Draw a section header label across the score columns when there are ≥5 players.
    @ViewBuilder
    private func overflowSectionHeader(
        _ sectionTitle: String,
        detail: String? = nil
    ) -> some View {
        Color.clear
            .frame(width: labelColumnWidth)
            .overlay(alignment: .leading) {
                sectionHeader(sectionTitle, detail: detail)
                    .frame(width: gridViewportWidth, alignment: .leading)
            }
    }

    private func labelsColumn() -> some View {
        VStack(spacing: 8) {
            Color.clear.frame(height: namesHeaderHeight + namesHeaderBottom)   // ✅

            // Section haute
            overflowSectionHeader(
                UIStrings.Game.upperSection,
                detail: upperSectionDetailText
            )
                .frame(height: headerRowHeight)
            scoreHelpLabel(UIStrings.Game.ones).frame(height: cellRowHeight)
            scoreHelpLabel(UIStrings.Game.twos).frame(height: cellRowHeight)
            scoreHelpLabel(UIStrings.Game.threes).frame(height: cellRowHeight)
            scoreHelpLabel(UIStrings.Game.fours).frame(height: cellRowHeight)
            scoreHelpLabel(UIStrings.Game.fives).frame(height: cellRowHeight)
            scoreHelpLabel(UIStrings.Game.sixes).frame(height: cellRowHeight)
            Text(UIStrings.Game.total1).font(.headline).frame(height: cellRowHeight, alignment: .leading)

            // Section milieu
            overflowSectionHeader(
                UIStrings.Game.middleSection,
                detail: middleSectionDetailText
            )
                .frame(height: headerRowHeight)
            scoreHelpLabel(UIStrings.Game.max).frame(height: cellRowHeight)
            scoreHelpLabel(UIStrings.Game.min).frame(height: cellRowHeight)
            if game.notation.middleMode == .bonusGate {
                Text("Bonus").font(.headline).frame(height: cellRowHeight, alignment: .leading)
            }
            Text(UIStrings.Game.total2).font(.headline).frame(height: cellRowHeight, alignment: .leading)

            // Section basse
            overflowSectionHeader(UIStrings.Game.bottomSection)
                .frame(height: headerRowHeight)
            scoreHelpLabel(UIStrings.Game.brelan).frame(height: cellRowHeight)
            if game.enableChance { scoreHelpLabel(UIStrings.Game.chance).frame(height: cellRowHeight) }
            scoreHelpLabel(UIStrings.Game.full).frame(height: cellRowHeight)
            scoreHelpLabel(UIStrings.Game.suite).frame(height: cellRowHeight)
            if game.enableSmallStraight { scoreHelpLabel(UIStrings.Game.petiteSuite).frame(height: cellRowHeight) }
            scoreHelpLabel(UIStrings.Game.carre).frame(height: cellRowHeight)
            scoreHelpLabel(UIStrings.Game.yams).frame(height: cellRowHeight)
            if extraYamsIsEnabled { scoreHelpLabel("Prime Yams supplémentaire").frame(height: cellRowHeight) }
            Text(UIStrings.Game.total3).font(.headline).frame(height: cellRowHeight, alignment: .leading)

            // Total général
            Text(UIStrings.Game.totalAll).font(.headline).padding(.top, 6).frame(height: cellRowHeight, alignment: .leading)
        }
        .frame(width: labelColumnWidth, alignment: .leading)
        .font(.body)
    }

    private func playersColumnsHeader() -> some View {
        HStack(spacing: 0) {
            ForEach(Array(displayPlayerIDs.enumerated()), id: \.element) { index, pid in
                let name = allPlayers.first(where: { $0.id == pid })?.nickname ?? "—"
                let baseColor = colorForPlayerID(pid)

                Text(name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: minCellWidth, maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(baseColor.opacity(0.10)) // ← fond des chips
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(baseColor, lineWidth: (game.activePlayerID == pid) ? 2 : 1) // ← contour
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 2)
                    .contentShape(Rectangle())
                    .opacity(canChangePlayerByTap ? 1.0 : 0.45)
                    .onTapGesture { setActivePlayer(pid) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: namesHeaderHeight)
        .padding(.bottom, namesHeaderBottom)
    }

    private func playersColumnsBody() -> some View {
        VStack(spacing: 8) {
            playersColumnsHeader()

            // Section haute
            Color.clear.frame(height: headerRowHeight)
            pickerRowPlayersOnly(allowedValues: allowed(for: 1), label: UIStrings.Game.ones, keyPath: \.ones)
            pickerRowPlayersOnly(allowedValues: allowed(for: 2), label: UIStrings.Game.twos, keyPath: \.twos)
            pickerRowPlayersOnly(allowedValues: allowed(for: 3), label: UIStrings.Game.threes, keyPath: \.threes)
            pickerRowPlayersOnly(allowedValues: allowed(for: 4), label: UIStrings.Game.fours, keyPath: \.fours)
            pickerRowPlayersOnly(allowedValues: allowed(for: 5), label: UIStrings.Game.fives, keyPath: \.fives)
            pickerRowPlayersOnly(allowedValues: allowed(for: 6), label: UIStrings.Game.sixes, keyPath: \.sixes)
            totalsRowPlayersOnly(valueForPlayer: total1Text)

            // Section milieu
            Color.clear.frame(height: headerRowHeight)
            numericRowPlayersOnly(keyPath: \.maxVals, label: UIStrings.Game.max)
            numericRowPlayersOnly(keyPath: \.minVals, label: UIStrings.Game.min)
            if game.notation.middleMode == .bonusGate {
                totalsRowPlayersOnly(valueForPlayer: middleBonusText)
            }
            totalsRowPlayersOnly(valueForPlayer: total2Text)

            // Section basse
            Color.clear.frame(height: headerRowHeight)
            numericRowPlayersOnly(keyPath: \.brelan,
                                  label: UIStrings.Game.brelan,
                                  validator: { ValidationEngine.sanitizeBottom($0, rule: game.notation.ruleBrelan) },
                                  displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleBrelan) })
            if game.enableChance {
                numericRowPlayersOnly(keyPath: \.chance,
                                      label: UIStrings.Game.chance,
                                      validator: { ValidationEngine.sanitizeBottom($0, rule: game.notation.ruleChance) },
                                      displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleChance) })
            }
            numericRowPlayersOnly(keyPath: \.full,
                                  label: UIStrings.Game.full,
                                  validator: { ValidationEngine.sanitizeBottom($0, rule: game.notation.ruleFull) },
                                  displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleFull) })

            pickerRowPlayersOnly(allowedValues: suiteAllowedValuesFromSnapshot(),
                                 label: UIStrings.Game.suite,
                                 valueToText: GDV_Helpers.displaySuiteValue,
                                 keyPath: \.suite)
            
            if game.enableSmallStraight {
                pickerRowPlayersOnly(allowedValues: petiteSuiteAllowedValuesFromSnapshot(),
                                     label: UIStrings.Game.petiteSuite,
                                     valueToText: GDV_Helpers.displayPetiteSuiteValue,
                                     keyPath: \.petiteSuite)
            }

            pickerRowPlayersOnly(
                allowedValues: carreAllowedValuesFromSnapshot(),
                label: UIStrings.Game.carre,
                valueToText: {
                    figureCellLabel($0, rule: game.notation.ruleCarre)
                },
                menuValueToText: {
                    figureMenuLabel(
                        $0,
                        name: UIStrings.Game.carre,
                        rule: game.notation.ruleCarre
                    )
                },
                showsRawValueBadgeWhenTransformed: true,
                keyPath: \.carre
            )

            pickerRowPlayersOnly(
                allowedValues: yamsAllowedValuesFromSnapshot(),
                label: UIStrings.Game.yams,
                valueToText: {
                    figureCellLabel($0, rule: game.notation.ruleYams)
                },
                menuValueToText: {
                    figureMenuLabel(
                        $0,
                        name: UIStrings.Game.yams,
                        rule: game.notation.ruleYams
                    )
                },
                showsRawValueBadgeWhenTransformed: true,
                keyPath: \.yams
            )

            if extraYamsIsEnabled {
                extraYamsRowPlayersOnly()
            }

            totalsRowPlayersOnly(valueForPlayer: total3Text)
            totalsRowPlayersOnly(valueForPlayer: totalAllText)
                .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Lignes compactes (≤4 joueurs)
    private func rowUpper(label: String, face: Int, keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack(spacing: 0) {
            scoreHelpLabel(label)
            pickerRowPlayersOnly(allowedValues: allowed(for: face), label: label, keyPath: keyPath)
        }
    }

    private func rowMaxMin(label: String, keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack(spacing: 0) {
            scoreHelpLabel(label)
            numericRowPlayersOnly(keyPath: keyPath, label: label)
        }
    }

    private func rowBottom(label: String,
                           keyPath: WritableKeyPath<Scorecard, [Int]>,
                           validator: ((Int?) -> Int)? = nil,
                           displayMap: ((Int) -> String)? = nil) -> some View {
        HStack(spacing: 0) {
            scoreHelpLabel(label)
            numericRowPlayersOnly(keyPath: keyPath, label: label, validator: validator, displayMap: displayMap)
        }
    }

    // MARK: - Rows (players only)
    private func numericRowPlayersOnly(keyPath: WritableKeyPath<Scorecard, [Int]>,
                                       label: String,
                                       validator: ((Int?) -> Int)? = nil,
                                       displayMap: ((Int) -> String)? = nil) -> some View {
        HStack(spacing: 0) {
            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let scBinding = $game.scorecards[playerIdx]
                    let binding   = valueBinding(scBinding, keyPath, scoreColumnIndex, label: label)
                    let isFilled = binding.wrappedValue >= 0 // -1 = vide
                    let isEditable = canEditScoreCell(for: pid, label: label)
                    // En mode sombre, pour la colonne du joueur actif, on garde la teinte claire
                    // même si la case est "remplie", afin que le caret et le texte restent lisibles.
                    let effectiveFilledForTint =
                        (colorScheme == .dark && isCellEnabled(for: pid)) ? false : isFilled
                    let cfg = NumericRow.Config(
                        inputID: "\(game.id.uuidString).\(pid.uuidString).\(storageKey(for: label)).\(scoreColumnIndex)",
                        value: binding,
                        isLocked: false,
                        isActive: isEditable,
                        validator: { newVal in
                            if keyPath == \Scorecard.maxVals {
                                let currentMin = game.scorecards[playerIdx].minVals[scoreColumnIndex]
                                return ValidationEngine.sanitizeMiddleMax(
                                    newVal,
                                    currentMin: (currentMin >= 0 ? currentMin : nil),
                                    strictGreater: (game.notation.middleMode == .bonusGate)
                                )
                            } else if keyPath == \Scorecard.minVals {
                                let currentMax = game.scorecards[playerIdx].maxVals[scoreColumnIndex]
                                return ValidationEngine.sanitizeMiddleMin(
                                    newVal,
                                    currentMax: (currentMax >= 0 ? currentMax : nil),
                                    strictGreater: (game.notation.middleMode == .bonusGate)
                                )
                            } else if let fn = validator {
                                let raw = newVal ?? -1
                                let sanitized = fn(newVal)
                                if raw > 0 && sanitized != raw { return -1 }
                                return sanitized
                            } else {
                                return newVal ?? -1
                            }
                        },
                        displayMap: displayMap,
                        valueFont: badgeFont,
                        effectiveFont: cellFont,
                        contentPadding: cellPadding,
                        allowedRange: (
                            label == UIStrings.Game.carre ? (4...30) : (5...30)
                        ),
                        allowZero: (
                            label == UIStrings.Game.brelan
                                || label == UIStrings.Game.chance
                                || label == UIStrings.Game.full
                                || label == UIStrings.Game.suite
                                || label == UIStrings.Game.petiteSuite
                                || label == UIStrings.Game.carre
                                || label == UIStrings.Game.yams
                        ),
                        onInvalidInput: { value in
                            alertMessage = "La valeur \(value) n’est pas valide pour \(label)."
                            showAlert = true
                        },
                        containerFill: AnyShapeStyle(Color.clear),
                        textColor: .primary,
                        caretTint: .primary
                    )

                    // Draw the tinted background BEHIND the NumericRow (fixes dark-mode caret visibility)
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(columnTint(pid: pid, isFilled: effectiveFilledForTint))
                        NumericRow(cfg)
                            .id(cfg.inputID)
                            .frame(
                                minWidth: minCellWidth,
                                maxWidth: .infinity,
                                alignment: .leading
                            )
                            .frame(height: cellRowHeight)
                            .background(Color.clear)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func pickerRowPlayersOnly(allowedValues: [Int],
                                      label: String,
                                      valueToText: ((Int) -> String)? = nil,
                                      menuValueToText: ((Int) -> String)? = nil,
                                      showsRawValueBadgeWhenTransformed: Bool = false,
                                      keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack(spacing: 0) {
            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let scBinding = $game.scorecards[playerIdx]
                    let binding   = valueBinding(scBinding, keyPath, scoreColumnIndex, label: label)
                    let isEditable = canEditScoreCell(for: pid, label: label)
                    let rawValue = binding.wrappedValue
                    let displayedValue = valueToText.map { $0(rawValue) }
                        ?? (rawValue == -1 ? UIStrings.Common.dash : String(rawValue))
                    let rawText = rawValue >= 0 ? String(rawValue) : ""
                    let showsRawBadge = showsRawValueBadgeWhenTransformed
                        && rawValue > 0
                        && displayedValue != rawText

                    Menu {
                        Picker("Valeur", selection: binding) {
                            ForEach([-1] + allowedValues, id: \.self) { v in
                                let title: String = {
                                    if label == UIStrings.Game.suite {
                                        return suiteMenuLabelFromSnapshot(v)
                                } else if label == UIStrings.Game.petiteSuite {
                                    return petiteSuiteMenuLabelFromSnapshot(v)
                                } else {
                                    return menuValueToText.map { $0(v) }
                                        ?? valueToText.map { $0(v) }
                                        ?? (v == -1 ? UIStrings.Common.dash : String(v))
                                }
                            }()
                                Text(title).tag(v)
                            }
                        }
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(columnTint(pid: pid, isFilled: rawValue >= 0))

                            Text(displayedValue)
                                .font(cellFont)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(
                                    .horizontal,
                                    showsRawBadge ? max(16, cellPadding * 2) : cellPadding
                                )

                            if showsRawBadge {
                                Text(rawText)
                                    .font(badgeFont)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, max(4, cellPadding * 0.75))
                                    .padding(.vertical, max(2, cellPadding * 0.25))
                                    .background(Color.black.opacity(0.06))
                                    .clipShape(Capsule())
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .padding(.trailing, max(4, cellPadding * 0.75))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.6)
                            }
                        }
                            .frame(minWidth: minCellWidth, maxWidth: .infinity)
                            .frame(height: cellRowHeight)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(!isEditable)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    // MARK: - Totaux
    private func middleCanCompute(playerIdx: Int) -> Bool {
        let sc = game.scorecards[playerIdx]
        switch game.notation.middleMode {
        case .multiplier:
            return sc.maxVals[scoreColumnIndex] >= 0
            &&     sc.minVals[scoreColumnIndex] >= 0
            &&     sc.ones[scoreColumnIndex]    >= 0
        case .bonusGate:
            return sc.maxVals[scoreColumnIndex] >= 0
            &&     sc.minVals[scoreColumnIndex] >= 0
        }
    }

    private func total1Text(_ playerIdx: Int) -> String {
        let sc = game.scorecards[playerIdx]
        return String(StatsEngine.upperTotal(sc: sc, game: game, col: scoreColumnIndex))
    }

    private func total2Text(_ playerIdx: Int) -> String {
        guard middleCanCompute(playerIdx: playerIdx) else { return UIStrings.Common.dash }
        let sc = game.scorecards[playerIdx]
        return String(StatsEngine.middleTotal(sc: sc, game: game, col: scoreColumnIndex))
    }

    private func middleBonusText(_ playerIdx: Int) -> String {
        guard middleCanCompute(playerIdx: playerIdx) else { return UIStrings.Common.dash }
        let sc = game.scorecards[playerIdx]
        return String(
            StatsEngine.middleBonusAmount(
                maxValue: StatsEngine.norm(sc.maxVals[scoreColumnIndex]),
                minValue: StatsEngine.norm(sc.minVals[scoreColumnIndex]),
                threshold: game.notation.middleBonusSumThreshold,
                bonus: game.notation.middleBonusValue
            )
        )
    }

    private func total3Text(_ playerIdx: Int) -> String {
        let sc = game.scorecards[playerIdx]
        return String(StatsEngine.bottomTotal(sc: sc, game: game, col: scoreColumnIndex))
    }

    private func totalAllText(_ playerIdx: Int) -> String {
        let sc = game.scorecards[playerIdx]
        let upper  = StatsEngine.upperTotal(sc: sc, game: game, col: scoreColumnIndex)
        let bottom = StatsEngine.bottomTotal(sc: sc, game: game, col: scoreColumnIndex)
        let middle = middleCanCompute(playerIdx: playerIdx)
            ? StatsEngine.middleTotal(sc: sc, game: game, col: scoreColumnIndex)
            : 0
        return String(upper + middle + bottom)
    }

    private func totalScore(for playerID: UUID) -> Int {
        if let idx = game.scorecards.firstIndex(where: { $0.playerID == playerID }) {
            return Int(totalAllText(idx)) ?? 0
        }
        return 0
    }

    @ViewBuilder
    private func totalsRowPlayersOnly(valueForPlayer: @escaping (_ playerIdx: Int) -> String) -> some View {
        HStack(spacing: 0) {
            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let text = valueForPlayer(playerIdx)
                    Text(text)
                        .font(.headline)
                        .frame(minWidth: minCellWidth, maxWidth: .infinity)
                        .frame(height: cellRowHeight)
                        .padding(.horizontal, cellPadding)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(columnTint(pid: pid, isFilled: true))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    @ViewBuilder
    private func totalsRow(label: String, valueForPlayer: @escaping (_ playerIdx: Int) -> String) -> some View {
        HStack(spacing: 0) {
            Text(label).font(.headline).frame(width: labelColumnWidth, alignment: .leading)
            totalsRowPlayersOnly(valueForPlayer: valueForPlayer)
        }
    }

    // MARK: - Extra Yams
    private var extraYamsIsEnabled: Bool {
        game.extraYamsBonusMode != .disabled
    }

    private func storageKey(for label: String) -> String {
        switch label {
        case UIStrings.Game.ones: return "ones"
        case UIStrings.Game.twos: return "twos"
        case UIStrings.Game.threes: return "threes"
        case UIStrings.Game.fours: return "fours"
        case UIStrings.Game.fives: return "fives"
        case UIStrings.Game.sixes: return "sixes"
        case UIStrings.Game.max: return "max"
        case UIStrings.Game.min: return "min"
        case UIStrings.Game.brelan: return "brelan"
        case UIStrings.Game.chance: return "chance"
        case UIStrings.Game.full: return "full"
        case UIStrings.Game.suite: return "suite"
        case UIStrings.Game.petiteSuite: return "petiteSuite"
        case UIStrings.Game.carre: return "carre"
        case UIStrings.Game.yams: return "yams"
        default: return label
        }
    }

    @ViewBuilder
    private func turnActionsControl() -> some View {
        let showsYamsDeclaration = canShowTurnYamsDeclaration

        HStack(spacing: 8) {
            if showsYamsDeclaration {
                turnYamsDeclarationControl()
            }

            if hasReachedTurnChangeLimit {
                Button {
                    undoCurrentTurnChanges()
                } label: {
                    Label("Annuler", systemImage: "arrow.uturn.backward")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .foregroundStyle(.secondary)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.10))
                        )
                        .overlay(
                            Capsule()
                                .stroke(Color.secondary.opacity(0.20), lineWidth: 1)
                        )
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Annuler les modifications du tour")
            }

            if !showsYamsDeclaration && !hasReachedTurnChangeLimit {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 38)
    }

    private var canShowTurnYamsDeclaration: Bool {
        guard canShowNextButton,
              let pid = game.activePlayerID,
              let playerIdx = scorecardIndexByPlayerID[pid],
              let key = currentTurnScoreKey,
              key != "yams" else { return false }
        return scoreValue(for: key, in: game.scorecards[playerIdx]) > 0
    }

    @ViewBuilder
    private func turnYamsDeclarationControl() -> some View {
        if canShowTurnYamsDeclaration,
           let pid = game.activePlayerID,
           let playerIdx = scorecardIndexByPlayerID[pid],
           let key = currentTurnScoreKey,
           key != "yams" {
            let scBinding = $game.scorecards[playerIdx]
            let isDeclared = scBinding.wrappedValue.isDeclaredYams(
                col: scoreColumnIndex,
                key: key
            )

            Button {
                let newValue = !isDeclared
                scBinding.wrappedValue.setDeclaredYams(
                    newValue,
                    col: scoreColumnIndex,
                    key: key
                )

                try? context.save()
            } label: {
                Label(
                    isDeclared ? "Ce lancer est déclaré comme Yams" : "Ce lancer est un Yams",
                    systemImage: isDeclared ? "checkmark.circle.fill" : "dice"
                )
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .frame(height: 38)
                .foregroundStyle(Color.accentColor.opacity(isDeclared ? 1 : 0.85))
                .background(
                    Capsule()
                        .fill(Color.accentColor.opacity(isDeclared ? 0.24 : 0.07))
                )
                .overlay(
                    Capsule()
                        .stroke(
                            Color.accentColor.opacity(isDeclared ? 0.55 : 0.14),
                            lineWidth: isDeclared ? 1.5 : 1
                        )
                )
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Indique que les cinq dés avaient la même valeur")
        }
    }

    @ViewBuilder
    private func extraYamsRowPlayersOnly() -> some View {
        HStack(spacing: 0) {
            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let scBinding = $game.scorecards[playerIdx]
                    let awardCount = scBinding.wrappedValue.extraYamsAwardsCount(col: scoreColumnIndex)
                    let isActivePlayer = (game.activePlayerID == pid)
                    let source = isActivePlayer ? currentTurnScoreKey : nil
                    let isCurrentThrowYams: Bool = {
                        guard let source else { return false }
                        if source == "yams" {
                            return scoreValue(for: source, in: scBinding.wrappedValue) > 0
                        }
                        return scBinding.wrappedValue.isDeclaredYams(
                            col: scoreColumnIndex,
                            key: source
                        )
                    }()
                    let currentThrowAlreadyAwarded = source.map {
                        scBinding.wrappedValue.hasExtraYamsAward(
                            col: scoreColumnIndex,
                            source: $0
                        )
                    } ?? false
                    let hasReachedSecondYams = StatsService.yamsCount(
                        for: scBinding.wrappedValue,
                        col: scoreColumnIndex
                    ) >= 2
                    let modeAllowsAnother = game.extraYamsBonusMode == .multiple
                        || awardCount == 0
                    let canGrant = isActivePlayer
                        && isCurrentThrowYams
                        && hasReachedSecondYams
                        && modeAllowsAnother
                        && !currentThrowAlreadyAwarded

                    ZStack(alignment: .topTrailing) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(columnTint(pid: pid, isFilled: awardCount > 0))

                        if canGrant, let source {
                            Button {
                                scBinding.wrappedValue.addExtraYamsAward(
                                    col: scoreColumnIndex,
                                    source: source
                                )
                                try? context.save()
                            } label: {
                                Text("+")
                                    .font(.system(
                                        size: max(14, min(22, minCellWidth * 0.6)),
                                        weight: .semibold
                                    ))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .padding(.horizontal, cellPadding)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Attribuer une prime Yams supplémentaire")
                        } else if awardCount > 0 {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.seal.fill")
                                    .imageScale(.medium)
                                Text("\(awardCount)×\(game.notation.extraYamsBonusValue)")
                                    .font(badgeFont)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.75)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, cellPadding)
                            .frame(
                                maxWidth: .infinity,
                                maxHeight: .infinity,
                                alignment: .leading
                            )

                            if isActivePlayer && currentThrowAlreadyAwarded {
                                Button(role: .destructive) {
                                    revokePlayerIdx = playerIdx
                                    showRevokeYams = true
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .imageScale(.medium)
                                }
                                .buttonStyle(.borderless)
                                .padding(6)
                            }
                        } else {
                            Text(UIStrings.Common.dash)
                                .font(cellFont)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .padding(.horizontal, cellPadding)
                                .frame(
                                    maxWidth: .infinity,
                                    maxHeight: .infinity,
                                    alignment: .center
                                )
                        }
                    }
                    .frame(minWidth: minCellWidth, maxWidth: .infinity)
                    .frame(height: cellRowHeight)
                    .contextMenu {
                        if currentThrowAlreadyAwarded {
                            Button("Retirer la prime", role: .destructive) {
                                revokeExtraYams(for: playerIdx)
                            }
                        } else {
                            Button("Conditions") {
                                tipTitle = "Prime Yams supplémentaire"
                                tipText = game.extraYamsBonusMode == .multiple
                                    ? "Chaque Yams après le premier peut recevoir une prime."
                                    : "Une seule prime peut être attribuée après le premier Yams."
                                showTip = true
                            }
                        }
                    }
                    .disabled(!isActivePlayer)
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private func sanitizeYamsForSnapshot(_ newVal: Int?) -> Int {
        guard let v = newVal else { return -1 }
        if v == 0 { return 0 }
        let bases: Set<Int> = [5, 10, 15, 20, 25, 30]
        let rule = game.notation.ruleYams
        switch rule.mode {
        case .fixed: return rule.fixedValue
        default:     return bases.contains(v) ? v : -1
        }
    }

    // MARK: - Helpers communs
    private func recordScoreChange(
        playerID: UUID,
        key: String,
        previous: Int,
        newValue: Int
    ) {
        guard game.statusOrDefault == .inProgress,
              game.activePlayerID == playerID,
              previous != newValue,
              let sc = game.scorecards.first(where: { $0.playerID == playerID }) else {
            return
        }

        if turnStartScoreValuesByPlayer[playerID] == nil {
            var start = scoreSnapshot(for: sc)
            start[key] = previous
            turnStartScoreValuesByPlayer[playerID] = start
            turnStartFilledKeysByPlayer[playerID] = Set(
                start.compactMap { $0.value >= 0 ? $0.key : nil }
            )
        }

        let startValue = turnStartScoreValuesByPlayer[playerID]?[key] ?? -1
        if currentTurnScoreKeyByPlayer[playerID] == key,
           newValue == startValue {
            currentTurnScoreKeyByPlayer[playerID] = nil
        }

        if currentTurnScoreKeyByPlayer[playerID] == nil,
           startValue < 0,
           newValue >= 0,
           turnEvaluation(for: playerID).filledDelta == 1 {
            currentTurnScoreKeyByPlayer[playerID] = key
        }
    }

    private func allowed(for face: Int) -> [Int] { Validators.allowedUpperValues(face: face) }

    private func valueBinding(_ sc: Binding<Scorecard>,
                              _ keyPath: WritableKeyPath<Scorecard, [Int]>,
                              _ col: Int,
                              label: String) -> Binding<Int> {
        Binding<Int>(
            get: {
                let arr = sc.wrappedValue[keyPath: keyPath]
                return (col < arr.count && col >= 0) ? arr[col] : -1
            },
            set: { newVal in
                var arr = sc.wrappedValue[keyPath: keyPath]
                if col < arr.count && col >= 0 {
                    let previous = arr[col]
                    let playerID = sc.wrappedValue.playerID
                    arr[col] = newVal
                    sc.wrappedValue[keyPath: keyPath] = arr
                    recordScoreChange(
                        playerID: playerID,
                        key: storageKey(for: label),
                        previous: previous,
                        newValue: newVal
                    )
                    if newVal <= 0 {
                        let key = storageKey(for: label)
                        sc.wrappedValue.setDeclaredYams(false, col: col, key: key)
                        if sc.wrappedValue.extraYamsSource(col: col) == key {
                            sc.wrappedValue.setExtraYamsSource(nil, col: col)
                        }
                    }
                }
            }
        )
    }


    // MARK: - DEBUG
    #if DEBUG
    private func ensureCapacity(_ arr: inout [Int], at idx: Int) {
        if idx >= arr.count { arr.append(contentsOf: Array(repeating: -1, count: idx - arr.count + 1)) }
    }
    private func debugSetValue(playerIdx: Int, keyPath: WritableKeyPath<Scorecard, [Int]>, value: Int) {
        var arr = game.scorecards[playerIdx][keyPath: keyPath]
        ensureCapacity(&arr, at: scoreColumnIndex)
        arr[scoreColumnIndex] = value
        game.scorecards[playerIdx][keyPath: keyPath] = arr
    }
    private func debugFillAllRequiredAndComplete(showNotification: Bool = false) {
        for i in game.scorecards.indices {
            // haute
            debugSetValue(playerIdx: i, keyPath: \.ones,   value: 0)
            debugSetValue(playerIdx: i, keyPath: \.twos,   value: 0)
            debugSetValue(playerIdx: i, keyPath: \.threes, value: 0)
            debugSetValue(playerIdx: i, keyPath: \.fours,  value: 0)
            debugSetValue(playerIdx: i, keyPath: \.fives,  value: 0)
            debugSetValue(playerIdx: i, keyPath: \.sixes,  value: 0)
            // milieu
            debugSetValue(playerIdx: i, keyPath: \.maxVals, value: 0)
            debugSetValue(playerIdx: i, keyPath: \.minVals, value: 0)
            // basse
            debugSetValue(playerIdx: i, keyPath: \.brelan, value: 0)
            if game.enableChance { debugSetValue(playerIdx: i, keyPath: \.chance, value: 0) }
            debugSetValue(playerIdx: i, keyPath: \.full,  value: 0)
            debugSetValue(playerIdx: i, keyPath: \.suite, value: 0)
            if game.enableSmallStraight { debugSetValue(playerIdx: i, keyPath: \.petiteSuite, value: 0) }
            debugSetValue(playerIdx: i, keyPath: \.carre, value: 0)
            debugSetValue(playerIdx: i, keyPath: \.yams,  value: 0)
        }
        game.statusOrDefault = .completed
        game.endedAt = Date()
        try? context.save()

        let ranking: [(String, Int)] = orderedPlayers
            .map { ($0.nickname, totalScore(for: $0.id)) }
            .sorted { $0.1 > $1.1 }

        if showNotification {
            NotificationManager.postEndGame(
                winnerName: ranking.first?.0 ?? "—",
                gameName: game.name,
                rankings: ranking
            )
        } else {
            endGameEntries = ranking.map { .init(name: $0.0, score: $0.1) }
            showCongrats = true
        }
    }
    #endif
}

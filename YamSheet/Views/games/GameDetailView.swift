//
//  GameDetailView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 06/09/2025.
//

import SwiftUI
import SwiftData

struct GameDetailView: View {
    // MARK: - Env & Model
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Query private var allPlayers: [Player]
    @Bindable var game: Game

    // MARK: - UI State
    @State private var showTip = false
    @State private var tipText = ""
    @State private var showRevokeYams = false
    @State private var revokePlayerIdx: Int? = nil
    @State private var showEndGameSheet = false
    @State private var showOrderSheet = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    @State private var showCongrats = false
    @State private var endGameEntries: [EndGameCongratsView.Entry] = []

    // MARK: - Columns (multi-colonnes plus tard)
    private var scoreColumnIndex: Int { 0 }

    // MARK: - Layout
    private let outerHPadding: CGFloat = 32    // .padding(.horizontal) 16+16
    private let labelColumnWidth: CGFloat = 110
    private let perColumnOuterPad: CGFloat = 4 // padding(.horizontal,2) visuel sur colonnes
    private let safetyGutter: CGFloat = 8      // marge anti-rognage

    /// IDs des joueurs à afficher (actif d’abord)
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
        }
    }

    private var canShowNextButton: Bool {
        guard game.statusOrDefault == .inProgress, let pid = game.activePlayerID else { return false }
        let now = currentFillableCount(for: pid)
        let start = game.lastFilledCountByPlayer[pid] ?? now
        return (now - start) == 1
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
        guard game.canEndTurn(for: pid, fillableCount: countNow) else {
            alertMessage = "Ce joueur doit remplir exactement 1 case avant de passer son tour."
            showAlert = true
            return
        }
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
        let start = game.lastFilledCountByPlayer[pid] ?? now
        guard (now - start) == 1 else { return false }

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

    private func cellBackground(col: Int, isOpen: Bool) -> some View {
        Group {
            if isActiveIndex(col) {
                (isOpen ? Color.blue.opacity(0.12) : Color.green.opacity(0.12))
            } else {
                Color.gray.opacity(0.08)
            }
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
        print("[GameDetailView] Auto-pause (\(reason)) • didAdvance=\(didAdvance)")
        #endif
    }

    private func revokeExtraYams(for playerIdx: Int) {
        var arr = game.scorecards[playerIdx].extraYamsAwarded
        if scoreColumnIndex < arr.count && scoreColumnIndex >= 0 {
            arr[scoreColumnIndex] = false
            game.scorecards[playerIdx].extraYamsAwarded = arr
            try? context.save()
        }
    }

    private func setActivePlayer(_ pid: UUID) {
        guard game.statusOrDefault == .inProgress else { return }
        guard let current = game.activePlayerID else { return }
        if current == pid { return }

        let now = currentFillableCount(for: current)
        let start = game.lastFilledCountByPlayer[current] ?? now
        guard (now - start) >= 1 else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            alertMessage = "Remplis au moins une case avant de changer de joueur."
            showAlert = true
            return
        }
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
        GDV_Header(title: game.name, subtitle: statusSubtitle)
        GDV_PlayerChips(
            players: orderedPlayers.map { $0.nickname },
            activeIndex: activeIndexForChips
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Body
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                modernHeader()
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
        .onChange(of: game.activePlayerID) { _, _ in ensureTurnSnapshotInitialized() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { autoPauseIfNeeded(reason: "scenePhase=\(phase)") }
        }
        .onDisappear { autoPauseIfNeeded(reason: "onDisappear") }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        .navigationTitle(UIStrings.Game.title)
        .toolbar {
#if DEBUG
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
#endif
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

    // MARK: - Grid (≤4 joueurs compact, ≥5 joueurs labels figés + scroll horizontal)
    @ViewBuilder private func grid() -> some View {
        let needsHorizontal = displayPlayerIDs.count >= 5

        if needsHorizontal {
            HStack(alignment: .top, spacing: 0) {
                labelsColumn()
                ScrollView(.horizontal) {
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
                HStack { Text(UIStrings.Game.upperSection).font(.headline).frame(width: labelColumnWidth, alignment: .leading); Spacer() }
                rowUpper(label: UIStrings.Game.ones,   face: 1, keyPath: \Scorecard.ones)
                rowUpper(label: UIStrings.Game.twos,   face: 2, keyPath: \Scorecard.twos)
                rowUpper(label: UIStrings.Game.threes, face: 3, keyPath: \Scorecard.threes)
                rowUpper(label: UIStrings.Game.fours,  face: 4, keyPath: \Scorecard.fours)
                rowUpper(label: UIStrings.Game.fives,  face: 5, keyPath: \Scorecard.fives)
                rowUpper(label: UIStrings.Game.sixes,  face: 6, keyPath: \Scorecard.sixes)
                totalsRow(label: UIStrings.Game.total1, valueForPlayer: total1Text)

                // Section milieu
                HStack { Text(UIStrings.Game.middleSection).font(.headline).frame(width: labelColumnWidth, alignment: .leading); Spacer() }
                rowMaxMin(label: UIStrings.Game.max, keyPath: \Scorecard.maxVals)
                rowMaxMin(label: UIStrings.Game.min, keyPath: \Scorecard.minVals)
                totalsRow(label: UIStrings.Game.total2, valueForPlayer: total2Text)

                // Section basse
                HStack { Text(UIStrings.Game.bottomSection).font(.headline).frame(width: labelColumnWidth, alignment: .leading); Spacer() }
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
                    Text(UIStrings.Game.suite).frame(width: labelColumnWidth, alignment: .leading)
                    pickerRowPlayersOnly(allowedValues: [0,15,20],
                                         label: UIStrings.Game.suite,
                                         valueToText: GDV_Helpers.displaySuiteValue,
                                         keyPath: \.suite)
                }

                if game.enableSmallStraight {
                    HStack(spacing: 0) {
                        Text(UIStrings.Game.petiteSuite).frame(width: labelColumnWidth, alignment: .leading)
                        pickerRowPlayersOnly(allowedValues: [0,1],
                                             label: UIStrings.Game.petiteSuite,
                                             valueToText: GDV_Helpers.displayPetiteSuiteValue,
                                             keyPath: \.petiteSuite)
                    }
                }

                rowBottom(label: UIStrings.Game.carre, keyPath: \Scorecard.carre,
                          validator: { ValidationEngine.sanitizeBottom($0, rule: game.notation.ruleCarre) },
                          displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleCarre) })

                rowBottom(label: UIStrings.Game.yams, keyPath: \Scorecard.yams,
                          validator: { sanitizeYamsForSnapshot($0) },
                          displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleYams) })

                if extraYamsIsEnabled {
                    HStack(spacing: 0) {
                        Text("Prime Yams supplémentaire").frame(width: labelColumnWidth, alignment: .leading)
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
    private func labelsColumn() -> some View {
        VStack(spacing: 8) {
            Color.clear.frame(height: 26) // header placeholder

            // Section haute
            HStack { Text(UIStrings.Game.upperSection).font(.headline); Spacer() }
            Text(UIStrings.Game.ones)
            Text(UIStrings.Game.twos)
            Text(UIStrings.Game.threes)
            Text(UIStrings.Game.fours)
            Text(UIStrings.Game.fives)
            Text(UIStrings.Game.sixes)
            Text(UIStrings.Game.total1).font(.headline)

            // Section milieu
            HStack { Text(UIStrings.Game.middleSection).font(.headline); Spacer() }
            Text(UIStrings.Game.max)
            Text(UIStrings.Game.min)
            Text(UIStrings.Game.total2).font(.headline)

            // Section basse
            HStack { Text(UIStrings.Game.bottomSection).font(.headline); Spacer() }
            Text(UIStrings.Game.brelan)
            if game.enableChance { Text(UIStrings.Game.chance) }
            Text(UIStrings.Game.full)
            Text(UIStrings.Game.suite)
            if game.enableSmallStraight { Text(UIStrings.Game.petiteSuite) }
            Text(UIStrings.Game.carre)
            Text(UIStrings.Game.yams)
            if extraYamsIsEnabled { Text("Prime Yams supplémentaire") }
            Text(UIStrings.Game.total3).font(.headline)

            // Total général
            Text(UIStrings.Game.totalAll).font(.headline).padding(.top, 6)
        }
        .frame(width: labelColumnWidth, alignment: .leading)
        .font(.body)
    }

    private func playersColumnsHeader() -> some View {
        HStack(spacing: 0) {
            ForEach(displayPlayerIDs, id: \.self) { pid in
                let name = allPlayers.first(where: { $0.id == pid })?.nickname ?? "—"
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(minWidth: minCellWidth, maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background((game.activePlayerID == pid) ? Color.yellow.opacity(0.28) : Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 2)
                    .contentShape(Rectangle())
                    .opacity(canChangePlayerByTap ? 1.0 : 0.45)
                    .onTapGesture { setActivePlayer(pid) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }

    private func playersColumnsBody() -> some View {
        VStack(spacing: 8) {
            playersColumnsHeader()

            // Section haute
            Color.clear.frame(height: 0)
            pickerRowPlayersOnly(allowedValues: allowed(for: 1), label: UIStrings.Game.ones, keyPath: \.ones)
            pickerRowPlayersOnly(allowedValues: allowed(for: 2), label: UIStrings.Game.twos, keyPath: \.twos)
            pickerRowPlayersOnly(allowedValues: allowed(for: 3), label: UIStrings.Game.threes, keyPath: \.threes)
            pickerRowPlayersOnly(allowedValues: allowed(for: 4), label: UIStrings.Game.fours, keyPath: \.fours)
            pickerRowPlayersOnly(allowedValues: allowed(for: 5), label: UIStrings.Game.fives, keyPath: \.fives)
            pickerRowPlayersOnly(allowedValues: allowed(for: 6), label: UIStrings.Game.sixes, keyPath: \.sixes)
            totalsRowPlayersOnly(valueForPlayer: total1Text)

            // Section milieu
            Color.clear.frame(height: 0)
            numericRowPlayersOnly(keyPath: \.maxVals, label: UIStrings.Game.max)
            numericRowPlayersOnly(keyPath: \.minVals, label: UIStrings.Game.min)
            totalsRowPlayersOnly(valueForPlayer: total2Text)

            // Section basse
            Color.clear.frame(height: 0)
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

            pickerRowPlayersOnly(allowedValues: [0,15,20],
                                 label: UIStrings.Game.suite,
                                 valueToText: GDV_Helpers.displaySuiteValue,
                                 keyPath: \.suite)

            if game.enableSmallStraight {
                pickerRowPlayersOnly(allowedValues: [0,1],
                                     label: UIStrings.Game.petiteSuite,
                                     valueToText: GDV_Helpers.displayPetiteSuiteValue,
                                     keyPath: \.petiteSuite)
            }

            numericRowPlayersOnly(keyPath: \.carre,
                                  label: UIStrings.Game.carre,
                                  validator: { ValidationEngine.sanitizeBottom($0, rule: game.notation.ruleCarre) },
                                  displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleCarre) })

            numericRowPlayersOnly(keyPath: \.yams,
                                  label: UIStrings.Game.yams,
                                  validator: { sanitizeYamsForSnapshot($0) },
                                  displayMap: { ValidationEngine.displayForBottom(stored: $0, rule: game.notation.ruleYams) })

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
            Text(label).frame(width: labelColumnWidth, alignment: .leading)
            pickerRowPlayersOnly(allowedValues: allowed(for: face), label: label, keyPath: keyPath)
        }
    }

    private func rowMaxMin(label: String, keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack(spacing: 0) {
            Text(label).frame(width: labelColumnWidth, alignment: .leading)
            numericRowPlayersOnly(keyPath: keyPath, label: label)
        }
    }

    private func rowBottom(label: String,
                           keyPath: WritableKeyPath<Scorecard, [Int]>,
                           validator: ((Int?) -> Int)? = nil,
                           displayMap: ((Int) -> String)? = nil) -> some View {
        HStack(spacing: 0) {
            Text(label).frame(width: labelColumnWidth, alignment: .leading)
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
                    let isLocked  = scBinding.wrappedValue.isLocked(col: scoreColumnIndex, key: label)
                    let binding   = valueBinding(scBinding, keyPath, scoreColumnIndex)

                    let cfg = NumericRow.Config(
                        value: binding,
                        isLocked: isLocked,
                        isActive: isCellEnabled(for: pid),
                        validator: { newVal in
                            let idx = activeScorecardIndex ?? playerIdx
                            if keyPath == \Scorecard.maxVals {
                                let currentMin = game.scorecards[idx].minVals[scoreColumnIndex]
                                return ValidationEngine.sanitizeMiddleMax(newVal,
                                                                          currentMin: (currentMin >= 0 ? currentMin : nil),
                                                                          strictGreater: (game.notation.middleMode == .bonusGate))
                            } else if keyPath == \Scorecard.minVals {
                                let currentMax = game.scorecards[idx].maxVals[scoreColumnIndex]
                                return ValidationEngine.sanitizeMiddleMin(newVal,
                                                                          currentMax: (currentMax >= 0 ? currentMax : nil),
                                                                          strictGreater: (game.notation.middleMode == .bonusGate))
                            } else if let v = validator?(newVal) {
                                return v
                            } else {
                                return newVal ?? -1
                            }
                        },
                        displayMap: displayMap,
                        valueFont: badgeFont,
                        effectiveFont: cellFont,
                        contentPadding: cellPadding
                    )

                    NumericRow(cfg)
                        .frame(minWidth: minCellWidth, maxWidth: .infinity, alignment: .leading)
                        .contextMenu {
                            Button(UIStrings.Common.validate) {
                                scBinding.wrappedValue.setLocked(true, col: scoreColumnIndex, key: label)
                                try? context.save()
                            }
                            Button(UIStrings.Common.clear) { binding.wrappedValue = -1 }
                        }
                        .disabled(isLocked || !isCellEnabled(for: pid))
                        .padding(.horizontal, 2)
                }
            }
        }
    }

    private func pickerRowPlayersOnly(allowedValues: [Int],
                                      label: String,
                                      valueToText: ((Int) -> String)? = nil,
                                      keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack(spacing: 0) {
            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let scBinding = $game.scorecards[playerIdx]
                    let isLocked  = scBinding.wrappedValue.isLocked(col: scoreColumnIndex, key: label)
                    let binding   = valueBinding(scBinding, keyPath, scoreColumnIndex)

                    Menu {
                        Picker("Valeur", selection: binding) {
                            ForEach([-1] + allowedValues, id: \.self) { v in
                                let title = valueToText.map { $0(v) } ?? (v == -1 ? UIStrings.Common.dash : String(v))
                                Text(title).tag(v)
                            }
                        }
                    } label: {
                        Text(valueToText.map { $0(binding.wrappedValue) } ?? (binding.wrappedValue == -1 ? UIStrings.Common.dash : String(binding.wrappedValue)))
                            .font(cellFont)
                            .frame(minWidth: minCellWidth, maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.primary)
                            .padding(cellPadding)
                            .background(cellBackground(col: playerIdx, isOpen: binding.wrappedValue == -1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isLocked || !isCellEnabled(for: pid))
                    .contextMenu {
                        Button(UIStrings.Common.validate) {
                            scBinding.wrappedValue.setLocked(true, col: scoreColumnIndex, key: label)
                            try? context.save()
                        }
                        Button(UIStrings.Common.clear) { binding.wrappedValue = -1 }
                    }
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
                        .padding(cellPadding)
                        .background(cellBackground(col: playerIdx, isOpen: (text == UIStrings.Common.dash || text == "—")))
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
    private var extraYamsIsEnabled: Bool { game.enableExtraYamsBonus }

    private func yamsAlreadyScored(_ sc: Scorecard, col: Int) -> Bool {
        guard sc.yams.indices.contains(col) else { return false }
        return sc.yams[col] > 0
    }

    @ViewBuilder
    private func extraYamsRowPlayersOnly() -> some View {
        HStack(spacing: 0) {
            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let scBinding = $game.scorecards[playerIdx]
                    let awarded = scBinding.wrappedValue.extraYamsAwarded[scoreColumnIndex]
                    let eligible = yamsAlreadyScored(scBinding.wrappedValue, col: scoreColumnIndex)
                    let isActivePlayer = (game.activePlayerID == pid)

                    Group {
                        if awarded {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("+\(game.notation.extraYamsBonusValue)")
                                Spacer()
                                if isActivePlayer {
                                    Button(role: .destructive) {
                                        revokePlayerIdx = playerIdx
                                        showRevokeYams = true
                                    } label: {
                                        Label("Annuler", systemImage: "xmark.circle")
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(cellPadding)
                            .background(cellBackground(col: playerIdx, isOpen: false))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contextMenu {
                                Button("Retirer la prime", role: .destructive) {
                                    revokeExtraYams(for: playerIdx)
                                }
                            }
                        } else {
                            if eligible && isActivePlayer {
                                Button {
                                    var arr = scBinding.wrappedValue.extraYamsAwarded
                                    if scoreColumnIndex >= arr.count {
                                        arr.append(contentsOf: Array(repeating: false, count: scoreColumnIndex - arr.count + 1))
                                    }
                                    arr[scoreColumnIndex] = true
                                    scBinding.wrappedValue.extraYamsAwarded = arr
                                    scBinding.wrappedValue.setLocked(true, col: scoreColumnIndex, key: "ExtraYamsBonus")
                                    try? context.save()
                                } label: {
                                    Text("Attribuer")
                                        .frame(maxWidth: .infinity)
                                        .padding(cellPadding)
                                        .background(cellBackground(col: playerIdx, isOpen: true))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .contextMenu {
                                    Button("Conditions") {
                                        tipText = "Prime accordée uniquement si le Yams est déjà validé (≠ 0 et ≠ —)."
                                        showTip = true
                                    }
                                }
                            } else {
                                Text(UIStrings.Common.dash)
                                    .frame(maxWidth: .infinity)
                                    .padding(cellPadding)
                                    .background(cellBackground(col: playerIdx, isOpen: true))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .help("La prime n’est attribuable qu’après avoir validé la case Yams.")
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
    private func allowed(for face: Int) -> [Int] { Validators.allowedUpperValues(face: face) }

    private func valueBinding(_ sc: Binding<Scorecard>, _ keyPath: WritableKeyPath<Scorecard, [Int]>, _ col: Int) -> Binding<Int> {
        Binding<Int>(
            get: {
                let arr = sc.wrappedValue[keyPath: keyPath]
                return (col < arr.count && col >= 0) ? arr[col] : -1
            },
            set: { newVal in
                var arr = sc.wrappedValue[keyPath: keyPath]
                if col < arr.count && col >= 0 {
                    arr[col] = newVal
                    sc.wrappedValue[keyPath: keyPath] = arr
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

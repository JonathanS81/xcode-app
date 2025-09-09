import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPlayers: [Player]
    
    @Bindable var game: Game

    // ===== UI State =====
    @State private var showTip = false
    @State private var tipText = ""
    @State private var showRevokeYams = false
    @State private var revokePlayerIdx: Int? = nil
    @State private var showEndGameSheet = false
    @State private var showOrderSheet = false
    @State private var alertMessage = ""
    @State private var showAlert = false
    
    @Environment(\.scenePhase) private var scenePhase
    @State private var showCongrats = false
    @State private var endGameEntries: [EndGameCongratsView.Entry] = []


    // Index de colonne affichée (multi-colonnes plus tard)
    private var scoreColumnIndex: Int { 0 }

    // ===== Participants & Ordre =====
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

    /// Mapping index de scorecard par joueur
    private var scorecardIndexByPlayerID: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: game.scorecards.enumerated().map { ($0.element.playerID, $0.offset) })
    }

    /// IDs de colonnes à afficher : joueur actif d’abord, puis ordre de tour, puis éventuels restants
    private var displayPlayerIDs: [UUID] {
        var seen = Set<UUID>()
        var ids: [UUID] = []

        if let active = game.activePlayerID,
           game.scorecards.contains(where: { $0.playerID == active }) {
            ids.append(active); seen.insert(active)
        }
        for id in game.turnOrder where !seen.contains(id) {
            if game.scorecards.contains(where: { $0.playerID == id }) {
                ids.append(id); seen.insert(id)
            }
        }
        for sc in game.scorecards where !seen.contains(sc.playerID) {
            ids.append(sc.playerID); seen.insert(sc.playerID)
        }
        return ids
    }

    // “Au tour de …”
    private var activePlayerName: String {
        if let pid = game.activePlayerID,
           let p = allPlayers.first(where: { $0.id == pid }) {
            return p.nickname
        }
        return "—"
    }

    // === DEBUG ONLY ===
    #if DEBUG
    /// S'assure que le tableau de valeurs a au moins 'scoreColumnIndex + 1' éléments.
    private func ensureCapacity(_ arr: inout [Int], at idx: Int) {
        if idx >= arr.count {
            arr.append(contentsOf: Array(repeating: -1, count: idx - arr.count + 1))
        }
    }

    /// Écrit une valeur dans un keyPath de Scorecard, colonne courante.
    private func debugSetValue(playerIdx: Int, keyPath: WritableKeyPath<Scorecard, [Int]>, value: Int) {
        var arr = game.scorecards[playerIdx][keyPath: keyPath]
        ensureCapacity(&arr, at: scoreColumnIndex)
        arr[scoreColumnIndex] = value
        game.scorecards[playerIdx][keyPath: keyPath] = arr
    }

    /// Remplit toutes les cases requises (0) pour tous les joueurs afin de forcer "partie terminée".
    private func debugFillAllRequiredAndComplete(showNotification: Bool = false) {
        for i in game.scorecards.indices {
            // Section haute
            debugSetValue(playerIdx: i, keyPath: \.ones,   value: 0)
            debugSetValue(playerIdx: i, keyPath: \.twos,   value: 0)
            debugSetValue(playerIdx: i, keyPath: \.threes, value: 0)
            debugSetValue(playerIdx: i, keyPath: \.fours,  value: 0)
            debugSetValue(playerIdx: i, keyPath: \.fives,  value: 0)
            debugSetValue(playerIdx: i, keyPath: \.sixes,  value: 0)
            // Section milieu
            debugSetValue(playerIdx: i, keyPath: \.maxVals, value: 0)
            debugSetValue(playerIdx: i, keyPath: \.minVals, value: 0)
            // Section basse
            debugSetValue(playerIdx: i, keyPath: \.brelan, value: 0)
            if game.enableChance {
                debugSetValue(playerIdx: i, keyPath: \.chance, value: 0)
            }
            debugSetValue(playerIdx: i, keyPath: \.full,  value: 0)
            debugSetValue(playerIdx: i, keyPath: \.suite, value: 0) // 0 = barré / présent selon règle
            if game.enableSmallStraight {
                debugSetValue(playerIdx: i, keyPath: \.petiteSuite, value: 0) // 0 = barré
            }
            debugSetValue(playerIdx: i, keyPath: \.carre, value: 0)
            debugSetValue(playerIdx: i, keyPath: \.yams,  value: 0)
        }

        // Marquer la partie terminée + déclencher pop-up ou notif
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
            endGameEntries = ranking.map { EndGameCongratsView.Entry(name: $0.0, score: $0.1) }
            showCongrats = true
        }
    }
    #endif

    
    // ===== Helpers Tour par tour =====
    private func isCellEnabled(for playerID: UUID) -> Bool {
        guard game.statusOrDefault == .inProgress else { return false }
        return game.activePlayerID == playerID
    }

    /// nombre de cases (requises + optionnelles) remplies pour un joueur
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

    private func requiredFilledCount(for sc: Scorecard) -> Int {
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

    private func isGameCompletedNow() -> Bool {
        game.scorecards.allSatisfy { requiredFilledCount(for: $0) >= requiredCellsCountPerPlayer }
    }

    // ===== Actions =====
    private func onNextPlayerTapped() {
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

            // Construire le classement (nom + score)
            let ranking: [(String, Int)] = orderedPlayers
                .map { ($0.nickname, totalScore(for: $0.id)) }
                .sorted { $0.1 > $1.1 }

           
         


            // Si app inactive → notification locale. Sinon → pop-up confettis.
            if scenePhase != .active {
                NotificationManager.postEndGame(
                    winnerName: ranking.first?.0 ?? "—",
                    gameName: game.name,
                    rankings: ranking
                )
            } else {
                //endGameEntries = ranking.map { EndGameCongratsView.Entry(name: $0.0, score: $0.1) }
                endGameEntries = ranking.map { .init(name: $0.0, score: $0.1) }
                showCongrats = true
            }
        }
        try? context.save()
    }

    private func onPauseTapped() {
        game.statusOrDefault = .paused
        try? context.save()
    }

    private func revokeExtraYams(for playerIdx: Int) {
        var arr = game.scorecards[playerIdx].extraYamsAwarded
        if scoreColumnIndex < arr.count && scoreColumnIndex >= 0 {
            arr[scoreColumnIndex] = false
            game.scorecards[playerIdx].extraYamsAwarded = arr
            try? context.save()
        }
    }

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

    /// Rendre actif un joueur en cliquant son nom de colonne
    private func setActivePlayer(_ pid: UUID) {
        if let ap = game.activePlayerID, ap == pid { return }  // évite travail inutile
        game.jumpTo(playerID: pid)
        ensureTurnSnapshotInitialized()
    }

    // MARK: - Body
    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: 12) {
                // Ruban “Au tour de …” sous le titre, à gauche
                turnRibbon()
                grid()
            }
            .padding(.horizontal)
            .animation(.easeInOut(duration: 0.25), value: displayPlayerIDs)
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
                    game.setTurnOrder(ids)
                    try? context.save()
                }
            )
        }
        .sheet(isPresented: $showCongrats) {
            EndGameCongratsView(
                gameName: game.name,
                entries: endGameEntries,
                dismiss: { showCongrats = false }
            )
        }
        .onAppear {
            NotificationManager.requestAuthorizationIfNeeded()   // ← nouvelle ligne
            if game.turnOrder.isEmpty && orderedPlayers.count >= 2 { showOrderSheet = true }
            ensureTurnSnapshotInitialized()
        }
        .onChange(of: game.activePlayerID) { _ in ensureTurnSnapshotInitialized() }
        .scrollDismissesKeyboard(.interactively)
        .simultaneousGesture(TapGesture().onEnded { hideKeyboard() })
        .navigationTitle(UIStrings.Game.title)
        .toolbar {
#if DEBUG
// Menu coccinelle côté gauche pour tests fin de partie
ToolbarItem(placement: .navigationBarLeading) {
    Menu {
        Button("Debug • Terminer maintenant (popup)") {
            debugFillAllRequiredAndComplete(showNotification: false)
        }
        Button("Debug • Terminer avec notification") {
            NotificationManager.requestAuthorizationIfNeeded()
            debugFillAllRequiredAndComplete(showNotification: true)
        }
    } label: {
        Image(systemName: "ladybug.fill")
    }
}
#endif
            // Trailing : bouton “Joueur suivant” (si 1 case) + menu
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    if canShowNextButton {
                        Button("Joueur suivant") { onNextPlayerTapped() }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                    }
                    Menu {
                        Button(game.statusOrDefault == .paused ? UIStrings.Game.resume : UIStrings.Game.pause) {
                            game.statusOrDefault = (game.statusOrDefault == .paused) ? .inProgress : .paused
                            try? context.save()
                        }
                        Button(UIStrings.Game.finish) {
                            game.statusOrDefault = .completed
                            try? context.save()
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                }
            }

            // Bouton Terminé (clavier)
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

    // MARK: - Ruban “Au tour de …”
    @ViewBuilder
    private func turnRibbon() -> some View {
        HStack {
            Text("Au tour de \(activePlayerName)")
                .font(.headline)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.secondary.opacity(0.12))
                .clipShape(Capsule())
            Spacer()
        }
        .padding(.top, 4)
    }

    // MARK: - Header colonnes (noms au-dessus des colonnes)
    @ViewBuilder
    private func columnsHeader() -> some View {
        HStack(spacing: 0) {
            // espace réservé pour les libellés de lignes (110 de large)
            Text("").frame(width: 110, alignment: .leading)

            ForEach(displayPlayerIDs, id: \.self) { pid in
                let name = allPlayers.first(where: { $0.id == pid })?.nickname ?? "—"
                Text(name)
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background((game.activePlayerID == pid) ? Color.yellow.opacity(0.28) : Color.gray.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 2)
                    .contentShape(Rectangle())               // ← zone cliquable
                    .onTapGesture { setActivePlayer(pid) }    // ← activer le joueur
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Grid
    @ViewBuilder private func grid() -> some View {
        VStack(spacing: 8) {
            columnsHeader() // étiquettes au-dessus des colonnes (cliquables)
            sectionUpper()
            sectionMiddle()
            sectionBottom()
            totalsRow(label: UIStrings.Game.totalAll, valueForPlayer: totalAllText)
                .padding(.top, 6)
        }
    }

    // helpers
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
    
    private func yamsAlreadyScored(_ sc: Scorecard, col: Int) -> Bool {
        guard sc.yams.indices.contains(col) else { return false }
        return sc.yams[col] > 0
    }

    private var extraYamsIsEnabled: Bool {
        game.enableExtraYamsBonus && game.notation.extraYamsBonusValue > 0
    }

    // MARK: - Rows

    private func pickerRow(label: String, face: Int, keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let scBinding = $game.scorecards[playerIdx]
                    let isLocked  = scBinding.wrappedValue.isLocked(col: scoreColumnIndex, key: label)
                    let binding   = valueBinding(scBinding, keyPath, scoreColumnIndex)

                    Menu {
                        Picker("Valeur", selection: binding) {
                            ForEach([-1] + allowed(for: face), id: \.self) { v in
                                Text(v == -1 ? UIStrings.Common.dash : String(v)).tag(v)
                            }
                        }
                    } label: {
                        Text(binding.wrappedValue == -1 ? UIStrings.Common.dash : String(binding.wrappedValue))
                            .frame(maxWidth: .infinity)
                            .padding(8)
                            .background(cellBackground(col: playerIdx, isOpen: binding.wrappedValue == -1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .disabled(isLocked || !isCellEnabled(for: pid))
                    .contextMenu {
                        Button(UIStrings.Common.validate) {
                            scBinding.wrappedValue.setLocked(true, col: scoreColumnIndex, key: label)
                            try? context.save()
                        }
                        Button(UIStrings.Common.clear) {
                            var arr = scBinding.wrappedValue[keyPath: keyPath]
                            if scoreColumnIndex < arr.count && scoreColumnIndex >= 0 {
                                arr[scoreColumnIndex] = -1
                                scBinding.wrappedValue[keyPath: keyPath] = arr
                            }
                        }
                    }
                }
            }
        }
    }

    private func numericRow(label: String,
                            keyPath: WritableKeyPath<Scorecard, [Int]>,
                            figure: FigureKind? = nil,
                            validator: ((Int?) -> Int)? = nil,
                            displayMap: ((Int) -> String)? = nil,
                            valueFont: Font? = nil,
                            effectiveFont: Font? = nil) -> some View {
        HStack {
            if let fig = figure { labelWithTip(label, figure: fig) }
            else { Text(label).frame(width: 110, alignment: .leading) }

            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let scBinding = $game.scorecards[playerIdx]
                    let isLocked  = scBinding.wrappedValue.isLocked(col: scoreColumnIndex, key: label)
                    let binding   = valueBinding(scBinding, keyPath, scoreColumnIndex)
                    let isOpen    = (binding.wrappedValue == -1)

                    NumericCell(value: binding,
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
                                valueFont: valueFont,
                                effectiveFont: effectiveFont)
                    .padding(8)
                    .frame(maxWidth: .infinity)
                    .background(cellBackground(col: playerIdx, isOpen: isOpen))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contextMenu {
                        Button(UIStrings.Common.validate) {
                            scBinding.wrappedValue.setLocked(true, col: scoreColumnIndex, key: label)
                            try? context.save()
                        }
                        Button(UIStrings.Common.clear) { binding.wrappedValue = -1 }
                    }
                    .disabled(isLocked || !isCellEnabled(for: pid))
                }
            }
        }
    }

    private func pickerRowCustom(label: String,
                                 allowedValues: [Int],
                                 keyPath: WritableKeyPath<Scorecard, [Int]>,
                                 figure: FigureKind? = nil,
                                 valueToText: ((Int) -> String)? = nil) -> some View {
        HStack {
            if let fig = figure { labelWithTip(label, figure: fig) }
            else { Text(label).frame(width: 110, alignment: .leading) }

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
                            .frame(maxWidth: .infinity)
                            .padding(8)
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
                }
            }
        }
    }
    
    @ViewBuilder
    private func extraYamsRow() -> some View {
        if extraYamsIsEnabled {
            HStack {
                Text("Prime Yams supplémentaire").frame(width: 110, alignment: .leading)

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
                                .padding(8)
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
                                            .padding(8)
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
                                        .padding(8)
                                        .background(cellBackground(col: playerIdx, isOpen: true))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .help("La prime n’est attribuable qu’après avoir validé la case Yams.")
                                }
                            }
                        }
                        .disabled(!isActivePlayer)
                    }
                }
            }
        } else {
            EmptyView()
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

    // MARK: - Sections
    private func sectionUpper() -> some View {
        VStack(spacing: 8) {
            HStack { Text(UIStrings.Game.upperSection).font(.headline); Spacer() }
            pickerRow(label: UIStrings.Game.ones,   face: 1, keyPath: \Scorecard.ones)
            pickerRow(label: UIStrings.Game.twos,   face: 2, keyPath: \Scorecard.twos)
            pickerRow(label: UIStrings.Game.threes, face: 3, keyPath: \Scorecard.threes)
            pickerRow(label: UIStrings.Game.fours,  face: 4, keyPath: \Scorecard.fours)
            pickerRow(label: UIStrings.Game.fives,  face: 5, keyPath: \Scorecard.fives)
            pickerRow(label: UIStrings.Game.sixes,  face: 6, keyPath: \Scorecard.sixes)
            totalsRow(label: UIStrings.Game.total1, valueForPlayer: total1Text)
        }
    }

    private func sectionMiddle() -> some View {
        VStack(spacing: 8) {
            HStack { Text(UIStrings.Game.middleSection).font(.headline); Spacer() }
            let strict = (game.notation.middleMode == .bonusGate)

            numericRow(label: UIStrings.Game.max,
                       keyPath: \Scorecard.maxVals,
                       validator: { newVal in
                           let idx = activeScorecardIndex ?? 0
                           let currentMin = game.scorecards[idx].minVals[scoreColumnIndex]
                           return ValidationEngine.sanitizeMiddleMax(newVal,
                                                                     currentMin: (currentMin >= 0 ? currentMin : nil),
                                                                     strictGreater: strict)
                       })

            numericRow(label: UIStrings.Game.min,
                       keyPath: \Scorecard.minVals,
                       validator: { newVal in
                           let idx = activeScorecardIndex ?? 0
                           let currentMax = game.scorecards[idx].maxVals[scoreColumnIndex]
                           return ValidationEngine.sanitizeMiddleMin(newVal,
                                                                     currentMax: (currentMax >= 0 ? currentMax : nil),
                                                                     strictGreater: strict)
                       })
            totalsRow(label: UIStrings.Game.total2, valueForPlayer: total2Text)
        }
    }

    private func sectionBottom() -> some View {
        VStack(spacing: 8) {
            HStack { Text(UIStrings.Game.bottomSection).font(.headline); Spacer() }

            numericRow(label: UIStrings.Game.brelan,
                       keyPath: \Scorecard.brelan,
                       figure: .brelan,
                       validator: { newVal in
                           ValidationEngine.sanitizeBottom(newVal, rule: game.notation.ruleBrelan)
                       },
                       displayMap: { v in
                           ValidationEngine.displayForBottom(stored: v, rule: game.notation.ruleBrelan)
                       })

            if game.enableChance {
                numericRow(label: UIStrings.Game.chance,
                           keyPath: \Scorecard.chance,
                           figure: .chance,
                           validator: { newVal in
                               ValidationEngine.sanitizeBottom(newVal, rule: game.notation.ruleChance)
                           },
                           displayMap: { v in
                               ValidationEngine.displayForBottom(stored: v, rule: game.notation.ruleChance)
                           })
            }

            numericRow(label: UIStrings.Game.full,
                       keyPath: \Scorecard.full,
                       figure: .full,
                       validator: { newVal in
                           ValidationEngine.sanitizeBottom(newVal, rule: game.notation.ruleFull)
                       },
                       displayMap: { v in
                           ValidationEngine.displayForBottom(stored: v, rule: game.notation.ruleFull)
                       })

            pickerRowCustom(label: UIStrings.Game.suite,
                            allowedValues: [0, 15, 20],
                            keyPath: \Scorecard.suite,
                            figure: .suiteBig,
                            valueToText: displaySuiteValue)

            if game.enableSmallStraight {
                pickerRowCustom(label: UIStrings.Game.petiteSuite,
                                allowedValues: [0, 1],
                                keyPath: \Scorecard.petiteSuite,
                                figure: .petiteSuite,
                                valueToText: displayPetiteSuiteValue)
            }

            numericRow(label: UIStrings.Game.carre,
                       keyPath: \Scorecard.carre,
                       figure: .carre,
                       validator: { newVal in
                           ValidationEngine.sanitizeBottom(newVal, rule: game.notation.ruleCarre)
                       },
                       displayMap: { v in
                           ValidationEngine.displayForBottom(stored: v, rule: game.notation.ruleCarre)
                       })

            numericRow(label: UIStrings.Game.yams,
                       keyPath: \Scorecard.yams,
                       figure: .yams,
                       validator: { newVal in sanitizeYamsForSnapshot(newVal) },
                       displayMap: { v in
                           ValidationEngine.displayForBottom(stored: v, rule: game.notation.ruleYams)
                       },
                       valueFont: .caption,
                       effectiveFont: .headline)

            extraYamsRow()
            totalsRow(label: UIStrings.Game.total3, valueForPlayer: total3Text)
        }
    }

    // MARK: - Totals helpers
    private func middleCanCompute(playerIdx: Int) -> Bool {
        let sc = game.scorecards[playerIdx]
        switch game.notation.middleMode {
        case .multiplier:
            return sc.maxVals[scoreColumnIndex] >= 0
                && sc.minVals[scoreColumnIndex] >= 0
                && sc.ones[scoreColumnIndex]    >= 0
        case .bonusGate:
            return sc.maxVals[scoreColumnIndex] >= 0
                && sc.minVals[scoreColumnIndex] >= 0
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
        let upper = StatsEngine.upperTotal(sc: sc, game: game, col: scoreColumnIndex)
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
    private func totalsRow(label: String, valueForPlayer: @escaping (_ playerIdx: Int) -> String) -> some View {
        HStack {
            Text(label).font(.headline).frame(width: 110, alignment: .leading)
            ForEach(displayPlayerIDs, id: \.self) { pid in
                if let playerIdx = scorecardIndexByPlayerID[pid] {
                    let text = valueForPlayer(playerIdx)
                    Text(text)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(cellBackground(col: playerIdx, isOpen: (text == UIStrings.Common.dash || text == "—")))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - UI bits
    @ViewBuilder
    private func labelWithTip(_ title: String, figure: FigureKind? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if let fig = figure {
                Button {
                    tipText = StatsEngine.figureTooltip(notation: game.notation, figure: fig)
                    showTip = true
                } label: { Image(systemName: "questionmark.circle") }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 110, alignment: .leading)
    }

    private func displaySuiteValue(_ v: Int) -> String {
        switch v {
        case -1: return UIStrings.Common.dash
        case 0:  return UIStrings.Game.barred0
        case 15: return UIStrings.Game.suite15
        case 20: return UIStrings.Game.suite20
        default: return String(v)
        }
    }

    private func displayPetiteSuiteValue(_ v: Int) -> String {
        switch v {
        case -1: return UIStrings.Common.dash
        case 0:  return UIStrings.Game.barred0
        case 1:  return UIStrings.Game.petiteLbl
        default: return String(v)
        }
    }

    // MARK: - NumericCell
    private struct NumericCell: View {
        @Binding var value: Int
        let isLocked: Bool
        let isActive: Bool
        let validator: ((Int?) -> Int)?
        let displayMap: ((Int) -> String)?
        let valueFont: Font?
        let effectiveFont: Font?

        @State private var text: String = ""
        @FocusState private var isFocused: Bool

        var body: some View {
            ZStack(alignment: .trailing) {
                TextField(UIStrings.Common.dash, text: $text)
                    .keyboardType(.numberPad)
                    .submitLabel(.done)
                    .onSubmit { commit() }
                    .font(valueFont)
                    .focused($isFocused)
                    .onAppear { text = (value >= 0) ? String(value) : "" }
                    .onChange(of: value) { _, newVal in
                        if !isFocused {
                            let t = (newVal >= 0) ? String(newVal) : ""
                            if t != text { text = t }
                        }
                    }
                    .onChange(of: text) { _, newText in
                        let filtered = newText.filter { $0.isNumber }
                        if filtered != newText { text = filtered; return }
                        let intVal = Int(filtered)
                        if isFocused {
                            let soft = intVal.map { max(0, min(99, $0)) }
                            if soft != value { value = soft ?? -1 }
                        } else {
                            applyValidation(intVal)
                        }
                    }
                    .onChange(of: isFocused) { was, now in
                        if was && !now { commit() }
                    }

                if let map = displayMap, value >= 0 {
                    let eff = map(value)
                    if eff != String(value) {
                        Text(eff)
                            .font(effectiveFont ?? .caption2)
                            .padding(.trailing, 8)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.06))
                            .clipShape(Capsule())
                    }
                }
            }
            .disabled(isLocked || !isActive)
        }

        private func commit() {
            isFocused = false
            let intVal = Int(text)
            applyValidation(intVal)
            text = (value >= 0) ? String(value) : ""
        }

        private func applyValidation(_ intVal: Int?) {
            let sanitized = validator?(intVal) ?? (intVal ?? -1)
            if sanitized != value { value = sanitized }
        }
    }
}


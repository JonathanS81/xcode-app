import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var allPlayers: [Player]

    @State private var activeCol: Int = 0            // index du joueur sélectionné
    @State private var showTip = false
    @State private var tipText = ""

    @Bindable var game: Game

    // Unique colonne de score dans chaque Scorecard (si tu ajoutes plusieurs colonnes plus tard, remplace par un @State)
    private var scoreColumnIndex: Int { 0 }

    // MARK: - Body
    var body: some View {
        let players = game.scorecards.compactMap { sc in
            allPlayers.first(where: { $0.id == sc.playerID }).map { (player: $0, sc: sc) }
        }

        ScrollView(.vertical) {
            VStack(spacing: 12) {
                header(players: players.map { $0.player })
                grid()
            }
            .padding(.horizontal)
        }
        .navigationTitle(UIStrings.Game.title)
        .toolbar {
            Menu {
                
                Button(game.status == .paused ? UIStrings.Game.resume : UIStrings.Game.pause) {
                    game.status = game.status == .paused ? .inProgress : .paused
                    try? context.save()
                }
                Button(UIStrings.Game.finish) {
                    game.status = .completed
                    try? context.save()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        .alert(UIStrings.Game.tooltipTitle, isPresented: $showTip, actions: {
            Button(UIStrings.Common.ok, role: .cancel) { }
        }, message: { Text(tipText) })
    }

    // MARK: - Header

    @ViewBuilder
    private func header(players: [Player]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 16) {
                ForEach(Array(players.enumerated()), id: \.offset) { (idx, p) in
                    Text(p.nickname)
                        .padding(10)
                        .background(idx == activeCol ? Color.green.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .onTapGesture { activeCol = idx }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Tooltip label

    @ViewBuilder
    private func labelWithTip(_ title: String, figure: FigureKind? = nil) -> some View {
        HStack(spacing: 6) {
            Text(title)
            if let fig = figure {
                Button {
                    tipText = StatsEngine.figureTooltip(notation: game.notation, figure: fig)
                    showTip = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 110, alignment: .leading)
    }

    // MARK: - Grid

    @ViewBuilder
    private func grid() -> some View {
        VStack(spacing: 8) {
            sectionUpper()
            sectionMiddle()
            sectionBottom()
            // Total général
            totalsRow(label: UIStrings.Game.totalAll, valueForPlayer: totalAllText)
                .padding(.top, 6)
        }
    }

    private func allowed(for face: Int) -> [Int] {
        Validators.allowedUpperValues(face: face)
    }

    private func cellBackground(col: Int, isOpen: Bool) -> some View {
        Group {
            if col == activeCol {
                (isOpen ? Color.blue.opacity(0.12) : Color.green.opacity(0.12))
            } else {
                Color.gray.opacity(0.08)
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        HStack { Text(title).font(.headline); Spacer() }
            .padding(.top, 12)
    }

    // Helper pour binder un élément d’un tableau [Int] stocké dans Scorecard à l’index de colonne
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

    // MARK: - Rows (Section haute / milieu / basse)

    // Lignes de la section haute (menu + picker des valeurs autorisées)
    private func pickerRow(label: String, face: Int, keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            ForEach(game.scorecards.indices, id: \.self) { playerIdx in
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
                .disabled(isLocked || playerIdx != activeCol)
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

    // Entrée numérique (section milieu ou certaines figures), avec tooltip optionnel
    private func numericRow(label: String,
                            keyPath: WritableKeyPath<Scorecard, [Int]>,
                            figure: FigureKind? = nil) -> some View {
        HStack {
            if let fig = figure {
                labelWithTip(label, figure: fig)
            } else {
                Text(label).frame(width: 110, alignment: .leading)
            }
            ForEach(game.scorecards.indices, id: \.self) { playerIdx in
                let scBinding = $game.scorecards[playerIdx]
                let isLocked  = scBinding.wrappedValue.isLocked(col: scoreColumnIndex, key: label)
                let binding   = valueBinding(scBinding, keyPath, scoreColumnIndex)

                TextField(UIStrings.Common.dash, value: Binding(
                    get: { binding.wrappedValue == -1 ? nil : binding.wrappedValue },
                    set: { newVal in binding.wrappedValue = newVal ?? -1 }
                ), format: .number)
                .keyboardType(.numberPad)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(cellBackground(col: playerIdx, isOpen: binding.wrappedValue == -1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(isLocked || playerIdx != activeCol)
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

    // Sélecteurs personnalisés (Suite / Petite suite) avec mapping d’affichage
    private func pickerRowCustom(label: String,
                                 allowedValues: [Int],
                                 keyPath: WritableKeyPath<Scorecard, [Int]>,
                                 figure: FigureKind? = nil,
                                 valueToText: ((Int) -> String)? = nil) -> some View {
        HStack {
            if let fig = figure {
                labelWithTip(label, figure: fig)
            } else {
                Text(label).frame(width: 110, alignment: .leading)
            }
            ForEach(game.scorecards.indices, id: \.self) { playerIdx in
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
                .disabled(isLocked || playerIdx != activeCol)
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

    // MARK: - Sections

    private func sectionUpper() -> some View {
        VStack(spacing: 8) {
            sectionTitle(UIStrings.Game.upperSection)
            pickerRow(label: UIStrings.Game.ones,   face: 1, keyPath: \Scorecard.ones)
            pickerRow(label: UIStrings.Game.twos,   face: 2, keyPath: \Scorecard.twos)
            pickerRow(label: UIStrings.Game.threes, face: 3, keyPath: \Scorecard.threes)
            pickerRow(label: UIStrings.Game.fours,  face: 4, keyPath: \Scorecard.fours)
            pickerRow(label: UIStrings.Game.fives,  face: 5, keyPath: \Scorecard.fives)
            pickerRow(label: UIStrings.Game.sixes,  face: 6, keyPath: \Scorecard.sixes)

            // Total 1 (haut)
            totalsRow(label: UIStrings.Game.total1, valueForPlayer: total1Text)
        }
    }

    private func sectionMiddle() -> some View {
        VStack(spacing: 8) {
            sectionTitle(UIStrings.Game.middleSection)
            numericRow(label: UIStrings.Game.max, keyPath: \Scorecard.maxVals)
            numericRow(label: UIStrings.Game.min, keyPath: \Scorecard.minVals)

            // Total 2 (milieu)
            totalsRow(label: UIStrings.Game.total2, valueForPlayer: total2Text)
        }
    }

    private func sectionBottom() -> some View {
        VStack(spacing: 8) {
            sectionTitle(UIStrings.Game.bottomSection)
            numericRow(label: UIStrings.Game.brelan, keyPath: \Scorecard.brelan, figure: .brelan)
            
            if game.enableChance {
                numericRow(label: UIStrings.Game.chance, keyPath: \Scorecard.chance, figure: .chance)
            }
            
            numericRow(label: UIStrings.Game.full,   keyPath: \Scorecard.full,   figure: .full)

            // Suite (grande) : valeurs -1,0,15,20 (— / barré / 1–5 / 2–6)
            pickerRowCustom(label: UIStrings.Game.suite,
                            allowedValues: [0, 15, 20],
                            keyPath: \Scorecard.suite,
                            figure: .suiteBig,
                            valueToText: displaySuiteValue)

            // Petite suite (si activée) : -1,0,1 (— / barré / présente)
            if game.enableSmallStraight {
                pickerRowCustom(label: UIStrings.Game.petiteSuite,
                                allowedValues: [0, 1],
                                keyPath: \Scorecard.petiteSuite,
                                figure: .petiteSuite,
                                valueToText: displayPetiteSuiteValue)
            }

            numericRow(label: UIStrings.Game.carre,  keyPath: \Scorecard.carre, figure: .carre)
            numericRow(label: UIStrings.Game.yams,   keyPath: \Scorecard.yams,  figure: .yams)

            // Total 3 (bas)
            totalsRow(label: UIStrings.Game.total3, valueForPlayer: total3Text)
        }
    }

    // MARK: - Totals helpers

    private func isDash(_ s: String) -> Bool {
        s == UIStrings.Common.dash || s == "—"
    }

    // Section milieu : peut-on calculer ?
    // .multiplier -> besoin de Max, Min et As
    // .bonusGate  -> besoin de Max et Min
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

    private func total1Text(playerIdx: Int) -> String {
        let sc = game.scorecards[playerIdx]
        return String(StatsEngine.upperTotal(sc: sc, game: game, col: scoreColumnIndex))
    }

    private func total2Text(playerIdx: Int) -> String {
        guard middleCanCompute(playerIdx: playerIdx) else { return UIStrings.Common.dash }
        let sc = game.scorecards[playerIdx]
        return String(StatsEngine.middleTotal(sc: sc, game: game, col: scoreColumnIndex))
    }

    private func total3Text(playerIdx: Int) -> String {
        let sc = game.scorecards[playerIdx]
        return String(StatsEngine.bottomTotal(sc: sc, game: game, col: scoreColumnIndex))
    }

    private func totalAllText(playerIdx: Int) -> String {
        guard middleCanCompute(playerIdx: playerIdx) else { return UIStrings.Common.dash }
        let sc = game.scorecards[playerIdx]
        return String(StatsEngine.total(sc: sc, game: game, col: scoreColumnIndex))
    }

    // Ligne de totaux homogène
    @ViewBuilder
    private func totalsRow(label: String, valueForPlayer: @escaping (_ playerIdx: Int) -> String) -> some View {
        HStack {
            Text(label).font(.headline).frame(width: 110, alignment: .leading)
            ForEach(game.scorecards.indices, id: \.self) { playerIdx in
                let text = valueForPlayer(playerIdx)
                Text(text)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(cellBackground(col: playerIdx, isOpen: isDash(text)))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    // MARK: - Affichage suite

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
}


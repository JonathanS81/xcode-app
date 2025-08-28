import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var allPlayers: [Player]
    @State private var activeCol: Int = 0
    @State private var showTip = false
    @State private var tipText = ""
    @Bindable var game: Game
    
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
                Button(UIStrings.Game.finish)  {
                    game.status = .completed
                    try? context.save()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
        
        .alert(UIStrings.Game.tooltipTitle, isPresented: $showTip, actions: {
            Button(UIStrings.Common.ok, role: .cancel) { }
        }, message: {
            Text(tipText)
        })
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
            }.padding(.vertical, 8)
        }
    }
    
    //TOOLTIP
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
    
    // Helper to bind one score value inside a [Int] stored on Scorecard
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
    
    // MARK: - Rows
    
    private func pickerRow(label: String, face: Int, keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            ForEach(game.scorecards.indices, id: \.self) { col in
                let scBinding = $game.scorecards[col]
                let isLocked = scBinding.wrappedValue.isLocked(col: col, key: label)
                let binding = valueBinding(scBinding, keyPath, col)
                Menu {
                    Picker("Valeur", selection: binding) {
                        ForEach([-1] + allowed(for: face), id: \.self) { v in
                            Text(v == -1 ? "—" : String(v)).tag(v)
                        }
                    }
                } label: {
                    Text(binding.wrappedValue == -1 ? "—" : String(binding.wrappedValue))
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(cellBackground(col: col, isOpen: binding.wrappedValue == -1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isLocked || col != activeCol)
                .contextMenu {
                    Button(UIStrings.Common.validate) {
                        scBinding.wrappedValue.setLocked(true, col: col, key: label)
                        try? context.save()
                    }
                    Button(UIStrings.Common.delete) {
                        var arr = scBinding.wrappedValue[keyPath: keyPath]
                        if col < arr.count && col >= 0 {
                            arr[col] = -1
                            scBinding.wrappedValue[keyPath: keyPath] = arr
                        }
                    }
                }
            }
        }
    }
    
    private func numericRow(label: String,
                            keyPath: WritableKeyPath<Scorecard, [Int]>,
                            figure: FigureKind? = nil) -> some View {
        HStack {
            if let fig = figure {
                labelWithTip(label, figure: fig)   // ← affiche le "?" si figure
            } else {
                Text(label).frame(width: 110, alignment: .leading)
            }
            
            ForEach(game.scorecards.indices, id: \.self) { col in
                let scBinding = $game.scorecards[col]
                let isLocked = scBinding.wrappedValue.isLocked(col: col, key: label)
                let binding = valueBinding(scBinding, keyPath, col)
                TextField("—", value: Binding(
                    get: { binding.wrappedValue == -1 ? nil : binding.wrappedValue },
                    set: { newVal in binding.wrappedValue = newVal ?? -1 }
                ), format: .number)
                .keyboardType(.numberPad)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(cellBackground(col: col, isOpen: binding.wrappedValue == -1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(isLocked || col != activeCol)
                .contextMenu {
                    Button(UIStrings.Common.validate) {
                        scBinding.wrappedValue.setLocked(true, col: col, key: label)
                        try? context.save()
                    }
                    Button(UIStrings.Common.delete) { binding.wrappedValue = -1 }
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
            if let fig = figure {
                labelWithTip(label, figure: fig)   // ← “?”
            } else {
                Text(label).frame(width: 110, alignment: .leading)
            }
            
            ForEach(game.scorecards.indices, id: \.self) { col in
                let scBinding = $game.scorecards[col]
                let isLocked = scBinding.wrappedValue.isLocked(col: col, key: label)
                let binding = valueBinding(scBinding, keyPath, col)
                
                Menu {
                    Picker("Valeur", selection: binding) {
                        ForEach([-1] + allowedValues, id: \.self) { v in
                            let title: String = {
                                if let map = valueToText { return map(v) }
                                return v == -1 ? "—" : String(v)
                            }()
                            Text(title).tag(v)
                        }
                    }
                } label: {
                    Text({
                        if let map = valueToText { return map(binding.wrappedValue) }
                        return binding.wrappedValue == -1 ? "—" : String(binding.wrappedValue)
                    }())
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(cellBackground(col: col, isOpen: binding.wrappedValue == -1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(isLocked || col != activeCol)
                .contextMenu {
                    Button(UIStrings.Common.validate) {
                        scBinding.wrappedValue.setLocked(true, col: col, key: label)
                        try? context.save()
                    }
                    Button(UIStrings.Common.clear)  { binding.wrappedValue = -1 }
                }
            }
        }
    }
    
    
    
    
    
    // MARK: - Sections
    
    private func sectionUpper() -> some View {
        VStack(spacing: 8) {
            sectionTitle(UIStrings.Game.upperSection)
            pickerRow(label: UIStrings.Game.ones,   face: 1, keyPath: \.ones)
            pickerRow(label: UIStrings.Game.twos,   face: 2, keyPath: \.twos)
            pickerRow(label: UIStrings.Game.threes, face: 3, keyPath: \.threes)
            pickerRow(label: UIStrings.Game.fours,  face: 4, keyPath: \.fours)
            pickerRow(label: UIStrings.Game.fives,  face: 5, keyPath: \.fives)
            pickerRow(label: UIStrings.Game.sixes,  face: 6, keyPath: \.sixes)
        }
    }
    
    private func sectionMiddle() -> some View {
        VStack(spacing: 8) {
            sectionTitle(UIStrings.Game.middleSection)
            numericRow(label: UIStrings.Game.max, keyPath: \.maxVals)
            numericRow(label: UIStrings.Game.min, keyPath: \.minVals)
        }
    }
    
    private func sectionBottom() -> some View {
        VStack(spacing: 8) {
            sectionTitle(UIStrings.Game.bottomSection)
            numericRow(label: UIStrings.Game.brelan, keyPath: \.brelan, figure: .brelan)
            numericRow(label: UIStrings.Game.chance, keyPath: \.chance, figure: .chance)
            numericRow(label: UIStrings.Game.full,   keyPath: \.full,   figure: .full)
            
            // ← AJOUT DES SUITES :
            pickerRowCustom(label: UIStrings.Game.suite,
                            allowedValues: [0, 15, 20],
                            keyPath: \Scorecard.suite,
                            figure: .suiteBig,
                            valueToText: displaySuiteValue)

            if game.enableSmallStraight {
                pickerRowCustom(label: UIStrings.Game.petiteSuite,
                                allowedValues: [0, 1], // 0=barré, 1=présente (score via notation)
                                keyPath: \Scorecard.petiteSuite,
                                figure: .petiteSuite,
                                valueToText: displayPetiteSuiteValue)
            }
            
            numericRow(label: UIStrings.Game.carre,  keyPath: \.carre,  figure: .carre)
            numericRow(label: UIStrings.Game.yams,   keyPath: \.yams,   figure: .yams)
            
            
        }
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
    
}

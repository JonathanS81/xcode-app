import SwiftUI
import SwiftData

struct GameDetailView: View {
    @Environment(\.modelContext) private var context
    @Query private var allPlayers: [Player]
    @State private var activeCol: Int = 0

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
        .navigationTitle("Feuille de score")
        .toolbar {
            Menu {
                Button(game.status == .paused ? "Reprendre" : "Pause") {
                    game.status = game.status == .paused ? .inProgress : .paused
                    try? context.save()
                }
                Button("Terminer") {
                    game.status = .completed
                    try? context.save()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        }
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
                    Button("Valider ✅") {
                        scBinding.wrappedValue.setLocked(true, col: col, key: label)
                        try? context.save()
                    }
                    Button("Effacer ❌") {
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

    private func numericRow(label: String, keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
        HStack {
            Text(label).frame(width: 110, alignment: .leading)
            ForEach(game.scorecards.indices, id: \.self) { col in
                let scBinding = $game.scorecards[col]
                let isLocked = scBinding.wrappedValue.isLocked(col: col, key: label)
                let binding = valueBinding(scBinding, keyPath, col)
                TextField("—", value: Binding(
                    get: { binding.wrappedValue == -1 ? nil : binding.wrappedValue },
                    set: { newVal in
                        binding.wrappedValue = newVal ?? -1
                    }
                ), format: .number)
                .keyboardType(.numberPad)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(cellBackground(col: col, isOpen: binding.wrappedValue == -1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .disabled(isLocked || col != activeCol)
                .contextMenu {
                    Button("Valider ✅") {
                        scBinding.wrappedValue.setLocked(true, col: col, key: label)
                        try? context.save()
                    }
                    Button("Effacer ❌") {
                        binding.wrappedValue = -1
                    }
                }
            }
        }
    }
    
    
    private func pickerRowCustom(label: String,
                                     allowedValues: [Int],
                                     keyPath: WritableKeyPath<Scorecard, [Int]>) -> some View {
            HStack {
                Text(label).frame(width: 110, alignment: .leading)
                ForEach(game.scorecards.indices, id: \.self) { col in
                    let scBinding = $game.scorecards[col]
                    let isLocked = scBinding.wrappedValue.isLocked(col: col, key: label)
                    let binding = valueBinding(scBinding, keyPath, col)
                    Menu {
                        Picker("Valeur", selection: binding) {
                            ForEach([-1] + allowedValues, id: \.self) { v in
                                switch v {
                                case -1: Text("—").tag(v)
                                case 0:  Text("0").tag(v)
                                case 15: Text("1-5").tag(v)
                                case 20: Text("2–6").tag(v)
                                default: Text(String(v)).tag(v)
                                }
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
                        Button("Valider ✅") {
                            scBinding.wrappedValue.setLocked(true, col: col, key: label)
                            try? context.save()
                        }
                        Button("Effacer ❌") { binding.wrappedValue = -1 }
                    }
                }
            }
        }
   
    
    

    // MARK: - Sections

    private func sectionUpper() -> some View {
        VStack(spacing: 8) {
            sectionTitle("Section haute")
            pickerRow(label: "As (1)", face: 1, keyPath: \Scorecard.ones)
            pickerRow(label: "Deux (2)", face: 2, keyPath: \Scorecard.twos)
            pickerRow(label: "Trois (3)", face: 3, keyPath: \Scorecard.threes)
            pickerRow(label: "Quatre (4)", face: 4, keyPath: \Scorecard.fours)
            pickerRow(label: "Cinq (5)", face: 5, keyPath: \Scorecard.fives)
            pickerRow(label: "Six (6)", face: 6, keyPath: \Scorecard.sixes)
        }
    }

    private func sectionMiddle() -> some View {
        VStack(spacing: 8) {
            sectionTitle("Section milieu")
            numericRow(label: "Max", keyPath: \Scorecard.maxVals)
            numericRow(label: "Min", keyPath: \Scorecard.minVals)
        }
    }

    private func sectionBottom() -> some View {
        VStack(spacing: 8) {
            sectionTitle("Section basse")
            numericRow(label: "Brelan", keyPath: \Scorecard.brelan)
            numericRow(label: "Chance", keyPath: \Scorecard.chance)
            numericRow(label: "Full", keyPath: \Scorecard.full)
            // ← AJOUT DES SUITES :
            pickerRowCustom(label: "Suite",
                            allowedValues: [0, 15, 20],
                            keyPath: \Scorecard.suite)

            if game.enableSmallStraight {
                pickerRowCustom(label: "Petite suite",
                                allowedValues: [0, game.smallStraightScore],
                                keyPath: \Scorecard.petiteSuite)
            }
            numericRow(label: "Carré", keyPath: \Scorecard.carre)
            numericRow(label: "Yams", keyPath: \Scorecard.yams)
            

        }
    }
}

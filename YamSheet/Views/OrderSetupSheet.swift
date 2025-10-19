//
//  OrderSetupSheet.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//

import SwiftUI

struct OrderSetupSheet<PlayerType: Identifiable>: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isEditing: Bool = false
    let players: [PlayerType]
    let idFor: (PlayerType) -> UUID
    let nameFor: (PlayerType) -> String
    let onConfirm: ([UUID]) -> Void

    @State private var order: [PlayerType]

    init(players: [PlayerType],
         idFor: @escaping (PlayerType) -> UUID,
         nameFor: @escaping (PlayerType) -> String,
         onConfirm: @escaping ([UUID]) -> Void)
    {
        self.players = players
        self.idFor = idFor
        self.nameFor = nameFor
        self.onConfirm = onConfirm
        _order = State(initialValue: players)
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(order) { p in
                    HStack {
                        if let colorPlayer = (p as? Player)?.color {
                            Circle()
                                .fill(colorPlayer)
                                .frame(width: 20, height: 20)
                        }
                        Text(nameFor(p))
                            .font(.body)
                            .padding(.leading, 4)
                    }
                }
                .onMove { from, to in
                    order.move(fromOffsets: from, toOffset: to)
                }
            }
            .environment(\.editMode, Binding(get: { isEditing ? .active : .inactive }, set: { newValue in isEditing = (newValue == .active) }))
            .navigationTitle("Ordre des joueurs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Mélanger") { order.shuffle() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Valider") {
                        onConfirm(order.map(idFor))
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    HStack {
                        Spacer()
                        Button(isEditing ? "Terminer" : "Modifier") {
                            withAnimation(.easeInOut) {
                                isEditing.toggle()
                            }
                        }
                        .font(.headline)
                        Spacer()
                    }
                }
            }
        }
    }
}

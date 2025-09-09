
//
//  OrderSetupSheet.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//

import SwiftUI

struct OrderSetupSheet<PlayerType: Identifiable>: View {
    @Environment(\.dismiss) private var dismiss
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
                    Text(nameFor(p))
                }
                .onMove { from, to in
                    order.move(fromOffsets: from, toOffset: to)
                }
            }
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
                    EditButton()
                }
            }
        }
    }
}

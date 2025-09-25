//
//  PlayerStatsList.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 21/09/2025.
//

import SwiftUI

struct PlayerStatsList: View {
    let stats: [PlayerStats]   // <- injecté

    var body: some View {
        List(stats) { s in
            NavigationLink {
                PlayerStatsDetailView(stats: s)   // déjà prêt pour les Charts
            } label: {
                HStack {
                    VStack(alignment: .leading) {
                        Text(s.name).font(.headline)
                        Text("\(s.gamesPlayed) parties • \(s.wins) victoires • \(Int(s.winRate * 100))%")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("Moy: \(Int(s.avgScore.rounded()))")
                        Text("Best: \(s.bestScore)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

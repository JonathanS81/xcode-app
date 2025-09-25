//
//  StatisticsTab..swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 21/09/2025.
//
import SwiftUI
import SwiftData

struct StatisticsTab: View {
    @Query private var players: [Player]
    @Query private var games: [Game]

    @StateObject private var store = StatsStore()
    @State private var selection: Int = 0

    var body: some View {
        NavigationStack {
            VStack {
                Picker("", selection: $selection) {
                    Text("Joueurs").tag(0)
                    Text("Global").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selection == 0 {
                    PlayerStatsList(stats: store.playerStats)
                } else {
                    AppStatsView(stats: store.appStats)
                }
            }
            .navigationTitle("Statistiques")
            .onAppear { store.refresh(players: players, games: games) }
            .onChange(of: players) { _, _ in store.refresh(players: players, games: games) }
            .onChange(of: games) { _, _ in store.refresh(players: players, games: games) }
        }
    }
}

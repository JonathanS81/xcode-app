//
//  PlayerStatsDetailView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 22/09/2025.
//
import SwiftUI
import Charts

struct PlayerStatsDetailView: View {
    let stats: PlayerStats

    var body: some View {
        List {
            Section("Résumé") {
                LabeledContent("Parties jouées", value: "\(stats.gamesPlayed)")
                LabeledContent("Victoires", value: "\(stats.wins) (\(Int(stats.winRate * 100))%)")
                LabeledContent("Score moyen", value: "\(Int(stats.avgScore.rounded()))")
                LabeledContent("Meilleur score", value: "\(stats.bestScore)")
                LabeledContent("Plus bas score", value: "\(stats.worstScore)")
                LabeledContent("Taux de Yams", value: "\(Int(stats.yamsRate * 100))%")
            }

            if !stats.scoresHistory.isEmpty {
                Section("Évolution des scores") {
                    Chart {
                        ForEach(Array(stats.scoresHistory.enumerated()), id: \.offset) { idx, score in
                            LineMark(
                                x: .value("Partie", idx + 1),
                                y: .value("Score", score)
                            )
                            PointMark(
                                x: .value("Partie", idx + 1),
                                y: .value("Score", score)
                            )
                        }
                    }
                    .frame(height: 200)
                }
            }
        }
        .navigationTitle(stats.name)
    }
}

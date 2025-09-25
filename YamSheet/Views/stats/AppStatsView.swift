//
//  AppStatsView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 21/09/2025.
//

import SwiftUI
import Charts

struct AppStatsView: View {
    let stats: AppStats?

    var body: some View {
        List {
            if let s = stats {
                Section("Général") {
                    LabeledContent("Parties (total)", value: "\(s.totalGames)")
                    LabeledContent("Parties terminées", value: "\(s.completedGames)")
                    LabeledContent("Joueurs", value: "\(s.totalPlayers)")
                }

                Section("Records") {
                    if let best = s.bestScoreEver {
                        LabeledContent("Meilleur score", value: "\(best.score) — \(best.name)")
                    } else {
                        Text("Pas encore de partie terminée.")
                    }
                    if let mw = s.mostWins {
                        LabeledContent("Plus de victoires", value: "\(mw.wins) — \(mw.name)")
                    }
                }

                // Exemple de bar chart des scores moyens (léger)
                // On peut passer un tableau dérivé si tu veux éviter de re-créer un service ici.
                // Ici, on reste pur : AppStats n'a pas la liste, donc à toi de choisir si on veut y ajouter un snapshot.
            } else {
                Text("Calcul des statistiques…").foregroundStyle(.secondary)
            }
        }
    }
}

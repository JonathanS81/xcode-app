//
//  EndGameSheet.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//

import SwiftUI

struct EndGameSheet: View {
    struct Entry: Identifiable {
        var id: UUID { playerID }
        let playerID: UUID
        let name: String
        let score: Int
    }

    let entries: [Entry]  // triées par score desc
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Partie terminée")
                .font(.title).bold()

            if let winner = entries.first {
                Text("🏆 Vainqueur : \(winner.name) — \(winner.score)")
                    .font(.title3).bold()
                    .padding(.bottom, 8)
            }

            List(entries) { e in
                HStack {
                    Text(e.name)
                    Spacer()
                    Text("\(e.score)").bold()
                }
            }
            .listStyle(.plain)
            .frame(maxHeight: 320)

            Button("Fermer") { onClose() }
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .presentationDetents([.medium, .large])
        .onAppear {
            #if os(iOS)
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            #endif
        }
    }
}


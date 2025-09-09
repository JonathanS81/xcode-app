//
//  TurnHeaderView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//

import SwiftUI

struct TurnHeaderView<PlayerType: Identifiable>: View {
    let players: [PlayerType]
    let idFor: (PlayerType) -> UUID
    let nameFor: (PlayerType) -> String
    let activePlayerID: UUID?
    let onTapPlayer: (PlayerType) -> Void
    let onPause: () -> Void
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(activeTitle)
                    .font(.headline)
                Spacer()
                Button("Mettre en pause", action: onPause)
            }
            .padding(.bottom, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(players) { p in
                        let isActive = (idFor(p) == activePlayerID)
                        Text(nameFor(p))
                            .font(isActive ? .headline.bold() : .body)
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(isActive ? Color.yellow.opacity(0.3) : Color.gray.opacity(0.12))
                            .clipShape(Capsule())
                            .onTapGesture { onTapPlayer(p) }
                    }
                }
            }

            Button {
                onNext()
            } label: {
                Text("Joueur suivant")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var activeTitle: String {
        guard let id = activePlayerID,
              let p = players.first(where: { idFor($0) == id }) else { return "Au tour de —" }
        return "Au tour de \(nameFor(p))"
    }
}


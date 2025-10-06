//
//  GDV.PlayerChips.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//

import SwiftUI

struct GDV_PlayerChips: View {
    let players: [String]
    let activeIndex: Int?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(players.enumerated()), id: \.offset) { idx, name in
                    Text(name)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background((idx == activeIndex) ? Color.yellow.opacity(0.28) : Color.gray.opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(.vertical, 4)
        }
    }
}

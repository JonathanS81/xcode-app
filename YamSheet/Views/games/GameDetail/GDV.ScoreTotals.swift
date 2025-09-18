//
//  GDV.ScoreTotals.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//

import SwiftUI

struct GDV_ScoreTotals: View {
    let totalText: (Int) -> String
    let playerCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Totaux").font(.headline)
            HStack {
                Text("Total").frame(width: 110, alignment: .leading)
                ForEach(0..<playerCount, id: \.self) { idx in
                    Text(totalText(idx))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(Color.gray.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

//
//  GDV.Header.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//
import SwiftUI
import SwiftData   // ✅ ajoute ceci


struct GDV_Header: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allPlayers: [Player]

    private func colorForPlayerID(_ id: UUID?) -> Color {
        guard let id, let p = allPlayers.first(where: { $0.id == id }) else { return .accentColor }
        return p.color
    }

    private func colorForColumnIndex(_ idx: Int, using columnPlayerIDs: [UUID]) -> Color {
        guard idx >= 0 && idx < columnPlayerIDs.count else { return .accentColor }
        return colorForPlayerID(columnPlayerIDs[idx])
    }
    
    
    private var activeColor: Color {
        // Si le header a accès à `game.activePlayerID`
        if let g = (Mirror(reflecting: self).children.first { $0.label == "game" }?.value as? Game) {
            return colorForPlayerID(g.activePlayerID)
        }
        // Sinon, si le header expose directement activePlayerID
        if let apid = (Mirror(reflecting: self).children.first { $0.label == "activePlayerID" }?.value as? UUID) {
            return colorForPlayerID(apid)
        }
        return .accentColor
    }
    
    
    let title: String
    let subtitle: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.title3.weight(.semibold))
                if let subtitle {
                    Text(subtitle).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

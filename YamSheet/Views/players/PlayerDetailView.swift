//
//  PlayerDetailView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 03/09/2025.
//


import SwiftUI
import SwiftData

struct PlayerDetailView: View {
    // On reçoit un Player "normal" (pas de @Bindable requis pour afficher)
    let player: Player

    @Environment(\.modelContext) private var context
    @Query private var allGames: [Game]

    @State private var presentEdit: Bool = false

    // MARK: - Derived metrics
    private var gamesInvolvingPlayer: [Game] {
        allGames.filter { g in g.scorecards.contains { $0.playerID == player.id } }
    }
    private var gamesCount: Int { gamesInvolvingPlayer.count }

    private var completedGames: [Game] {
        gamesInvolvingPlayer.filter { $0.statusOrDefault == .completed }
    }

    private var winsCount: Int {
        var wins = 0
        for g in completedGames {
            // Totaux de la partie via StatsService/StatsEngine (source de vérité)
            let totals = g.scorecards.map { (pid: $0.playerID, total: StatsService.total(for: $0, game: g)) }
            let top = totals.map { $0.total }.max() ?? Int.min
            let winners = totals.filter { $0.total == top }.map { $0.pid }
            if winners.contains(player.id) { wins += 1 }
        }
        return wins
    }

    private var averageScore: Int {
        var scores: [Int] = []
        for g in completedGames {
            if let sc = g.scorecards.first(where: { $0.playerID == player.id }) {
                scores.append(StatsService.total(for: sc, game: g))
            }
        }
        guard !scores.isEmpty else { return 0 }
        let sum = scores.reduce(0, +)
        return Int((Double(sum) / Double(scores.count)).rounded())
    }

    var body: some View {
        List {
            header
            Section("Statistiques") {
                HStack { Label("Parties", systemImage: "gamecontroller"); Spacer(); Text("\(gamesCount)") }
                HStack { Label("Victoires", systemImage: "trophy.fill"); Spacer(); Text("\(winsCount)") }
                HStack { Label("Score moyen", systemImage: "chart.bar"); Spacer(); Text("\(averageScore)") }
            }

            Section("Informations") {
                if let email = player.email, !email.isEmpty {
                    HStack { Label("Email", systemImage: "envelope"); Spacer(); Text(email).textSelection(.enabled) }
                }
                if let emoji = player.favoriteEmoji, !emoji.isEmpty {
                    HStack { Label("Emoji favori", systemImage: "face.smiling"); Spacer(); Text(emoji) }
                }
                HStack {
                    Label("Couleur", systemImage: "paintpalette")
                    Spacer()
                    Circle().fill(player.color).frame(width: 18, height: 18)
                }
            }
        }
        .navigationTitle(player.nickname.isEmpty ? player.name : player.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Modifier") { presentEdit = true }
            }
        }
        .sheet(isPresented: $presentEdit) {
            NavigationStack {
                PlayerEditorView(player: player)
                    .navigationTitle("Modifier le joueur")
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }

    // MARK: - Header
    private var header: some View {
        Section {
            HStack(spacing: 16) {
                AvatarView(imageData: player.avatarImageData, fallbackColor: player.color)
                VStack(alignment: .leading, spacing: 4) {
                    Text(player.name).font(.title3).bold()
                    if !player.nickname.isEmpty { Text("\(player.nickname)").foregroundStyle(.secondary) }
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Small Avatar helper (local)
private struct AvatarView: View {
    let imageData: Data?
    let fallbackColor: Color

    var body: some View {
        ZStack {
            Circle().fill(fallbackColor.opacity(0.15))
            if let data = imageData, let ui = UIImage(data: data) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.fill")
                    .imageScale(.large)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay { Circle().stroke(.quaternary, lineWidth: 1) }
    }
}

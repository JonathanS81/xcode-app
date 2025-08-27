import SwiftUI
import SwiftData

struct PlayerDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var player: Player

    var body: some View {
        Form {
            Section("Identité") {
                TextField("Nom", text: $player.name)
                TextField("Surnom", text: $player.nickname)
                TextField("Email", text: Binding(get: { player.email ?? "" }, set: { player.email = $0.isEmpty ? nil : $0 }))
                Toggle("Invité", isOn: $player.isGuest)
            }
            Section("Stats") {
                LabeledContent("Parties", value: String(player.gamesCount))
                LabeledContent("Yams", value: String(player.yamsCount))
                LabeledContent("Moyenne", value: String(format: "%.1f", player.averageScore))
                LabeledContent("Meilleur", value: String(player.bestScore))
                LabeledContent("Pire", value: String(player.worstScore))
                LabeledContent("Victoires", value: String(player.wins))
                LabeledContent("Défaites", value: String(player.losses))
            }
        }
        .navigationTitle(player.nickname)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button("Sauver") { try? context.save() } }
        }
    }
}

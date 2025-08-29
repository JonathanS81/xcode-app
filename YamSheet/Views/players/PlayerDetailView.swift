import SwiftUI
import SwiftData

struct PlayerDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var player: Player

    var body: some View {
        Form {
            Section(UIStrings.Common.identity) {
                TextField(UIStrings.Player.name, text: $player.name)
                TextField(UIStrings.Player.surname, text: $player.nickname)
                TextField(UIStrings.Player.email, text: Binding(get: { player.email ?? "" }, set: { player.email = $0.isEmpty ? nil : $0 }))
                Toggle(UIStrings.Player.invite, isOn: $player.isGuest)
            }
            Section(UIStrings.Common.stats) {
                LabeledContent(UIStrings.Common.games, value: String(player.gamesCount))
                LabeledContent(UIStrings.Game.yams, value: String(player.yamsCount))
                LabeledContent(UIStrings.Common.avg, value: String(format: "%.1f", player.averageScore))
                LabeledContent(UIStrings.Common.best, value: String(player.bestScore))
                LabeledContent(UIStrings.Common.worst, value: String(player.worstScore))
                LabeledContent(UIStrings.Common.wins, value: String(player.wins))
                LabeledContent(UIStrings.Common.losses, value: String(player.losses))
            }
        }
        .navigationTitle(player.nickname)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) { Button(UIStrings.Common.save) { try? context.save() } }
        }
    }
}

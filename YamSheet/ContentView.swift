import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            GamesListView()
                .tabItem { Label("Parties", systemImage: "list.bullet.rectangle") }
            PlayersListView()
                .tabItem { Label("Joueurs", systemImage: "person.3") }
            SettingsView()
                .tabItem { Label("Réglages", systemImage: "gear") }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [AppSettings.self, Player.self, Game.self, Scorecard.self], inMemory: true)
}

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            GamesListView()
                .tabItem { Label(UIStrings.Common.games, systemImage: "list.bullet.rectangle") }
            PlayersListView()
                .tabItem { Label(UIStrings.Common.players, systemImage: "person.3") }
            NotationsListView()
                .tabItem { Label(UIStrings.Common.notations, systemImage: "text.badge.star") }
            StatisticsTab()
                .tabItem {
                    Image(systemName: "chart.bar")
                    Text("Stats")
                }
            SettingsView()
                .tabItem { Label(UIStrings.Common.settings, systemImage: "gear") }
            
        }
    }
}

#Preview {
    ContentView()
  .modelContainer(for: [AppSettings.self, Player.self, Game.self, Scorecard.self], inMemory: true)
}

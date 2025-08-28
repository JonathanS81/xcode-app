import SwiftUI
import SwiftData

struct NewPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var nickname: String = ""
    @State private var email: String = ""
    @State private var isGuest: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                TextField(UIStrings.Player.name, text: $name)
                TextField(UIStrings.Player.surname.capitalized, text: $nickname)
                TextField(UIStrings.Player.email, text: $email)
                    .keyboardType(.emailAddress)
                Toggle(UIStrings.Player.invite, isOn: $isGuest)
            }
            .navigationTitle("Nouveau joueur")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(UIStrings.Common.cancel) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(UIStrings.Common.create) { create() }.disabled(name.isEmpty || nickname.isEmpty)
                }
            }
        }
    }

    private func create() {
        let p = Player(name: name, nickname: nickname, email: email.isEmpty ? nil : email, isGuest: isGuest)
        context.insert(p)
        try? context.save()
        dismiss()
    }
}

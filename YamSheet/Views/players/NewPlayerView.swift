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
                TextField("Nom", text: $name)
                TextField("Surnom", text: $nickname)
                TextField("Email (optionnel)", text: $email)
                    .keyboardType(.emailAddress)
                Toggle("Invité", isOn: $isGuest)
            }
            .navigationTitle("Nouveau joueur")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Créer") { create() }.disabled(name.isEmpty || nickname.isEmpty)
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

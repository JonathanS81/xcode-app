//
//  PlayerFormView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 28/09/2025.
//

import SwiftUI
import PhotosUI

struct PlayerFormView: View {
    struct Draft {
        var name: String = ""
        var nickname: String = ""
        var email: String = ""
        var favoriteEmoji: String = ""
        var preferredColor: Color = .blue
        var isGuest: Bool = false
        var avatarImageData: Data?
    }

    @Binding var draft: Draft
    var isEditing: Bool = false
    var onValidate: ((Draft) -> Void)?
    var onCancel: (() -> Void)?

    @State private var photoItem: PhotosPickerItem?
    @FocusState private var focusedField: Field?
    enum Field { case name, nickname, email, emoji }

    var body: some View {
        Form {
            Section("Identité") {
                HStack {
                    AvatarView(data: draft.avatarImageData)
                    PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                        Text("Choisir une photo").font(.callout)
                    }
                    .onChange(of: photoItem) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self) {
                                draft.avatarImageData = data
                            }
                        }
                    }
                }

                TextField("Nom (obligatoire)", text: $draft.name)
                    .textContentType(.name)
                    .focused($focusedField, equals: .name)

                TextField("Surnom", text: $draft.nickname)
                    .textContentType(.nickname)
                    .focused($focusedField, equals: .nickname)

                TextField("Email (facultatif)", text: $draft.email)
                    .keyboardType(.emailAddress)
                    .textContentType(.emailAddress)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .focused($focusedField, equals: .email)

                Toggle("Invité", isOn: $draft.isGuest)
            }

            Section("Préférences") {
                TextField("Emoji favori (facultatif)", text: $draft.favoriteEmoji)
                    .focused($focusedField, equals: .emoji)

                ColorPicker("Couleur", selection: $draft.preferredColor, supportsOpacity: false)
            }

            Section {
                Button(isEditing ? "Enregistrer" : "Créer") {
                    onValidate?(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if onCancel != nil {
                    Button("Annuler", role: .cancel) { onCancel?() }
                }
            }
        }
    }
}

private struct AvatarView: View {
    var data: Data?
    var body: some View {
        Group {
            if let data, let img = UIImage(data: data) {
                Image(uiImage: img)
                    .resizable().scaledToFill()
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable().scaledToFit()
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
                    .padding(10)
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(Circle())
        .overlay {
            Circle().stroke(.quaternary, lineWidth: 1)
        }
    }
}

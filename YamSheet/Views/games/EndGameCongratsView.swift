//
//  EndGameCongratsView.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 06/09/2025.
//

import SwiftUI

struct EndGameCongratsView: View {
    struct Entry: Identifiable {
        let id = UUID()
        let name: String
        let score: Int
    }

    let gameName: String?
    let entries: [Entry]
    let dismiss: () -> Void

    // Detecte tous les .json présents dans le sous-dossier Resources (folder bleu)
    private var animationNames: [String] {
        let paths = Bundle.main.paths(forResourcesOfType: "json", inDirectory: "Resources")
        // Garde uniquement les fichiers Lottie “célébration” si tu veux (ex: par préfixe)
        // let filtered = paths.filter { $0.contains("Confetti") || $0.contains("Fireworks") }

        return paths
            .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
            .sorted()
    }
    // Ton dossier est BLEU "Resources" → on précise le sous-dossier
    private let lottieSubdir: String? = "Resources"   // (si dossier jaune: passe à nil)

    private var winnerName: String { entries.first?.name ?? "—" }

    var body: some View {
        // Contenu “classique”
        let content = VStack(spacing: 16) {
            Text("Partie terminée")
                .font(.title3.bold())

            if let n = gameName, !n.isEmpty {
                Text(n)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Image(systemName: "trophy.fill").imageScale(.large)
                Text("Bravo \(winnerName) !")
                    .font(.title2.weight(.semibold))
            }
            .foregroundStyle(.orange)

            // TABLEAU DE CLASSEMENT — version originale
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(entries.enumerated()), id: \.offset) { idx, e in
                    HStack {
                        Text("\(idx + 1). \(e.name)")
                        Spacer()
                        Text("\(e.score)").fontWeight(.semibold)
                    }
                    .font(idx == 0 ? .headline : .body)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))   // ⟵ le fond “classique”
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 2)

            Button(action: dismiss) {
                Text("OK")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)

        // Lottie en ARRIÈRE-PLAN (ne modifie pas le tableau)
        return content
            .background {
                LottieRandomCelebrationView(
                    names: animationNames,
                    loopOnce: true,
                    speed: 1.0,
                    subdirectory: lottieSubdir
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .onAppear {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
    }
}

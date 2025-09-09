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

    // Si dossier BLEU "Resources", laisse "Resources". Si dossier JAUNE (Group), mets nil.
    private let lottieSubdir: String? = "Resources"

    // Auto-détection de tous les .json dans le bundle (racine + Resources)
    private var animationNames: [String] {
        let inRes  = Bundle.main.paths(forResourcesOfType: "json", inDirectory: "Resources")
        let inRoot = Bundle.main.paths(forResourcesOfType: "json", inDirectory: nil)
        let all = (inRes + inRoot)
            .map { URL(fileURLWithPath: $0).deletingPathExtension().lastPathComponent }
            .reduce(into: [String]()) { acc, name in if !acc.contains(name) { acc.append(name) } }
            .sorted()
        #if DEBUG
        print("[EndGameCongrats] JSON détectés:", all)
        #endif
        return all
    }

    private var winnerName: String { entries.first?.name ?? "—" }

    var body: some View {
        // === CONTENU PRINCIPAL (définit le layout du sheet) ===
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

            // Tableau "classique"
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
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(radius: 2)

            Button(action: dismiss) {
                Text("OK").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)

        // === IMPORTANT : LOTTIE EN OVERLAY (n’affecte PAS la taille) ===
        return content
            // (Optionnel) Dim léger pour mieux faire ressortir l’anim :
            //.overlay(alignment: .center) {
            //    Color.black.opacity(0.12).allowsHitTesting(false).clipped()
            //}
            .overlay(alignment: .center) {
                // L’overlay reçoit exactement la même taille que `content`
                LottieRandomCelebrationView(
                    names: animationNames,
                    loopOnce: false,
                    speed: 0.80,
                    subdirectory: lottieSubdir
                )
                .opacity(0.20)               // plein pot; ajuste si besoin
                .blendMode(.normal)       // tu peux tester .screen / .plusLighter / .overlay
                .allowsHitTesting(false)    // ne bloque pas le bouton OK
                .clipped()                  // ne déborde pas du content
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
            .onAppear { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    }
}

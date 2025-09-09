//
//  DebugViews.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 08/09/2025.
//

import SwiftUI

struct LottieSmokeTest: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Smoke Test Lottie").font(.headline)
            LottieRandomCelebrationView(
                names: ["Confetti", "Confetti2", "Confetti3", "Fireworks"],
                loopOnce: true, speed: 1.0, subdirectory: "Resources" // ← BLEU
            )
            .frame(height: 200)
            .background(Color.black.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

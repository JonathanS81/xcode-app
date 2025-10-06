//
//  LottieSupport.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 08/09/2025.
//
import SwiftUI

#if canImport(Lottie)
import Lottie

// MARK: - Loader robuste (racine + sous-dossier)
enum LottieLoader {
    static func load(named name: String, subdirectory: String? = nil, bundle: Bundle = .main) -> LottieAnimation? {
        // 1) racine
        if let a = LottieAnimation.named(name, bundle: bundle) { return a }
        // 2) sous-dossier explicite (ex: "Resources" si dossier BLEU)
        if let sub = subdirectory, let a = LottieAnimation.named(name, bundle: bundle, subdirectory: sub) { return a }
        // 3) fallback: chemins explicites
        for dir in [subdirectory, "Resources", nil] {
            if let path = bundle.path(forResource: name, ofType: "json", inDirectory: dir) {
                return LottieAnimation.filepath(path)
            }
        }
        #if DEBUG
        DLog("[LottieLoader] ❌ Échec chargement '\(name)' (subdir=\(subdirectory ?? "nil"))")
        #endif
        return nil
    }

    @discardableResult
    static func listJSONs(in bundle: Bundle = .main) -> [String] {
        let paths = bundle.paths(forResourcesOfType: "json", inDirectory: nil).sorted()
        #if DEBUG
        DLog("[LottieLoader] JSON dans bundle:\n" + paths.joined(separator: "\n"))
        #endif
        return paths
    }
}

// MARK: - UIViewRepresentable
struct LottieView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .playOnce
    var speed: CGFloat = 1.0
    var subdirectory: String? = nil

    func makeUIView(context: Context) -> LottieAnimationView {
        let v = LottieAnimationView()
        v.backgroundBehavior = .pauseAndRestore
        v.contentMode = .scaleAspectFill
        v.loopMode = loopMode
        v.animationSpeed = speed
        v.backgroundColor = .clear          // important
        v.isOpaque = false
        v.animation = LottieLoader.load(named: name, subdirectory: subdirectory)

        // lancer après layout
        DispatchQueue.main.async {
            if v.animation != nil {
                #if DEBUG
                DLog("[LottieView] ▶️ play '\(name)'")
                #endif
                v.play()
            } else {
                #if DEBUG
                DLog("[LottieView] ⚠️ animation == nil pour '\(name)'")
                #endif
            }
        }
        return v
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        if uiView.animation != nil, !uiView.isAnimationPlaying {
            uiView.play()
        }
    }
}

// MARK: - Vue aléatoire robuste (filtre les chargeables)
struct LottieRandomCelebrationView: View {
    let names: [String]             // sans .json
    var loopOnce: Bool = true
    var speed: CGFloat = 1.0
    var subdirectory: String? = nil // "Resources" si dossier BLEU

    @State private var picked: String?

    var body: some View {
        Group {
            if let p = picked {
                LottieView(name: p,
                           loopMode: loopOnce ? .playOnce : .loop,
                           speed: speed,
                           subdirectory: subdirectory)
            } else {
                // Fallback visuel si rien de chargeable
                #if DEBUG
                Text("⚠️ Aucune animation Lottie chargeable").font(.caption).padding(8)
                    .background(.red.opacity(0.85)).clipShape(Capsule()).foregroundStyle(.white)
                #else
                Color.clear
                #endif
            }
        }
        .onAppear {
            // filtre les animations réellement chargeables
            let ok = names.filter { LottieLoader.load(named: $0, subdirectory: subdirectory) != nil }
            #if DEBUG
            DLog("[LottieRandom] chargeables =", ok)
            if ok.isEmpty { _ = LottieLoader.listJSONs() }
            #endif
            picked = ok.randomElement()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }
}

#else   // --- fallback quand Lottie n'est pas attaché au target ---

struct LottieView: View {
    let name: String
    var loopMode: Int = 0
    var speed: CGFloat = 1.0
    var subdirectory: String? = nil
    var body: some View { Color.clear }
}

struct LottieRandomCelebrationView: View {
    let names: [String]; var loopOnce: Bool = true; var speed: CGFloat = 1.0; var subdirectory: String? = nil
    var body: some View { Color.clear }
}

#endif

// MARK: - (DEBUG) Inspecteur simple
#if DEBUG && canImport(Lottie)
struct LottieBundleInspectorView: View {
    @State private var jsons: [String] = []
    @State private var showPreview = false
    @State private var selection: String?

    var body: some View {
        NavigationStack {
            List(jsons, id: \.self) { path in
                let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                Button {
                    selection = name; showPreview = true
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(name)
                        Text(path).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Lottie Inspector")
            .onAppear { jsons = LottieLoader.listJSONs() }
            .sheet(isPresented: $showPreview) {
                VStack {
                    Text(selection ?? "—").font(.headline)
                    if let n = selection {
                        LottieView(name: n).frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        Color.clear
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
    }
}
#endif

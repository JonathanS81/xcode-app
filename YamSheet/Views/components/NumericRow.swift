//
//  NumericRow.swift
//  YamSheet
//
//  Created by Jonathan Sportiche  on 14/09/2025.
//
import SwiftUI

/// Ligne de saisie numérique (score) avec affichage optionnel d'une valeur effective (ex: bonus).
struct NumericRow: View {

    struct Config {
        var label: String = ""                          // non utilisé ici (le label est géré par la grille)
        var value: Binding<Int>                         // -1 = vide ; >=0 = valeur saisie
        var isLocked: Bool = false
        var isActive: Bool = true                       // joueur actif => style différent
        var validator: ((Int?) -> Int)? = nil           // VALIDATION AU COMMIT uniquement
        var displayMap: ((Int) -> String)? = nil        // transforme la valeur stockée en valeur “effective”
        var valueFont: Font? = nil                      // font de la valeur brute (badge)
        var effectiveFont: Font? = nil                  // font de la valeur centrale (effective)
        var contentPadding: CGFloat = 8                 // padding interne dynamique
        var allowedRange: ClosedRange<Int> = 5...30
        var allowZero: Bool = false
        var onInvalidInput: ((Int) -> Void)? = nil
        var containerFill: AnyShapeStyle? = nil
        var textColor: Color? = nil               // ⬅️ NOUVEAU
        var caretTint: Color? = nil               // ⬅️ NOUVEAU
    }

    private let cfg: Config

    // Etat local d'édition (buffer texte). On ne pousse vers cfg.value QU'AU COMMIT.
    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    init(_ cfg: Config) { self.cfg = cfg }

    var body: some View {
        ZStack {
            // 1) Zone éditable : TextField visible en édition (curseur centré), quasi invisible sinon
            TextField(
                UIStrings.Common.dash,
                text: $text
            )
            .focused($isFocused)
            .keyboardType(.numberPad)
            .disableAutocorrection(true)
            .textInputAutocapitalization(.never)
            .submitLabel(.done)
            .multilineTextAlignment(.center)            // curseur & saisie centrés
            .foregroundColor(cfg.textColor ?? .primary)
            .tint(cfg.caretTint ?? .accentColor)
            .background(Color.clear)
            .opacity(isFocused ? 1.0 : 0.001)           // hors focus on masque le texte natif
            .padding(cfg.contentPadding)
            .frame(maxWidth: .infinity, minHeight: 36)  // même hauteur que les Picker
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
               // RoundedRectangle(cornerRadius: 8)
                   // .stroke(Color.accentColor.opacity(isFocused ? 0.35 : 0.0), lineWidth: 1)
                RoundedRectangle(cornerRadius: 8)
                              .fill(cfg.containerFill ?? AnyShapeStyle(Color(.systemGray6)))
            )
            .onSubmit { commit() }
            .onChange(of: isFocused) { was, now in
                if was && !now { commit() }             // commit quand on quitte la case
            }
            .onAppear { syncFromBinding() }
            .onChange(of: cfg.value.wrappedValue) { _, _ in
                if !isFocused { syncFromBinding() }     // resync si modif externe
            }
            .onChange(of: text) { _, newText in
                // Laisser taper librement, mais filtrer aux chiffres
                let filtered = newText.filter { $0.isNumber }
                if filtered != newText { text = filtered }
            }

            // 2) Calculs d'affichage (raw/effective)
            let raw = cfg.value.wrappedValue
            let rawText = (raw >= 0) ? String(raw) : ""
            let effText: String? = {
                guard raw >= 0, let map = cfg.displayMap else { return nil }
                let eff = map(raw)
                return eff != rawText ? eff : nil
            }()

            // 3) Texte central (affiché uniquement hors édition)
            if !isFocused {
                Text(effText ?? (rawText.isEmpty ? "—" : rawText))
                    .font(cfg.effectiveFont)            // 👈 utilise la police fournie
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    // réserve de place pour le badge à droite si effText
                    .padding(.horizontal, effText != nil ? max(16, cfg.contentPadding * 2) : cfg.contentPadding)
                    .allowsHitTesting(false)
            }

            // 4) Badge à droite : valeur brute seulement quand non focus ET différente de l’effective
            if !isFocused, let _ = effText, !rawText.isEmpty {
                Text(rawText)
                    .font(cfg.valueFont)                // 👈 utilise la police fournie
                    .foregroundColor(.secondary)
                    .padding(.horizontal, max(4, cfg.contentPadding * 0.75))
                    .padding(.vertical, max(2, cfg.contentPadding * 0.25))
                    .background(Color.black.opacity(0.06))
                    .clipShape(Capsule())
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, max(4, cfg.contentPadding * 0.75))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .allowsHitTesting(false)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .disabled(cfg.isLocked || !cfg.isActive)
        .animation(.easeInOut(duration: 0.12), value: isFocused)
    }

    // MARK: - Commit / Sync
    private func commit() {
        // Validation différée au commit
        let previous = cfg.value.wrappedValue
        let intVal = Int(text)
        var validated = cfg.validator?(intVal) ?? (intVal ?? -1)

        // Si l'utilisateur saisit une valeur > 0 mais que le validator la rejette (== -1),
        // on n'auto-corrige pas : on notifie et on restaure la valeur précédente.
        if let raw = intVal, raw > 0, cfg.validator != nil, validated == -1 {
            cfg.onInvalidInput?(raw)
            // Restaure la valeur précédente sans modification
            cfg.value.wrappedValue = previous
            syncFromBinding()
            return
        }

        // Autoriser explicitement 0 (barré) si demandé par la config
        if validated == 0, cfg.allowZero {
            cfg.value.wrappedValue = 0
            syncFromBinding()
            return
        }

        // Clamp final via allowedRange (uniquement pour les valeurs strictement positives)
        if validated > 0 {
            if validated < cfg.allowedRange.lowerBound { validated = cfg.allowedRange.lowerBound }
            if validated > cfg.allowedRange.upperBound { validated = cfg.allowedRange.upperBound }
        }

        cfg.value.wrappedValue = validated
        syncFromBinding() // refléter la valeur stockée
    }

    private func syncFromBinding() {
        let v = cfg.value.wrappedValue
        text = (v >= 0) ? String(v) : ""
    }

    // MARK: - Styling
    private var backgroundColor: Color {
        let isOpen = (cfg.value.wrappedValue == -1)
        if cfg.isActive {
            return isOpen ? Color.blue.opacity(0.12) : Color.green.opacity(0.12)
        } else {
            return Color.gray.opacity(0.08)
        }
    }
}

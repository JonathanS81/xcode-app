import SwiftUI
import PhotosUI
import UIKit

/// Contenu commun aux écrans de création et de modification d'une notation.
/// Chaque interrupteur est placé avec les règles qu'il active afin d'éviter
/// d'avoir à naviguer entre une liste de contenu et les réglages associés.
struct NotationConfigurationSections: View {
    @Bindable var notation: Notation

    var body: some View {
        Section("Informations") {
            TextField("Nom de la notation", text: $notation.name)
            TextField("Commentaire", text: $notation.comment, axis: .vertical)
                .lineLimit(2...4)
        }

        Section("Apparence de la feuille") {
            ScorecardAppearanceEditor(notation: notation)
        }

        Section {
            if notation.visibility.upperSectionEnabled {
                NotationNumberRow(
                    title: UIStrings.Notation.upperBonusThresholdLabel,
                    value: $notation.upperBonusThreshold,
                    range: 0...200
                )
                NotationNumberRow(
                    title: UIStrings.Notation.upperBonusLabel,
                    value: $notation.upperBonusValue,
                    range: 0...200
                )

                DisclosureGroup("Aides") {
                    helpField("Aide générale de la section", key: .sectionUpper)
                    helpField("As", key: .ones)
                    helpField("Deux", key: .twos)
                    helpField("Trois", key: .threes)
                    helpField("Quatre", key: .fours)
                    helpField("Cinq", key: .fives)
                    helpField("Six", key: .sixes)
                }
            } else {
                disabledSectionLabel
            }
        } header: {
            sectionHeader(
                "Section haute",
                isOn: visibilityBinding(\.upperSectionEnabled)
            )
        }

        Section {
            if notation.visibility.middleSectionEnabled {
                Picker(UIStrings.Notation.rulePicker, selection: $notation.middleModeRaw) {
                    Text(UIStrings.Notation.middleLabel(.multiplier))
                        .tag(MiddleRuleMode.multiplier.rawValue)
                    Text(UIStrings.Notation.middleLabel(.bonusGate))
                        .tag(MiddleRuleMode.bonusGate.rawValue)
                }

                Text(
                    StatsEngine.middleTooltip(
                        mode: MiddleRuleMode(rawValue: notation.middleModeRaw) ?? .multiplier,
                        threshold: notation.middleBonusSumThreshold,
                        bonus: notation.middleBonusValue,
                        invalidPairMode: notation.middleInvalidPairMode
                    )
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                if MiddleRuleMode(rawValue: notation.middleModeRaw) == .bonusGate {
                    NotationNumberRow(
                        title: UIStrings.Notation.thresholdSum,
                        value: $notation.middleBonusSumThreshold,
                        range: 0...200
                    )
                    NotationNumberRow(
                        title: UIStrings.Notation.bonus,
                        value: $notation.middleBonusValue,
                        range: 0...200
                    )
                    Picker(
                        "Si Max ≤ Min",
                        selection: Binding(
                            get: { notation.middleInvalidPairMode },
                            set: { notation.middleInvalidPairMode = $0 }
                        )
                    ) {
                        ForEach(MiddleInvalidPairMode.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                }

                DisclosureGroup("Aide") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Aide affichée sur la feuille de score")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(notation.helpTextValue(for: .sectionMiddle))
                            .foregroundStyle(.primary)
                    }
                    .padding(.vertical, 4)
                }
            } else {
                disabledSectionLabel
            }
        } header: {
            sectionHeader(
                "Section milieu",
                isOn: visibilityBinding(\.middleSectionEnabled)
            )
        }

        Section {
            if notation.visibility.bottomSectionEnabled {
                bottomRule(
                    "Brelan",
                    isOn: visibilityBinding(\.brelanEnabled),
                    helpKey: .brelan
                ) {
                    FigureRuleRow(
                        title: "Notation",
                        figure: .brelan,
                        rule: $notation.ruleBrelan,
                        onModeChanged: { resetHelp(for: .brelan) }
                    )
                }

                bottomRule("Chance", isOn: chanceBinding, helpKey: .chance) {
                    FigureRuleRow(
                        title: "Notation",
                        figure: .chance,
                        rule: $notation.ruleChance,
                        onModeChanged: { resetHelp(for: .chance) }
                    )
                }

                bottomRule(
                    "Full",
                    isOn: visibilityBinding(\.fullEnabled),
                    helpKey: .full
                ) {
                    FigureRuleRow(
                        title: "Notation",
                        figure: .full,
                        rule: $notation.ruleFull,
                        onModeChanged: { resetHelp(for: .full) }
                    )
                }

                bottomRule(
                    "Grande suite",
                    isOn: visibilityBinding(\.suiteEnabled),
                    helpKey: .suite
                ) {
                    BigSuiteRuleBlock(
                        modeRaw: $notation.suiteBigModeRaw,
                        singleValue: $notation.suiteBigFixed,
                        value1to5: $notation.suiteBigFixed1to5,
                        value2to6: $notation.suiteBigFixed2to6
                    )
                }

                bottomRule(
                    "Petite suite",
                    isOn: smallStraightBinding,
                    helpKey: .petiteSuite
                ) {
                    FigureRuleRow(
                        title: "Notation",
                        figure: .petiteSuite,
                        rule: $notation.rulePetiteSuite,
                        onModeChanged: { resetHelp(for: .petiteSuite) }
                    )
                }

                bottomRule(
                    "Carré",
                    isOn: visibilityBinding(\.carreEnabled),
                    helpKey: .carre
                ) {
                    FigureRuleRow(
                        title: "Notation",
                        figure: .carre,
                        rule: $notation.ruleCarre,
                        onModeChanged: { resetHelp(for: .carre) }
                    )
                }

                bottomRule(
                    "Yams",
                    isOn: visibilityBinding(\.yamsEnabled),
                    helpKey: .yams
                ) {
                    FigureRuleRow(
                        title: "Notation",
                        figure: .yams,
                        rule: $notation.ruleYams,
                        onModeChanged: { resetHelp(for: .yams) }
                    )
                    ExtraYamsBonusBlock(
                        mode: Binding(
                            get: { notation.extraYamsBonusMode },
                            set: { notation.extraYamsBonusMode = $0 }
                        ),
                        value: $notation.extraYamsBonusValue
                    )

                    if notation.extraYamsBonusMode != .disabled {
                        helpField("Prime Yams supplémentaire", key: .extraYams)
                    }
                }

                DisclosureGroup("Aide générale") {
                    helpField("Aide de la section basse", key: .sectionBottom)
                }
            } else {
                disabledSectionLabel
            }
        } header: {
            sectionHeader(
                "Section basse",
                isOn: visibilityBinding(\.bottomSectionEnabled)
            )
        } footer: {
            Text("Au moins une section ou une ligne de score doit rester active.")
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String, isOn: Binding<Bool>) -> some View {
        HStack {
            Text(title)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
        }
    }

    private var disabledSectionLabel: some View {
        Text("Section désactivée")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private func resetHelp(for key: ScoreHelpKey) {
        notation.setHelpText("", for: key)
    }

    private func helpBinding(for key: ScoreHelpKey) -> Binding<String> {
        Binding(
            get: { notation.helpTextValue(for: key) },
            set: { notation.setHelpText($0, for: key) }
        )
    }

    private func helpField(_ title: String, key: ScoreHelpKey) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(
                "Texte d’aide (optionnel)",
                text: helpBinding(for: key),
                axis: .vertical
            )
            .lineLimit(2...4)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func bottomRule<Content: View>(
        _ title: String,
        isOn: Binding<Bool>,
        helpKey: ScoreHelpKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(title, isOn: isOn)

            if isOn.wrappedValue {
                content()
                    .padding(.leading, 4)

                helpField("Aide", key: helpKey)
                    .padding(.leading, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 2)
        .animation(.default, value: isOn.wrappedValue)
    }

    private func hasAtLeastOneScore(
        visibility: NotationVisibility,
        chanceEnabled: Bool,
        smallStraightEnabled: Bool
    ) -> Bool {
        if visibility.upperSectionEnabled || visibility.middleSectionEnabled {
            return true
        }
        guard visibility.bottomSectionEnabled else { return false }
        return visibility.brelanEnabled
            || chanceEnabled
            || visibility.fullEnabled
            || visibility.suiteEnabled
            || smallStraightEnabled
            || visibility.carreEnabled
            || visibility.yamsEnabled
    }

    private func visibilityBinding(
        _ keyPath: WritableKeyPath<NotationVisibility, Bool>
    ) -> Binding<Bool> {
        Binding(
            get: { notation.visibility[keyPath: keyPath] },
            set: { newValue in
                var candidate = notation.visibility
                candidate[keyPath: keyPath] = newValue
                guard hasAtLeastOneScore(
                    visibility: candidate,
                    chanceEnabled: notation.isChanceEnabled,
                    smallStraightEnabled: notation.isSmallStraightEnabled
                ) else { return }
                notation.visibility = candidate
            }
        )
    }

    private var chanceBinding: Binding<Bool> {
        Binding(
            get: { notation.isChanceEnabled },
            set: { newValue in
                guard hasAtLeastOneScore(
                    visibility: notation.visibility,
                    chanceEnabled: newValue,
                    smallStraightEnabled: notation.isSmallStraightEnabled
                ) else { return }
                notation.isChanceEnabled = newValue
            }
        )
    }

    private var smallStraightBinding: Binding<Bool> {
        Binding(
            get: { notation.isSmallStraightEnabled },
            set: { newValue in
                guard hasAtLeastOneScore(
                    visibility: notation.visibility,
                    chanceEnabled: notation.isChanceEnabled,
                    smallStraightEnabled: newValue
                ) else { return }
                notation.isSmallStraightEnabled = newValue
            }
        )
    }
}

struct ScorecardAppearanceEditor: View {
    @Bindable var notation: Notation

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var photoError: String?

    private var appearance: ScorecardAppearance {
        notation.scorecardAppearance
    }

    var body: some View {
        Group {
            Picker("Type de fond", selection: modeBinding) {
                ForEach(ScorecardBackgroundMode.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            switch appearance.mode {
            case .standard:
                Text("Utilise le fond habituel de l’application.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

            case .color:
                ColorPicker(
                    "Couleur du fond",
                    selection: colorBinding,
                    supportsOpacity: false
                )
                appearancePreview
                intensityControl

            case .photo:
                appearancePreview

                HStack {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label(
                            appearance.imageData == nil ? "Choisir une photo" : "Changer la photo",
                            systemImage: "photo.on.rectangle"
                        )
                    }

                    if appearance.imageData != nil {
                        Spacer()
                        Button("Retirer", role: .destructive) {
                            updateAppearance { $0.imageData = nil }
                        }
                    }
                }

                if isLoadingPhoto {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Préparation de l’image…")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                if let photoError {
                    Text(photoError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                intensityControl
            }
        }
        .onChange(of: selectedPhoto) { _, newPhoto in
            guard let newPhoto else { return }
            isLoadingPhoto = true
            photoError = nil

            Task { @MainActor in
                defer { isLoadingPhoto = false }
                guard let sourceData = try? await newPhoto.loadTransferable(type: Data.self),
                      let optimizedData = Self.optimizedImageData(from: sourceData) else {
                    photoError = "Cette image n’a pas pu être utilisée."
                    return
                }
                updateAppearance { appearance in
                    appearance.imageData = optimizedData
                    appearance.mode = .photo
                }
            }
        }
    }

    private var modeBinding: Binding<ScorecardBackgroundMode> {
        Binding(
            get: { appearance.mode },
            set: { newMode in
                updateAppearance { value in
                    value.mode = newMode
                    if newMode == .standard {
                        value.imageData = nil
                        value.colorData = nil
                    }
                }
            }
        )
    }

    private var colorBinding: Binding<Color> {
        Binding(
            get: { appearance.color },
            set: { newColor in
                updateAppearance { $0.color = newColor }
            }
        )
    }

    private var intensityBinding: Binding<Double> {
        Binding(
            get: { appearance.normalizedIntensity },
            set: { newValue in
                updateAppearance { $0.intensity = newValue }
            }
        )
    }

    private var intensityControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Intensité du fond")
            Slider(value: intensityBinding, in: 0.05...1.00, step: 0.05)
            Text("Une intensité modérée conserve les scores faciles à lire.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var appearancePreview: some View {
        ZStack {
            Color(uiColor: .systemBackground)

            switch appearance.mode {
            case .standard:
                EmptyView()
            case .color:
                appearance.color
                    .opacity(appearance.normalizedIntensity)
            case .photo:
                if let data = appearance.imageData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .overlay {
                            Color(uiColor: .systemBackground)
                                .opacity(1 - appearance.normalizedIntensity)
                        }
                } else {
                    ContentUnavailableView(
                        "Aucune photo",
                        systemImage: "photo",
                        description: Text("Choisissez une image dans votre photothèque.")
                    )
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.quaternary, lineWidth: 1)
        }
        .clipped()
    }

    private func updateAppearance(_ update: (inout ScorecardAppearance) -> Void) {
        var value = notation.scorecardAppearance
        update(&value)
        notation.scorecardAppearance = value
    }

    private static func optimizedImageData(from data: Data) -> Data? {
        guard let source = UIImage(data: data) else { return nil }

        let maximumDimension: CGFloat = 1_600
        let sourceSize = source.size
        let largestDimension = max(sourceSize.width, sourceSize.height)
        let scale = largestDimension > maximumDimension
            ? maximumDimension / largestDimension
            : 1
        let targetSize = CGSize(
            width: max(1, sourceSize.width * scale),
            height: max(1, sourceSize.height * scale)
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let rendered = UIGraphicsImageRenderer(size: targetSize, format: format).image { _ in
            UIColor.systemBackground.setFill()
            UIBezierPath(rect: CGRect(origin: .zero, size: targetSize)).fill()
            source.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        for quality in [0.78, 0.65, 0.52] {
            if let compressed = rendered.jpegData(compressionQuality: quality),
               compressed.count <= 1_500_000 {
                return compressed
            }
        }
        return rendered.jpegData(compressionQuality: 0.45)
    }
}

/// Contrôle numérique homogène : les boutons permettent un ajustement rapide,
/// tandis qu'un toucher sur la valeur ouvre directement le clavier numérique.
struct NotationNumberControl: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        HStack(spacing: 0) {
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 42, height: 36)
            }
            .disabled(value <= range.lowerBound)

            Divider()
                .frame(height: 24)

            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.body.monospacedDigit())
                .frame(width: 58, height: 36)

            Divider()
                .frame(height: 24)

            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 42, height: 36)
            }
            .disabled(value >= range.upperBound)
        }
        .buttonStyle(.plain)
        .background(Color(uiColor: .secondarySystemFill))
        .clipShape(Capsule())
        .onChange(of: value) { _, newValue in
            let clamped = min(max(newValue, range.lowerBound), range.upperBound)
            if clamped != newValue {
                value = clamped
            }
        }
    }
}

struct NotationNumberRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step: Int = 1

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
            Spacer(minLength: 8)
            NotationNumberControl(value: $value, range: range, step: step)
        }
    }
}

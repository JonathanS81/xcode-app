import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DataTransferView: View {
    @Query(sort: \Player.name) private var players: [Player]
    @Query(sort: \Game.createdAt, order: .reverse) private var games: [Game]
    @Query(sort: \Notation.name) private var notations: [Notation]
    @Query private var settings: [AppSettings]

    @StateObject private var exportCoordinator = YamSheetExportCoordinator()
    @State private var showingImporter = false
    @State private var pendingImport: YamSheetBackupArchive?
    @State private var transferAlert: DataTransferAlert?

    var body: some View {
        Form {
            Section {
                Text(
                    "Le PDF sert à consulter ou partager les données. Le format .yamsheet sert à les sauvegarder puis à les réimporter dans YamSheet."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section("Exporter") {
                NavigationLink {
                    PlayerDataExportView()
                } label: {
                    exportRow(
                        title: "Joueurs",
                        detail: "Fiches, statistiques et historique d’un ou plusieurs joueurs, en PDF ou .yamsheet.",
                        systemImage: "person.2"
                    )
                }
                .disabled(players.isEmpty)

                NavigationLink {
                    GameDataExportView()
                } label: {
                    exportRow(
                        title: "Parties",
                        detail: "Une, plusieurs ou toutes les parties, en PDF ou .yamsheet.",
                        systemImage: "list.bullet.rectangle"
                    )
                }
                .disabled(games.isEmpty)

                NavigationLink {
                    NotationDataExportView()
                } label: {
                    exportRow(
                        title: "Notations",
                        detail: "Une, plusieurs ou toutes les notations, au format .yamsheet.",
                        systemImage: "list.star"
                    )
                }
                .disabled(notations.isEmpty)
            }

            Section("Sauvegarde complète") {
                Button {
                    prepareCompleteBackup()
                } label: {
                    exportRow(
                        title: "Sauvegarder toutes les données",
                        detail: "Tous les joueurs, parties, notations et paramètres dans un fichier .yamsheet.",
                        systemImage: "externaldrive"
                    )
                }
            }

            Section("Importer") {
                Button {
                    showingImporter = true
                } label: {
                    Label(
                        "Choisir un fichier .yamsheet",
                        systemImage: "square.and.arrow.down"
                    )
                }

                Text(
                    "Peuvent être importés des joueurs avec leur historique, des parties, des notations ou une sauvegarde complète. Les joueurs et parties déjà présents restent inchangés ; seuls les éléments absents sont ajoutés."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                Text(
                    "Lors d’une sauvegarde complète, les paramètres et préférences sont appliqués après ta confirmation."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                Label(
                    "Une sauvegarde peut contenir des noms, adresses e-mail, avatars et historiques de parties. Il est recommandé de la conserver dans un emplacement de confiance.",
                    systemImage: "lock.shield"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Données")
        .navigationBarTitleDisplayMode(.inline)
        .yamSheetExporter(exportCoordinator)
        // Certains fournisseurs de fichiers décrivent l’extension personnalisée
        // comme de simples données. Le contenu est ensuite strictement validé.
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.data, .json]
        ) { result in
            switch result {
            case let .success(url):
                openImport(url)
            case let .failure(error):
                if !isCancellation(error) {
                    transferAlert = DataTransferAlert(
                        title: "Import impossible",
                        message: error.localizedDescription
                    )
                }
            }
        }
        .sheet(item: $pendingImport) { archive in
            YamSheetImportPreviewView(archive: archive) { result in
                pendingImport = nil
                switch result {
                case let .success(summary):
                    transferAlert = DataTransferAlert(
                        title: "Import terminé",
                        message: summary.summary
                    )
                case let .failure(error):
                    transferAlert = DataTransferAlert(
                        title: "Import impossible",
                        message: error.localizedDescription
                    )
                }
            }
        }
        .alert(item: $transferAlert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    @ViewBuilder
    private func exportRow(
        title: String,
        detail: String,
        systemImage: String
    ) -> some View {
        Label {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } icon: {
            Image(systemName: systemImage)
                .frame(width: 24)
        }
    }

    private func prepareCompleteBackup() {
        do {
            let archive = try YamSheetBackupService.makeArchive(
                scope: .full,
                players: players,
                games: games,
                notations: notations,
                settings: settings.first
            )
            exportCoordinator.start([
                try .backup(
                    archive,
                    filename: exportFilename(type: "Sauvegarde-complete")
                )
            ])
        } catch {
            transferAlert = DataTransferAlert(
                title: "Export impossible",
                message: error.localizedDescription
            )
        }
    }

    private func openImport(_ url: URL) {
        let canAccess = url.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            guard ["yamsheet", "json"].contains(url.pathExtension.lowercased()) else {
                throw YamSheetBackupError.invalidContent(
                    "sélectionne un fichier dont l’extension est .yamsheet"
                )
            }
            let data = try Data(contentsOf: url)
            let archive = try YamSheetBackupCoding.decode(data)
            try YamSheetBackupValidator.validate(archive)
            pendingImport = archive
        } catch {
            transferAlert = DataTransferAlert(
                title: "Sauvegarde invalide",
                message: error.localizedDescription
            )
        }
    }
}

private struct PlayerDataExportView: View {
    @Query(sort: \Player.nickname) private var players: [Player]
    @Query(sort: \Game.createdAt, order: .reverse) private var games: [Game]

    @StateObject private var exportCoordinator = YamSheetExportCoordinator()
    @State private var selectedIDs: Set<UUID> = []
    @State private var format: YamSheetShareExportFormat = .pdf
    @State private var exportError: DataTransferAlert?

    private var selectedPlayers: [Player] {
        players.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        List {
            formatSection

            Section {
                selectionAllRow(
                    title: "Tous les joueurs",
                    isSelected: selectedIDs.count == players.count && !players.isEmpty
                ) {
                    if selectedIDs.count == players.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(players.map(\.id))
                    }
                }

                ForEach(players) { player in
                    selectionRow(
                        title: player.displayName,
                        subtitle: nil,
                        isSelected: selectedIDs.contains(player.id)
                    ) {
                        toggle(player.id, in: &selectedIDs)
                    }
                }
            } header: {
                Text("Joueurs — \(selectedIDs.count) sélectionné(s)")
            }
        }
        .navigationTitle("Exporter les joueurs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Exporter") {
                    prepareExport()
                }
                .disabled(selectedIDs.isEmpty)
            }
        }
        .yamSheetExporter(exportCoordinator)
        .alert(item: $exportError) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var formatSection: some View {
        Section("Format") {
            Picker("Format", selection: $format) {
                ForEach(YamSheetShareExportFormat.allCases) { format in
                    Text(format.title).tag(format)
                }
            }
            .pickerStyle(.segmented)

            Text(format.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func prepareExport() {
        do {
            let baseName = exportFilename(
                type: selectedPlayers.count == 1
                    ? "Joueur-\(safeFilename(selectedPlayers[0].displayName))"
                    : "Joueurs-\(selectedPlayers.count)"
            )
            var files: [YamSheetPreparedExport] = []

            if format.includesPDF {
                files.append(
                    .pdf(
                        YamSheetPDFExportService.playersReport(
                            players: selectedPlayers,
                            allPlayers: players,
                            games: games
                        ),
                        filename: baseName
                    )
                )
            }
            if format.includesBackup {
                let archive = try YamSheetBackupService.makeArchive(
                    scope: .players,
                    players: players,
                    games: games,
                    notations: [],
                    settings: nil,
                    selectedPlayerIDs: selectedIDs
                )
                files.append(try .backup(archive, filename: baseName))
            }
            exportCoordinator.start(files)
        } catch {
            exportError = DataTransferAlert(
                title: "Export impossible",
                message: error.localizedDescription
            )
        }
    }
}

private struct GameDataExportView: View {
    @Query(sort: \Player.nickname) private var players: [Player]
    @Query(sort: \Game.createdAt, order: .reverse) private var games: [Game]

    @StateObject private var exportCoordinator = YamSheetExportCoordinator()
    @State private var selectedIDs: Set<UUID> = []
    @State private var format: YamSheetShareExportFormat = .pdf
    @State private var searchText = ""
    @State private var exportError: DataTransferAlert?

    private var playersByID: [UUID: Player] {
        Dictionary(uniqueKeysWithValues: players.map { ($0.id, $0) })
    }

    private var filteredGames: [Game] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return games }

        return games.filter { game in
            game.name.localizedCaseInsensitiveContains(query)
                || game.participantIDs.contains { id in
                    playersByID[id]?.displayName.localizedCaseInsensitiveContains(query)
                        == true
                }
        }
    }

    private var selectedGames: [Game] {
        games.filter { selectedIDs.contains($0.id) }
    }

    var body: some View {
        List {
            Section("Format") {
                Picker("Format", selection: $format) {
                    ForEach(YamSheetShareExportFormat.allCases) { format in
                        Text(format.title).tag(format)
                    }
                }
                .pickerStyle(.segmented)

                Text(format.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                selectionAllRow(
                    title: "Toutes les parties",
                    isSelected: selectedIDs.count == games.count && !games.isEmpty
                ) {
                    if selectedIDs.count == games.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(games.map(\.id))
                    }
                }

                ForEach(filteredGames) { game in
                    selectionRow(
                        title: game.name.isEmpty ? "Partie sans nom" : game.name,
                        subtitle: gameSubtitle(game),
                        isSelected: selectedIDs.contains(game.id)
                    ) {
                        toggle(game.id, in: &selectedIDs)
                    }
                }
            } header: {
                Text("Parties — \(selectedIDs.count) sélectionnée(s)")
            }
        }
        .searchable(text: $searchText, prompt: "Partie ou joueur")
        .navigationTitle("Exporter les parties")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Exporter") {
                    prepareExport()
                }
                .disabled(selectedIDs.isEmpty)
            }
        }
        .yamSheetExporter(exportCoordinator)
        .alert(item: $exportError) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func gameSubtitle(_ game: Game) -> String {
        let names = game.participantIDs.compactMap {
            playersByID[$0]?.displayName
        }
        let participants = names.isEmpty
            ? "Aucun joueur"
            : names.joined(separator: ", ")
        return "\(game.createdAt.formatted(date: .abbreviated, time: .omitted)) · \(participants)"
    }

    private func prepareExport() {
        do {
            let baseName = exportFilename(
                type: selectedGames.count == 1
                    ? "Partie-\(safeFilename(selectedGames[0].name))"
                    : "Parties-\(selectedGames.count)"
            )
            var files: [YamSheetPreparedExport] = []

            if format.includesPDF {
                files.append(
                    .pdf(
                        YamSheetPDFExportService.gamesReport(
                            games: selectedGames,
                            allGames: games,
                            players: players
                        ),
                        filename: baseName
                    )
                )
            }
            if format.includesBackup {
                let archive = try YamSheetBackupService.makeArchive(
                    scope: .games,
                    players: players,
                    games: selectedGames,
                    notations: [],
                    settings: nil
                )
                files.append(try .backup(archive, filename: baseName))
            }
            exportCoordinator.start(files)
        } catch {
            exportError = DataTransferAlert(
                title: "Export impossible",
                message: error.localizedDescription
            )
        }
    }
}

private struct NotationDataExportView: View {
    @Query(sort: \Notation.name) private var notations: [Notation]

    @StateObject private var exportCoordinator = YamSheetExportCoordinator()
    @State private var selectedIDs: Set<ObjectIdentifier> = []
    @State private var exportError: DataTransferAlert?

    private var selectedNotations: [Notation] {
        notations.filter { selectedIDs.contains(ObjectIdentifier($0)) }
    }

    var body: some View {
        List {
            Section {
                Text(
                    "Les notations sont exportées au format .yamsheet afin de pouvoir être réimportées."
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }

            Section {
                selectionAllRow(
                    title: "Toutes les notations",
                    isSelected: selectedIDs.count == notations.count && !notations.isEmpty
                ) {
                    if selectedIDs.count == notations.count {
                        selectedIDs.removeAll()
                    } else {
                        selectedIDs = Set(notations.map(ObjectIdentifier.init))
                    }
                }

                ForEach(notations) { notation in
                    let id = ObjectIdentifier(notation)
                    selectionRow(
                        title: notation.name,
                        subtitle: nil,
                        isSelected: selectedIDs.contains(id)
                    ) {
                        toggle(id, in: &selectedIDs)
                    }
                }
            } header: {
                Text("Notations — \(selectedIDs.count) sélectionnée(s)")
            }
        }
        .navigationTitle("Exporter les notations")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Exporter") {
                    prepareExport()
                }
                .disabled(selectedIDs.isEmpty)
            }
        }
        .yamSheetExporter(exportCoordinator)
        .alert(item: $exportError) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private func prepareExport() {
        do {
            let baseName = exportFilename(
                type: selectedNotations.count == 1
                    ? "Notation-\(safeFilename(selectedNotations[0].name))"
                    : "Notations-\(selectedNotations.count)"
            )
            let archive = try YamSheetBackupService.makeArchive(
                scope: .notations,
                players: [],
                games: [],
                notations: selectedNotations,
                settings: nil
            )
            exportCoordinator.start([
                try .backup(archive, filename: baseName)
            ])
        } catch {
            exportError = DataTransferAlert(
                title: "Export impossible",
                message: error.localizedDescription
            )
        }
    }
}

private enum YamSheetShareExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case backup
    case both

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf: return "PDF"
        case .backup: return "YamSheet"
        case .both: return "Les deux"
        }
    }

    var detail: String {
        switch self {
        case .pdf:
            return "Document lisible, adapté à la consultation et au partage."
        case .backup:
            return "Sauvegarde réimportable dans YamSheet."
        case .both:
            return "Deux fichiers seront enregistrés successivement : un PDF puis une sauvegarde .yamsheet."
        }
    }

    var includesPDF: Bool {
        self == .pdf || self == .both
    }

    var includesBackup: Bool {
        self == .backup || self == .both
    }
}

private struct YamSheetPreparedExport {
    let data: Data
    let contentType: UTType
    let filename: String

    static func pdf(_ data: Data, filename: String) -> Self {
        Self(
            data: data,
            contentType: .pdf,
            filename: filename + ".pdf"
        )
    }

    static func backup(
        _ archive: YamSheetBackupArchive,
        filename: String
    ) throws -> Self {
        Self(
            data: try YamSheetBackupCoding.encode(archive),
            contentType: .yamSheetBackup,
            filename: filename + ".yamsheet"
        )
    }
}

@MainActor
private final class YamSheetExportCoordinator: ObservableObject {
    @Published var document: YamSheetDataDocument?
    @Published var contentType: UTType = .data
    @Published var filename = "Export YamSheet"
    @Published var isPresented = false
    @Published var alert: DataTransferAlert?

    private var pending: [YamSheetPreparedExport] = []
    private var exportedCount = 0

    func start(_ files: [YamSheetPreparedExport]) {
        guard !files.isEmpty else { return }
        pending = files
        exportedCount = 0
        presentNext()
    }

    func handle(_ result: Result<URL, Error>) {
        document = nil

        switch result {
        case .success:
            exportedCount += 1
            if pending.isEmpty {
                alert = DataTransferAlert(
                    title: "Export terminé",
                    message: exportedCount == 1
                        ? "Le fichier a bien été créé."
                        : "Les \(exportedCount) fichiers ont bien été créés."
                )
            } else {
                DispatchQueue.main.async { [weak self] in
                    self?.presentNext()
                }
            }
        case let .failure(error):
            pending.removeAll()
            if !isCancellation(error) {
                alert = DataTransferAlert(
                    title: "Échec de l’export",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func presentNext() {
        guard !pending.isEmpty else { return }
        let next = pending.removeFirst()
        contentType = next.contentType
        filename = next.filename
        document = YamSheetDataDocument(data: next.data)
        isPresented = true
    }
}

private struct YamSheetExporterModifier: ViewModifier {
    @ObservedObject var coordinator: YamSheetExportCoordinator

    func body(content: Content) -> some View {
        content
            .fileExporter(
                isPresented: $coordinator.isPresented,
                document: coordinator.document,
                contentType: coordinator.contentType,
                defaultFilename: coordinator.filename
            ) { result in
                coordinator.handle(result)
            }
            .alert(item: $coordinator.alert) { alert in
                Alert(
                    title: Text(alert.title),
                    message: Text(alert.message),
                    dismissButton: .default(Text("OK"))
                )
            }
    }
}

private extension View {
    func yamSheetExporter(
        _ coordinator: YamSheetExportCoordinator
    ) -> some View {
        modifier(YamSheetExporterModifier(coordinator: coordinator))
    }
}

@ViewBuilder
private func selectionAllRow(
    title: String,
    isSelected: Bool,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        HStack {
            Text(title)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }
}

@ViewBuilder
private func selectionRow(
    title: String,
    subtitle: String?,
    isSelected: Bool,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .foregroundStyle(.primary)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
        }
    }
}

private func toggle<ID: Hashable>(_ id: ID, in selection: inout Set<ID>) {
    if selection.contains(id) {
        selection.remove(id)
    } else {
        selection.insert(id)
    }
}

private func exportFilename(type: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "fr_FR")
    formatter.dateFormat = "yyyy-MM-dd"
    return "YamSheet-\(type)-\(formatter.string(from: Date()))"
}

private func safeFilename(_ value: String) -> String {
    let invalid = CharacterSet.alphanumerics
        .union(CharacterSet(charactersIn: "-_"))
        .inverted
    let cleaned = value
        .components(separatedBy: invalid)
        .filter { !$0.isEmpty }
        .joined(separator: "-")
    return cleaned.isEmpty ? "Sans-nom" : cleaned
}

private func isCancellation(_ error: Error) -> Bool {
    let nsError = error as NSError
    return nsError.domain == NSCocoaErrorDomain
        && nsError.code == NSUserCancelledError
}

private struct YamSheetImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let archive: YamSheetBackupArchive
    let onCompletion: (Result<YamSheetImportResult, Error>) -> Void

    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                Section("Sauvegarde sélectionnée") {
                    LabeledContent("Type", value: archive.metadata.scope.title)
                    LabeledContent(
                        "Créée le",
                        value: archive.metadata.exportedAt.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    LabeledContent(
                        "Version source",
                        value: "\(archive.metadata.sourceAppVersion) (\(archive.metadata.sourceBuild))"
                    )
                }

                Section("Contenu") {
                    LabeledContent("Joueurs", value: "\(archive.players.count)")
                    LabeledContent("Parties", value: "\(archive.games.count)")
                    LabeledContent("Notations", value: "\(archive.notations.count)")
                    if !archive.playerStatistics.isEmpty {
                        LabeledContent(
                            "Statistiques individuelles",
                            value: "\(archive.playerStatistics.count)"
                        )
                    }
                    if archive.settings != nil {
                        LabeledContent("Paramètres", value: "Inclus")
                    }
                }

                Section("Méthode d’import") {
                    Text(
                        "Les parties sont reconnues grâce à leur identifiant. Un joueur est reconnu par son identifiant ou, à défaut, par son adresse e-mail ou par la combinaison nom et pseudo. Les éléments déjà présents sont conservés et ne sont pas importés une seconde fois."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }

                if archive.metadata.scope == .players {
                    Section {
                        Label(
                            "Les fiches sélectionnées, leur historique de parties et les adversaires nécessaires seront importés. Si un joueur est déjà reconnu, sa fiche locale est conservée et les parties absentes lui sont rattachées.",
                            systemImage: "info.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Confirmer l’import")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") {
                        dismiss()
                    }
                    .disabled(isImporting)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Importer") {
                        performImport()
                    }
                    .disabled(isImporting)
                }
            }
            .overlay {
                if isImporting {
                    ProgressView("Import en cours…")
                        .padding()
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
            }
        }
    }

    private func performImport() {
        isImporting = true
        do {
            let result = try YamSheetBackupService.importArchive(
                archive,
                into: context
            )
            onCompletion(.success(result))
        } catch {
            onCompletion(.failure(error))
        }
        isImporting = false
        dismiss()
    }
}

private struct DataTransferAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

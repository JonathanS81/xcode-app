import Foundation
import SwiftData

/// Helper to encode/decode arrays & dicts as Data JSON
fileprivate func encodeJSON<T: Encodable>(_ value: T) -> Data {
    (try? JSONEncoder().encode(value)) ?? Data()
}

@Model
final class Scorecard: Identifiable {
    var id: UUID
    var playerID: UUID
    var columns: Int

    // --------- Compat rétro : ancien nom éventuel du tableau de primes Yams ---------
    // Dans certaines bases plus anciennes, le champ s'appelait `extraYams`.
    // On l’expose en optionnel pour que SwiftData puisse ouvrir l’ancienne DB.
    @Attribute(originalName: "extraYams")
    var legacy_extraYams: [Bool]?     // <— lu si présent dans le store ancien

    // Champ actuel utilisé par le code
    var extraYamsAwarded: [Bool] = []

    // Déclarations ajoutées après la première version de l'app.
    // Les champs optionnels permettent d'ouvrir les anciennes bases SwiftData sans migration destructive.
    var declaredYamsData: Data?
    var extraYamsSourceData: Data?
    var extraYamsAwardsData: Data?

    @Relationship(deleteRule: .nullify, inverse: \Game.scorecards) var game: Game?

    // Stored as Data (JSON)
    var onesData: Data
    var twosData: Data
    var threesData: Data
    var foursData: Data
    var fivesData: Data
    var sixesData: Data

    var maxValsData: Data
    var minValsData: Data

    var brelanData: Data
    var chanceData: Data
    var fullData: Data
    var carreData: Data
    var yamsData: Data

    var suiteData: Data            // grande suite (1–5 ou 2–6) : 0 / 15 / 20
    var petiteSuiteData: Data      // petite suite (si activée) : 0 / score paramétré

    var locksData: Data

    private func decoded<Value: Decodable>(
        _ type: Value.Type,
        field: String,
        from data: Data
    ) -> Value? {
        JSONDecodingCache.shared.decode(
            type,
            namespace: "Scorecard",
            ownerID: id,
            field: field,
            from: data
        )
    }

    private func encoded<Value: Encodable>(
        _ value: Value,
        field: String
    ) -> Data {
        let data = encodeJSON(value)
        JSONDecodingCache.shared.store(
            value,
            namespace: "Scorecard",
            ownerID: id,
            field: field,
            source: data
        )
        return data
    }

    init(playerID: UUID, columns: Int) {
        self.id = UUID()
        self.playerID = playerID
        self.columns = columns

        func initArray() -> Data { encodeJSON(Array(repeating: -1, count: columns)) }
        self.onesData = initArray()
        self.twosData = initArray()
        self.threesData = initArray()
        self.foursData = initArray()
        self.fivesData = initArray()
        self.sixesData = initArray()

        self.maxValsData = initArray()
        self.minValsData = initArray()

        self.brelanData = initArray()
        self.chanceData = initArray()
        self.fullData = initArray()
        self.carreData = initArray()
        self.yamsData = initArray()

        self.suiteData = initArray()
        self.petiteSuiteData = initArray()
        self.extraYamsAwarded = Array(repeating: false, count: columns)
        self.declaredYamsData = nil
        self.extraYamsSourceData = nil
        self.extraYamsAwardsData = nil
        self.locksData = encodeJSON([String: Bool]())
    }

    // Computed properties
    var ones: [Int] {
        get { decoded([Int].self, field: "ones", from: onesData) ?? [] }
        set { onesData = encoded(newValue, field: "ones") }
    }
    var twos: [Int] {
        get { decoded([Int].self, field: "twos", from: twosData) ?? [] }
        set { twosData = encoded(newValue, field: "twos") }
    }
    var threes: [Int] {
        get { decoded([Int].self, field: "threes", from: threesData) ?? [] }
        set { threesData = encoded(newValue, field: "threes") }
    }
    var fours: [Int] {
        get { decoded([Int].self, field: "fours", from: foursData) ?? [] }
        set { foursData = encoded(newValue, field: "fours") }
    }
    var fives: [Int] {
        get { decoded([Int].self, field: "fives", from: fivesData) ?? [] }
        set { fivesData = encoded(newValue, field: "fives") }
    }
    var sixes: [Int] {
        get { decoded([Int].self, field: "sixes", from: sixesData) ?? [] }
        set { sixesData = encoded(newValue, field: "sixes") }
    }

    var maxVals: [Int] {
        get { decoded([Int].self, field: "max", from: maxValsData) ?? [] }
        set { maxValsData = encoded(newValue, field: "max") }
    }
    var minVals: [Int] {
        get { decoded([Int].self, field: "min", from: minValsData) ?? [] }
        set { minValsData = encoded(newValue, field: "min") }
    }

    var brelan: [Int] {
        get { decoded([Int].self, field: "brelan", from: brelanData) ?? [] }
        set { brelanData = encoded(newValue, field: "brelan") }
    }
    var chance: [Int] {
        get { decoded([Int].self, field: "chance", from: chanceData) ?? [] }
        set { chanceData = encoded(newValue, field: "chance") }
    }
    var full: [Int] {
        get { decoded([Int].self, field: "full", from: fullData) ?? [] }
        set { fullData = encoded(newValue, field: "full") }
    }
    var carre: [Int] {
        get { decoded([Int].self, field: "carre", from: carreData) ?? [] }
        set { carreData = encoded(newValue, field: "carre") }
    }
    var yams: [Int] {
        get { decoded([Int].self, field: "yams", from: yamsData) ?? [] }
        set { yamsData = encoded(newValue, field: "yams") }
    }

    var suite: [Int] {
        get { decoded([Int].self, field: "suite", from: suiteData) ?? [] }
        set { suiteData = encoded(newValue, field: "suite") }
    }

    var petiteSuite: [Int] {
        get {
            decoded(
                [Int].self,
                field: "petiteSuite",
                from: petiteSuiteData
            ) ?? []
        }
        set { petiteSuiteData = encoded(newValue, field: "petiteSuite") }
    }

    var locks: [String: Bool] {
        get {
            decoded(
                [String: Bool].self,
                field: "locks",
                from: locksData
            ) ?? [:]
        }
        set { locksData = encoded(newValue, field: "locks") }
    }

    /// Cases hors ligne Yams explicitement déclarées comme provenant de cinq dés identiques.
    /// Clé stockée : "<colonne>.<catégorie>".
    var declaredYams: [String: Bool] {
        get {
            guard let data = declaredYamsData else { return [:] }
            return decoded(
                [String: Bool].self,
                field: "declaredYams",
                from: data
            ) ?? [:]
        }
        set {
            declaredYamsData = encoded(
                newValue,
                field: "declaredYams"
            )
        }
    }

    /// Catégorie du score auquel une prime est rattachée, indexée par colonne.
    /// Ce lien empêche de compter deux fois un lancer à la fois déclaré et primé.
    var extraYamsSources: [String: String] {
        get {
            guard let data = extraYamsSourceData else { return [:] }
            return decoded(
                [String: String].self,
                field: "extraYamsSources",
                from: data
            ) ?? [:]
        }
        set {
            extraYamsSourceData = encoded(
                newValue,
                field: "extraYamsSources"
            )
        }
    }

    /// Sources des primes attribuées, regroupées par colonne.
    /// Une source correspond à la catégorie remplie pendant le lancer primé.
    var extraYamsAwards: [String: [String]] {
        get {
            guard let data = extraYamsAwardsData else { return [:] }
            return decoded(
                [String: [String]].self,
                field: "extraYamsAwards",
                from: data
            ) ?? [:]
        }
        set {
            extraYamsAwardsData = encoded(
                newValue,
                field: "extraYamsAwards"
            )
        }
    }

    // Helpers
    func isLocked(col: Int, key: String) -> Bool {
        locks["\(col).\(key)"] ?? false
    }
    func setLocked(_ value: Bool, col: Int, key: String) {
        var l = locks
        l["\(col).\(key)"] = value
        locks = l
    }

    func isDeclaredYams(col: Int, key: String) -> Bool {
        declaredYams["\(col).\(key)"] ?? false
    }

    func setDeclaredYams(_ value: Bool, col: Int, key: String) {
        var values = declaredYams
        values["\(col).\(key)"] = value
        declaredYams = values
    }

    func extraYamsSource(col: Int) -> String? {
        extraYamsSources[String(col)]
    }

    func setExtraYamsSource(_ key: String?, col: Int) {
        var values = extraYamsSources
        values[String(col)] = key
        extraYamsSources = values
    }

    func extraYamsAwardSources(col: Int) -> [String] {
        let columnKey = String(col)
        if let stored = extraYamsAwards[columnKey] {
            return stored
        }

        let hasLegacyAward = extraYamsAwarded.indices.contains(col)
            && extraYamsAwarded[col]
        guard hasLegacyAward else { return [] }
        return [extraYamsSource(col: col) ?? "__legacy__"]
    }

    func extraYamsAwardsCount(col: Int) -> Int {
        extraYamsAwardSources(col: col).count
    }

    func hasExtraYamsAward(col: Int, source: String) -> Bool {
        extraYamsAwardSources(col: col).contains(source)
    }

    func addExtraYamsAward(col: Int, source: String) {
        var values = extraYamsAwards
        var sources = extraYamsAwardSources(col: col)
        guard !sources.contains(source) else { return }
        sources.append(source)
        values[String(col)] = sources
        extraYamsAwards = values

        if col >= extraYamsAwarded.count {
            extraYamsAwarded.append(contentsOf:
                Array(repeating: false, count: col - extraYamsAwarded.count + 1)
            )
        }
        extraYamsAwarded[col] = true
    }

    func removeExtraYamsAward(col: Int, source: String? = nil) {
        var values = extraYamsAwards
        var sources = extraYamsAwardSources(col: col)
        if let source {
            sources.removeAll { $0 == source }
        } else if !sources.isEmpty {
            sources.removeLast()
        }
        values[String(col)] = sources
        extraYamsAwards = values

        if extraYamsAwarded.indices.contains(col) {
            extraYamsAwarded[col] = !sources.isEmpty
        }
        if sources.isEmpty {
            setExtraYamsSource(nil, col: col)
        }
    }

    // MARK: - Computed score (accès facile pour les vues)
    func computeTotal(using game: Game) -> Int {
        StatsService.total(for: self, game: game, col: 0)
    }
}

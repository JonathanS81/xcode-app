import Foundation
import SwiftData

/// Helper to encode/decode arrays & dicts as Data JSON
fileprivate func encodeJSON<T: Encodable>(_ value: T) -> Data {
    (try? JSONEncoder().encode(value)) ?? Data()
}
fileprivate func decodeJSON<T: Decodable>(_ type: T.Type, from data: Data) -> T {
    (try? JSONDecoder().decode(type, from: data)) ?? (T.self == [Int].self ? [] as! T : (T.self == [String: Bool].self ? [:] as! T : T.self as! T))
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

        self.locksData = encodeJSON([String: Bool]())
    }

    // Computed properties
    var ones: [Int] {
        get { decodeJSON([Int].self, from: onesData) }
        set { onesData = encodeJSON(newValue) }
    }
    var twos: [Int] {
        get { decodeJSON([Int].self, from: twosData) }
        set { twosData = encodeJSON(newValue) }
    }
    var threes: [Int] {
        get { decodeJSON([Int].self, from: threesData) }
        set { threesData = encodeJSON(newValue) }
    }
    var fours: [Int] {
        get { decodeJSON([Int].self, from: foursData) }
        set { foursData = encodeJSON(newValue) }
    }
    var fives: [Int] {
        get { decodeJSON([Int].self, from: fivesData) }
        set { fivesData = encodeJSON(newValue) }
    }
    var sixes: [Int] {
        get { decodeJSON([Int].self, from: sixesData) }
        set { sixesData = encodeJSON(newValue) }
    }

    var maxVals: [Int] {
        get { decodeJSON([Int].self, from: maxValsData) }
        set { maxValsData = encodeJSON(newValue) }
    }
    var minVals: [Int] {
        get { decodeJSON([Int].self, from: minValsData) }
        set { minValsData = encodeJSON(newValue) }
    }

    var brelan: [Int] {
        get { decodeJSON([Int].self, from: brelanData) }
        set { brelanData = encodeJSON(newValue) }
    }
    var chance: [Int] {
        get { decodeJSON([Int].self, from: chanceData) }
        set { chanceData = encodeJSON(newValue) }
    }
    var full: [Int] {
        get { decodeJSON([Int].self, from: fullData) }
        set { fullData = encodeJSON(newValue) }
    }
    var carre: [Int] {
        get { decodeJSON([Int].self, from: carreData) }
        set { carreData = encodeJSON(newValue) }
    }
    var yams: [Int] {
        get { decodeJSON([Int].self, from: yamsData) }
        set { yamsData = encodeJSON(newValue) }
    }

    var suite: [Int] {
        get { decodeJSON([Int].self, from: suiteData) }
        set { suiteData = encodeJSON(newValue) }
    }

    var petiteSuite: [Int] {
        get { decodeJSON([Int].self, from: petiteSuiteData) }
        set { petiteSuiteData = encodeJSON(newValue) }
    }

    var locks: [String: Bool] {
        get { decodeJSON([String: Bool].self, from: locksData) }
        set { locksData = encodeJSON(newValue) }
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
}

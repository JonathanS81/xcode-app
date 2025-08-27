import Foundation

enum ScoreField: String, CaseIterable {
    // upper
    case ones, twos, threes, fours, fives, sixes
    // middle
    case maxVals, minVals
    // bottom
    case brelan, chance, full, carre, yams
}

struct StatsEngine {
    static func normalize(_ v: Int) -> Int { max(0, v) } // -1 becomes 0 without touching model

    static func upperTotalWithValues(_ values: [Int], threshold: Int, bonus: Int) -> Int {
        let base = values.map { normalize($0) }.reduce(0, +)
        return base + (base >= threshold ? bonus : 0)
    }

    static func middleTotalWithValues(maxVals: Int, minVals: Int, mode: MiddleMode, numberOfAces: Int = 0) -> Int {
        let maxV = normalize(maxVals)
        let minV = normalize(minVals)
        switch mode {
        case .disabled:
            return 0
        case .marieAnne:
            return (maxV - minV) * numberOfAces
        case .jon:
            let sum = maxV + minV
            if maxV > minV && sum >= 50 { return sum + 30 }
            return sum
        }
    }

    static func bottomLineValueV2(field: ScoreField, rawValue: Int) -> Int {
        let v = normalize(rawValue)
        switch field {
        case .brelan, .chance:
            return v
        case .full:
            return 30 + v
        case .carre:
            return 40 + v
        case .yams:
            return 50 + v
        default:
            return v
        }
    }
}

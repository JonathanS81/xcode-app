import Foundation

/// Évalue les changements effectués sur la feuille d'un joueur pendant un tour.
/// Une valeur négative représente une case vide.
enum TurnChangePolicy {
    static let maximumChangedCells = 3

    struct Evaluation: Equatable {
        let changedKeys: Set<String>
        let filledDelta: Int

        var canEndTurn: Bool {
            filledDelta == 1
                && !changedKeys.isEmpty
                && changedKeys.count <= TurnChangePolicy.maximumChangedCells
        }

        func canEdit(_ key: String) -> Bool {
            _ = key
            return changedKeys.count < TurnChangePolicy.maximumChangedCells
        }
    }

    static func evaluate(
        start: [String: Int],
        current: [String: Int]
    ) -> Evaluation {
        let keys = Set(start.keys).union(current.keys)
        let changedKeys = Set(keys.filter {
            (start[$0] ?? -1) != (current[$0] ?? -1)
        })
        let startFilled = keys.reduce(0) {
            $0 + ((start[$1] ?? -1) >= 0 ? 1 : 0)
        }
        let currentFilled = keys.reduce(0) {
            $0 + ((current[$1] ?? -1) >= 0 ? 1 : 0)
        }

        return Evaluation(
            changedKeys: changedKeys,
            filledDelta: currentFilled - startFilled
        )
    }
}

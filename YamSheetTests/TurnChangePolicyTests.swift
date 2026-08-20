import XCTest
@testable import YamSheet

final class TurnChangePolicyTests: XCTestCase {
    func testNormalTurnCanEndWithOneNewFilledCell() {
        let result = TurnChangePolicy.evaluate(
            start: ["ones": -1, "twos": -1],
            current: ["ones": 3, "twos": -1]
        )

        XCTAssertTrue(result.canEndTurn)
        XCTAssertEqual(result.changedKeys, ["ones"])
    }

    func testReassigningOnePreviousChoiceAndPlayingUsesThreeChanges() {
        let result = TurnChangePolicy.evaluate(
            start: ["threes": 6, "min": -1, "chance": -1],
            current: ["threes": -1, "min": 14, "chance": 22]
        )

        XCTAssertTrue(result.canEndTurn)
        XCTAssertEqual(result.filledDelta, 1)
        XCTAssertEqual(result.changedKeys, ["threes", "min", "chance"])
        XCTAssertFalse(result.canEdit("yams"))
        XCTAssertFalse(result.canEdit("min"))
    }

    func testFourthChangedCellIsRejected() {
        let result = TurnChangePolicy.evaluate(
            start: ["ones": -1, "twos": -1, "threes": -1, "fours": -1],
            current: ["ones": 1, "twos": 2, "threes": 3, "fours": 4]
        )

        XCTAssertFalse(result.canEndTurn)
        XCTAssertEqual(result.changedKeys.count, 4)
    }

    func testReturningCellToInitialValueFreesAChangeSlot() {
        let result = TurnChangePolicy.evaluate(
            start: ["ones": 1, "twos": -1, "threes": -1],
            current: ["ones": 1, "twos": 4, "threes": -1]
        )

        XCTAssertEqual(result.changedKeys, ["twos"])
        XCTAssertTrue(result.canEdit("threes"))
    }

    func testChangingOnlyAnExistingScoreCannotEndTurn() {
        let result = TurnChangePolicy.evaluate(
            start: ["ones": 1, "twos": -1],
            current: ["ones": 2, "twos": -1]
        )

        XCTAssertFalse(result.canEndTurn)
        XCTAssertEqual(result.filledDelta, 0)
    }
}

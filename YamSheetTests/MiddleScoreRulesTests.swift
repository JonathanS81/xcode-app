import XCTest
@testable import YamSheet

final class MiddleScoreRulesTests: XCTestCase {
    func testMiddleValuesAreNotAdjustedAgainstEachOther() {
        XCTAssertEqual(
            ValidationEngine.sanitizeMiddleMax(
                14,
                currentMin: 18,
                strictGreater: true
            ),
            14
        )
        XCTAssertEqual(
            ValidationEngine.sanitizeMiddleMin(
                18,
                currentMax: 14,
                strictGreater: true
            ),
            18
        )
    }

    func testMiddleValuesOutsideFiveToThirtyAreRejected() {
        XCTAssertEqual(
            ValidationEngine.sanitizeMiddleMax(
                4,
                currentMin: nil,
                strictGreater: false
            ),
            -1
        )
        XCTAssertEqual(
            ValidationEngine.sanitizeMiddleMax(
                31,
                currentMin: nil,
                strictGreater: false
            ),
            -1
        )
        XCTAssertEqual(
            ValidationEngine.sanitizeMiddleMin(
                5,
                currentMax: nil,
                strictGreater: false
            ),
            5
        )
        XCTAssertEqual(
            ValidationEngine.sanitizeMiddleMin(
                30,
                currentMax: nil,
                strictGreater: false
            ),
            30
        )
    }

    func testMultiplierReturnsZeroWhenMaxIsNotGreaterThanMin() {
        XCTAssertEqual(
            StatsEngine.middleScore(
                maxValue: 14,
                minValue: 18,
                aces: 3,
                mode: .multiplier,
                threshold: 50,
                bonus: 30,
                invalidPairMode: .keepSum
            ),
            0
        )
    }

    func testStrictBonusGateReturnsZeroWhenMaxIsNotGreaterThanMin() {
        XCTAssertEqual(
            StatsEngine.middleScore(
                maxValue: 14,
                minValue: 18,
                aces: 3,
                mode: .bonusGate,
                threshold: 50,
                bonus: 30,
                invalidPairMode: .zeroSection
            ),
            0
        )
    }

    func testTolerantBonusGateKeepsSumWithoutBonus() {
        XCTAssertEqual(
            StatsEngine.middleScore(
                maxValue: 25,
                minValue: 25,
                aces: 3,
                mode: .bonusGate,
                threshold: 50,
                bonus: 30,
                invalidPairMode: .keepSum
            ),
            50
        )
    }

    func testValidBonusGateStillAwardsBonus() {
        XCTAssertEqual(
            StatsEngine.middleScore(
                maxValue: 26,
                minValue: 24,
                aces: 3,
                mode: .bonusGate,
                threshold: 50,
                bonus: 30,
                invalidPairMode: .zeroSection
            ),
            80
        )
    }

    func testMiddleBonusAmountIsExposedSeparately() {
        XCTAssertEqual(
            StatsEngine.middleBonusAmount(
                maxValue: 26,
                minValue: 24,
                threshold: 50,
                bonus: 30
            ),
            30
        )
        XCTAssertEqual(
            StatsEngine.middleBonusAmount(
                maxValue: 25,
                minValue: 25,
                threshold: 50,
                bonus: 30
            ),
            0
        )
    }
}

@testable import HappySpeech
import XCTest

// MARK: - DesignSystemTokensTests
//
// Block V v18 — покрытие SpacingTokens, RadiusTokens, MotionTokens (18 тестов).
// Токены тестируются как детерминированные константы — никакого UI.

final class DesignSystemTokensTests: XCTestCase {

    // MARK: - SpacingTokens базовые значения

    func test_spacingMicro_is4() {
        XCTAssertEqual(SpacingTokens.micro, 4.0, accuracy: 0.001)
    }

    func test_spacingTiny_is8() {
        XCTAssertEqual(SpacingTokens.tiny, 8.0, accuracy: 0.001)
    }

    func test_spacingSmall_is12() {
        XCTAssertEqual(SpacingTokens.small, 12.0, accuracy: 0.001)
    }

    func test_spacingRegular_is16() {
        XCTAssertEqual(SpacingTokens.regular, 16.0, accuracy: 0.001)
    }

    func test_spacingScreenEdge_is24() {
        XCTAssertEqual(SpacingTokens.screenEdge, 24.0, accuracy: 0.001)
    }

    func test_spacingCardPad_is20() {
        XCTAssertEqual(SpacingTokens.cardPad, 20.0, accuracy: 0.001)
    }

    func test_spacingSectionGap_is32() {
        XCTAssertEqual(SpacingTokens.sectionGap, 32.0, accuracy: 0.001)
    }

    func test_spacingPageTop_is40() {
        XCTAssertEqual(SpacingTokens.pageTop, 40.0, accuracy: 0.001)
    }

    // MARK: - SpacingTokens алиасы совпадают с числовыми значениями

    func test_spacingAliases_screenEdge_equalsLarge() {
        XCTAssertEqual(SpacingTokens.screenEdge, SpacingTokens.large)
    }

    func test_spacingAliases_cardPad_equalsMedium() {
        XCTAssertEqual(SpacingTokens.cardPad, SpacingTokens.medium)
    }

    func test_spacingAliases_listGap_equalsSmall() {
        XCTAssertEqual(SpacingTokens.listGap, SpacingTokens.small)
    }

    // MARK: - RadiusTokens

    func test_radiusXS_is8() {
        XCTAssertEqual(RadiusTokens.xs, 8.0, accuracy: 0.001)
    }

    func test_radiusCard_is24() {
        XCTAssertEqual(RadiusTokens.card, 24.0, accuracy: 0.001)
    }

    func test_radiusButton_is32() {
        XCTAssertEqual(RadiusTokens.button, 32.0, accuracy: 0.001)
    }

    func test_radiusFull_isLarge() {
        XCTAssertGreaterThanOrEqual(RadiusTokens.full, 999.0)
    }

    func test_radiusButton_equalsSheet() {
        XCTAssertEqual(RadiusTokens.button, RadiusTokens.sheet)
    }

    // MARK: - MotionTokens.Duration

    func test_motionDuration_instant_isShorterThanQuick() {
        XCTAssertLessThan(MotionTokens.Duration.instant, MotionTokens.Duration.quick)
    }

    func test_motionDuration_quick_isShorterThanStandard() {
        XCTAssertLessThan(MotionTokens.Duration.quick, MotionTokens.Duration.standard)
    }

    func test_motionDuration_standard_isShorterThanSlow() {
        XCTAssertLessThan(MotionTokens.Duration.standard, MotionTokens.Duration.slow)
    }

    // MARK: - MotionTokens.spring(reduceMotion:)

    func test_motionSpring_reduceMotionFalse_returnsNonNil() {
        XCTAssertNotNil(MotionTokens.spring(reduceMotion: false))
    }

    func test_motionSpring_reduceMotionTrue_returnsNil() {
        XCTAssertNil(MotionTokens.spring(reduceMotion: true))
    }

    func test_motionBounce_reduceMotionTrue_returnsNil() {
        XCTAssertNil(MotionTokens.bounce(reduceMotion: true))
    }

    func test_motionPage_reduceMotionTrue_returnsNonNil() {
        // reduceMotion == true → linear fallback, не nil
        XCTAssertNotNil(MotionTokens.page(reduceMotion: true))
    }
}

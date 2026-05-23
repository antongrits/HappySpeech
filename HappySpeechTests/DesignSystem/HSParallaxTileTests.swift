@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - HSParallaxTileTests
//
// Step 9 — verifies the pure-geometry offset helper used by
// `HSParallaxTileModifier`. We don't render a SwiftUI ScrollView in unit
// tests; the calculation is encapsulated in `HSParallaxGeometry.offset`
// for testability.

final class HSParallaxTileTests: XCTestCase {

    // MARK: - Centre cases

    func test_tileAtScreenCenter_offsetIsZero() {
        let offset = HSParallaxGeometry.offset(
            tileMidY: 400,
            screenMidY: 400,
            factor: 0.3
        )
        XCTAssertEqual(offset, 0, accuracy: 0.0001)
    }

    func test_factorZero_offsetIsAlwaysZero() {
        let offset = HSParallaxGeometry.offset(
            tileMidY: 100,
            screenMidY: 400,
            factor: 0
        )
        XCTAssertEqual(offset, 0, accuracy: 0.0001)
    }

    // MARK: - Above / below screen midpoint

    func test_tileAboveCenter_offsetIsPositive() {
        // Tile midY = 100, screenMid = 400 → distance = -300 → offset = +300 × 0.5 = 150.
        let offset = HSParallaxGeometry.offset(
            tileMidY: 100,
            screenMidY: 400,
            factor: 0.5
        )
        XCTAssertEqual(offset, 150, accuracy: 0.0001)
    }

    func test_tileBelowCenter_offsetIsNegative() {
        // Tile midY = 700, screenMid = 400 → distance = 300 → offset = -300 × 0.5 = -150.
        let offset = HSParallaxGeometry.offset(
            tileMidY: 700,
            screenMidY: 400,
            factor: 0.5
        )
        XCTAssertEqual(offset, -150, accuracy: 0.0001)
    }

    // MARK: - Factor scaling

    func test_factorScales_offsetLinearly() {
        let base = HSParallaxGeometry.offset(
            tileMidY: 100,
            screenMidY: 400,
            factor: 0.1
        )
        let doubled = HSParallaxGeometry.offset(
            tileMidY: 100,
            screenMidY: 400,
            factor: 0.2
        )
        XCTAssertEqual(doubled, base * 2, accuracy: 0.0001)
    }

    // MARK: - Clamping

    func test_factorAboveOne_clampsToOne() {
        let offset = HSParallaxGeometry.offset(
            tileMidY: 100,
            screenMidY: 400,
            factor: 5
        )
        // distance = -300, clampedFactor = 1, expected = 300
        XCTAssertEqual(offset, 300, accuracy: 0.0001)
    }

    func test_factorBelowZero_clampsToZero() {
        let offset = HSParallaxGeometry.offset(
            tileMidY: 100,
            screenMidY: 400,
            factor: -2
        )
        XCTAssertEqual(offset, 0, accuracy: 0.0001)
    }

    // MARK: - Modifier instantiation

    func test_modifier_isInstantiable_withDefault() {
        let modifier = HSParallaxTileModifier()
        XCTAssertEqual(modifier.factor, 0.3, accuracy: 0.0001)
    }

    func test_modifier_clampsFactor_atConstruction() {
        let high = HSParallaxTileModifier(factor: 5)
        XCTAssertEqual(high.factor, 1, accuracy: 0.0001)

        let low = HSParallaxTileModifier(factor: -2)
        XCTAssertEqual(low.factor, 0, accuracy: 0.0001)
    }
}

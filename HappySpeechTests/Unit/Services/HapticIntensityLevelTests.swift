@testable import HappySpeech
import XCTest

// MARK: - HapticIntensityLevelTests
//
// Block V v18 — покрытие HapticIntensityLevel (6 тестов).
// Тестируются scale-значения и фабричный метод from(scale:).

final class HapticIntensityLevelTests: XCTestCase {

    // MARK: - scale values

    func test_offLevel_scaleIsZero() {
        XCTAssertEqual(HapticIntensityLevel.off.scale, 0.0, accuracy: 0.001)
    }

    func test_subtleLevel_scaleIsHalf() {
        XCTAssertEqual(HapticIntensityLevel.subtle.scale, 0.5, accuracy: 0.001)
    }

    func test_fullLevel_scaleIsOne() {
        XCTAssertEqual(HapticIntensityLevel.full.scale, 1.0, accuracy: 0.001)
    }

    // MARK: - from(scale:)

    func test_fromScale_zero_returnsOff() {
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.0), .off)
    }

    func test_fromScale_point5_returnsSubtle() {
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.5), .subtle)
    }

    func test_fromScale_one_returnsFull() {
        XCTAssertEqual(HapticIntensityLevel.from(scale: 1.0), .full)
    }

    func test_fromScale_point9_returnsFull() {
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.9), .full)
    }

    func test_fromScale_nearZero_returnsOff() {
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.005), .off)
    }

    // MARK: - CaseIterable

    func test_allCases_containsThreeValues() {
        XCTAssertEqual(HapticIntensityLevel.allCases.count, 3)
    }
}

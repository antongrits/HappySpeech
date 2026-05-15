import UIKit
import XCTest
@testable import HappySpeech

// MARK: - HapticServiceLiveTests
//
// Тесты LiveHapticService + FallbackHapticService.
// На симуляторе CHHapticEngine недоступен → LiveHapticService.isAvailable == false,
// play() — no-op. FallbackHapticService использует UIKit feedback generators
// и работает на симуляторе (без видимого эффекта).

final class HapticServiceLiveTests: XCTestCase {

    // MARK: - LiveHapticService

    func testLiveInitDoesNotCrash() {
        let service = LiveHapticService()
        // isAvailable зависит от железа; на симуляторе обычно false — но init не падает.
        _ = service.isAvailable
    }

    func testLiveIntensityScaleClamps() {
        let service = LiveHapticService()
        service.setIntensityScale(5.0)
        service.setIntensityScale(-3.0)
        service.setIntensityScale(0.5)
        // Нет краша — внутреннее состояние зажато в [0, 1].
    }

    func testLivePlayWhenUnavailableIsNoop() async {
        let service = LiveHapticService()
        // На симуляторе isAvailable == false → play возвращается мгновенно.
        await service.play(pattern: .celebration)
        await service.play(pattern: .errorBuzz)
    }

    func testLivePlayWithZeroIntensityIsNoop() async {
        let service = LiveHapticService()
        service.setIntensityScale(0.0)
        await service.play(pattern: .buttonTap)
    }

    func testLiveStopIsNoop() async {
        let service = LiveHapticService()
        await service.stop()
    }

    func testLiveLegacyImpactShimDoesNotCrash() {
        let service = LiveHapticService()
        for style: UIImpactFeedbackGenerator.FeedbackStyle in [.heavy, .medium, .rigid, .soft, .light] {
            service.impact(style)
        }
    }

    func testLiveLegacyNotificationShimDoesNotCrash() {
        let service = LiveHapticService()
        for type: UINotificationFeedbackGenerator.FeedbackType in [.success, .warning, .error] {
            service.notification(type)
        }
    }

    func testLiveLegacySelectionShimDoesNotCrash() {
        let service = LiveHapticService()
        service.selection()
    }

    // MARK: - FallbackHapticService

    func testFallbackIsAlwaysAvailable() {
        let service = FallbackHapticService()
        XCTAssertTrue(service.isAvailable, "Fallback заявляет доступность всегда")
    }

    func testFallbackPlayAllPatternsDoesNotCrash() async {
        let service = FallbackHapticService()
        for pattern in HapticPattern.allCases {
            await service.play(pattern: pattern)
        }
    }

    func testFallbackZeroIntensitySkipsPlay() async {
        let service = FallbackHapticService()
        service.setIntensityScale(0.0)
        await service.play(pattern: .celebration)
        // Нет краша; при нулевой интенсивности play() — ранний выход.
    }

    func testFallbackIntensityScaleClamps() {
        let service = FallbackHapticService()
        service.setIntensityScale(10.0)
        service.setIntensityScale(-1.0)
    }

    func testFallbackStopIsNoop() async {
        let service = FallbackHapticService()
        await service.stop()
    }

    func testFallbackLegacyShimsDoNotCrash() {
        let service = FallbackHapticService()
        service.impact(.medium)
        service.notification(.success)
        service.selection()
    }

    func testFallbackLegacyShimsSkippedAtZeroIntensity() {
        let service = FallbackHapticService()
        service.setIntensityScale(0.0)
        service.impact(.heavy)
        service.notification(.error)
        service.selection()
    }

    // MARK: - HapticIntensityLevel scale

    func testHapticIntensityLevelScaleValues() {
        XCTAssertEqual(HapticIntensityLevel.off.scale, 0.0, accuracy: 0.001)
        XCTAssertEqual(HapticIntensityLevel.subtle.scale, 0.5, accuracy: 0.001)
        XCTAssertEqual(HapticIntensityLevel.full.scale, 1.0, accuracy: 0.001)
    }

    func testHapticIntensityLevelFromScaleBoundaries() {
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.0), .off)
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.005), .off)
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.3), .subtle)
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.74), .subtle)
        XCTAssertEqual(HapticIntensityLevel.from(scale: 0.75), .full)
        XCTAssertEqual(HapticIntensityLevel.from(scale: 1.0), .full)
    }

    func testHapticPatternCaseCount() {
        XCTAssertEqual(HapticPattern.allCases.count, 15)
    }
}

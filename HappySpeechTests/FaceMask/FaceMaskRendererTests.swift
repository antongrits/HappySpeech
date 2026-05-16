@testable import HappySpeech
import XCTest

// MARK: - FaceMaskRendererTests
//
// Покрывает: чистую логику FaceMaskRenderer — overlayOffset, glowColor,
// makeConfiguration (только параметры), isFaceTrackingSupported.
// ARKit/Metal hardware — untestable без реального устройства.
// ARFaceTrackingConfiguration.isSupported = false на симуляторе — ветка проверяется.

@MainActor
final class FaceMaskRendererTests: XCTestCase {

    private var sut: FaceMaskRenderer!

    override func setUp() {
        super.setUp()
        sut = FaceMaskRenderer()
    }

    // MARK: - overlayOffset

    func test_overlayOffset_kitten_hasNegativeHeight() {
        let offset = sut.overlayOffset(for: .kitten)
        XCTAssertEqual(offset.width, 0, accuracy: 0.1)
        XCTAssertLessThan(offset.height, 0, "Kitten overlay должен быть выше центра лица")
    }

    func test_overlayOffset_crown_higherThanKitten() {
        let kittenOffset = sut.overlayOffset(for: .kitten)
        let crownOffset = sut.overlayOffset(for: .crown)
        XCTAssertLessThan(crownOffset.height, kittenOffset.height,
                          "Корона должна находиться выше ушек котика")
    }

    func test_overlayOffset_glasses_closerToCenterThanKitten() {
        let kittenOffset = sut.overlayOffset(for: .kitten)
        let glassesOffset = sut.overlayOffset(for: .glasses)
        XCTAssertGreaterThan(glassesOffset.height, kittenOffset.height,
                              "Очки должны быть ближе к центру чем ушки")
    }

    func test_overlayOffset_allMasksHaveZeroWidth() {
        for mask in FaceMaskKind.allCases {
            let offset = sut.overlayOffset(for: mask)
            XCTAssertEqual(offset.width, 0, accuracy: 0.1,
                           "Ширина overlay должна быть 0 для маски \(mask)")
        }
    }

    // MARK: - glowColor (проверяем что возвращает без крэша для каждой маски)

    func test_glowColor_returnsColorForAllMasks() {
        for mask in FaceMaskKind.allCases {
            let color = sut.glowColor(for: mask)
            // Просто убеждаемся что метод отработал и вернул Color (не крашит)
            _ = color
        }
    }

    // MARK: - makeConfiguration

    func test_makeConfiguration_isLightEstimationEnabled() {
        // ARFaceTrackingConfiguration не работает на симуляторе, но объект можно создать.
        let config = sut.makeConfiguration()
        XCTAssertTrue(config.isLightEstimationEnabled,
                      "Light estimation должен быть включён")
    }

    func test_makeConfiguration_maximumNumberOfTrackedFacesIsOne() {
        let config = sut.makeConfiguration()
        XCTAssertEqual(config.maximumNumberOfTrackedFaces, 1,
                       "Должно отслеживаться не более одного лица")
    }

    // MARK: - currentMask и glowState (публичное состояние)

    func test_currentMask_defaultIsKitten() {
        XCTAssertEqual(sut.currentMask, .kitten,
                       "Маска по умолчанию должна быть kitten")
    }

    func test_glowState_defaultIsIdle() {
        XCTAssertEqual(sut.glowState, FaceMaskState.idle,
                       "Состояние glow по умолчанию должно быть idle")
    }

    func test_currentMask_canBeUpdated() {
        sut.currentMask = .fox
        XCTAssertEqual(sut.currentMask, .fox)
    }

    func test_glowState_canBeUpdated() {
        sut.glowState = .glowing
        XCTAssertEqual(sut.glowState, .glowing)
    }

    // MARK: - isFaceTrackingSupported (static)

    func test_isFaceTrackingSupported_returnsBool() {
        // На симуляторе false, на TrueDepth-устройстве true.
        let supported = FaceMaskRenderer.isFaceTrackingSupported
        // Просто убеждаемся что вызов не крашит.
        _ = supported
    }
}

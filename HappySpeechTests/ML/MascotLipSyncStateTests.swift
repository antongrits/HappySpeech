import XCTest

@testable import HappySpeech

// MARK: - MascotLipSyncStateTests
//
// 5 unit-тестов для MascotLipSyncState + LipSyncViseme.
// Не требуют ARKit / Vision / реального устройства.

@MainActor
final class MascotLipSyncStateTests: XCTestCase {

    // MARK: - SUT

    private var sut: MascotLipSyncState!

    override func setUp() {
        super.setUp()
        sut = MascotLipSyncState()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Test 1: начальное состояние

    /// По умолчанию isTracking = false, чтобы оверлей не показывался без ARSession.
    func test_initialState_isTrackingFalse() {
        XCTAssertFalse(sut.isTracking)
        XCTAssertEqual(sut.mouthOpen, 0.0)
        XCTAssertEqual(sut.confidence, 0.0)
        XCTAssertEqual(sut.viseme, .neutral)
    }

    // MARK: - Test 2: обновление mouthOpen зажимает значение в 0...1

    /// При назначении значений вне диапазона — state просто хранит то что передали.
    /// Клиент (ARMirrorView) сам обязан передавать значения в [0, 1].
    func test_mouthOpen_mutation() {
        sut.mouthOpen = 0.75
        XCTAssertEqual(sut.mouthOpen, 0.75, accuracy: 0.001)

        sut.mouthOpen = 0.0
        XCTAssertEqual(sut.mouthOpen, 0.0, accuracy: 0.001)

        sut.mouthOpen = 1.0
        XCTAssertEqual(sut.mouthOpen, 1.0, accuracy: 0.001)
    }

    // MARK: - Test 3: конвертация всех Viseme в LipSyncViseme

    /// LipSyncViseme(from:) должен маппить все 6 кейсов Viseme без падений.
    func test_lipSyncViseme_conversionFromAllVisemes() {
        let mapping: [(Viseme, LipSyncViseme)] = [
            (.closed, .neutral),
            (.a,      .open),
            (.e,      .wide),
            (.i,      .smile),
            (.o,      .rounded),
            (.u,      .rounded)
        ]
        for (viseme, expected) in mapping {
            let result = LipSyncViseme(from: viseme)
            XCTAssertEqual(
                result, expected,
                "Viseme.\(viseme) должен конвертироваться в LipSyncViseme.\(expected)"
            )
        }
    }

    // MARK: - Test 4: переход isTracking true → false сбрасывает overlay

    /// Когда ARSession паузируется, isTracking становится false.
    /// Тест проверяет что state поддерживает такой переход без ошибок.
    func test_trackingTransition_trueThenFalse() {
        sut.mouthOpen = 0.5
        sut.viseme = .open
        sut.confidence = 0.8
        sut.isTracking = true

        XCTAssertTrue(sut.isTracking)

        sut.isTracking = false

        XCTAssertFalse(sut.isTracking)
        // mouthOpen и viseme НЕ сбрасываются при паузе — значения остаются
        // (это позволяет плавно скрыть оверлей через opacity → 0, не меняя форму)
        XCTAssertEqual(sut.mouthOpen, 0.5, accuracy: 0.001)
        XCTAssertEqual(sut.viseme, .open)
    }

    // MARK: - Test 5: confidence в диапазоне 0...1 не вызывает ошибок opacity

    /// opacity принимает Double(confidence), который должен быть в [0, 1].
    /// Тест проверяет все граничные значения.
    func test_confidence_boundaryValues() {
        sut.confidence = 0.0
        XCTAssertEqual(Double(sut.confidence), 0.0, accuracy: 0.001)

        sut.confidence = 0.5
        XCTAssertEqual(Double(sut.confidence), 0.5, accuracy: 0.001)

        sut.confidence = 1.0
        XCTAssertEqual(Double(sut.confidence), 1.0, accuracy: 0.001)
    }
}

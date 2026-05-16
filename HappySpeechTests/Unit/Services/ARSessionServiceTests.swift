@testable import HappySpeech
import XCTest

// MARK: - ARSessionServiceTests
//
// 2.10 v25 — покрытие ARSessionService.
// FaceBlendshapes — чистая структура с вычисляемыми свойствами (lipSymmetry,
// isSmiling, isTongueOut, averageBlink, mouthOpenness) — покрывается напрямую.
// Старт реальной ARSession (ARFaceTrackingConfiguration / камера) — genuinely
// SDK-bound и недоступен на симуляторе; покрываем capability-логику и
// 2D-fallback через MockARSessionService (документировано для ADR-V25-COVERAGE).

@MainActor
final class ARSessionServiceTests: XCTestCase {

    // MARK: - FaceBlendshapes — neutral / presets

    func test_neutral_allValuesAreZero() {
        let neutral = FaceBlendshapes.neutral
        XCTAssertEqual(neutral.jawOpen, 0)
        XCTAssertEqual(neutral.mouthFunnel, 0)
        XCTAssertEqual(neutral.tongueOut, 0)
        XCTAssertEqual(neutral.cheekPuff, 0)
    }

    func test_smilePreset_hasSmileValues() {
        let smile = FaceBlendshapes.smile
        XCTAssertGreaterThan(smile.mouthSmileLeft, 0)
        XCTAssertGreaterThan(smile.mouthSmileRight, 0)
        XCTAssertTrue(smile.isSmiling)
    }

    func test_funnelPreset_hasFunnelValue() {
        XCTAssertGreaterThan(FaceBlendshapes.funnel.mouthFunnel, 0)
    }

    // MARK: - FaceBlendshapes — computed: mouthOpenness

    func test_mouthOpenness_mirrorsJawOpen() {
        let shape = FaceBlendshapes(jawOpen: 0.42)
        XCTAssertEqual(shape.mouthOpenness, 0.42, accuracy: 0.0001)
    }

    // MARK: - FaceBlendshapes — computed: isSmiling

    func test_isSmiling_trueWhenBothCornersAboveThreshold() {
        let shape = FaceBlendshapes(mouthSmileLeft: 0.4, mouthSmileRight: 0.4)
        XCTAssertTrue(shape.isSmiling)
    }

    func test_isSmiling_falseWhenOnlyOneCornerRaised() {
        let shape = FaceBlendshapes(mouthSmileLeft: 0.4, mouthSmileRight: 0.1)
        XCTAssertFalse(shape.isSmiling)
    }

    func test_isSmiling_falseAtNeutral() {
        XCTAssertFalse(FaceBlendshapes.neutral.isSmiling)
    }

    // MARK: - FaceBlendshapes — computed: isTongueOut

    func test_isTongueOut_trueAboveHalf() {
        XCTAssertTrue(FaceBlendshapes(tongueOut: 0.6).isTongueOut)
    }

    func test_isTongueOut_falseBelowHalf() {
        XCTAssertFalse(FaceBlendshapes(tongueOut: 0.5).isTongueOut)
    }

    // MARK: - FaceBlendshapes — computed: averageBlink

    func test_averageBlink_isMeanOfBothEyes() {
        let shape = FaceBlendshapes(eyeBlinkLeft: 0.8, eyeBlinkRight: 0.2)
        XCTAssertEqual(shape.averageBlink, 0.5, accuracy: 0.0001)
    }

    // MARK: - FaceBlendshapes — computed: lipSymmetry

    func test_lipSymmetry_isOneWhenPerfectlySymmetric() {
        let shape = FaceBlendshapes(
            mouthSmileLeft: 0.5, mouthSmileRight: 0.5,
            mouthStretchLeft: 0.3, mouthStretchRight: 0.3
        )
        XCTAssertEqual(shape.lipSymmetry, 1.0, accuracy: 0.0001)
    }

    func test_lipSymmetry_isOneWhenBothSidesNeutral() {
        // maxSide <= 0.01 ⇒ возвращается 1 (нет данных — считаем симметричным).
        XCTAssertEqual(FaceBlendshapes.neutral.lipSymmetry, 1.0, accuracy: 0.0001)
    }

    func test_lipSymmetry_lessThanOneWhenAsymmetric() {
        let shape = FaceBlendshapes(
            mouthSmileLeft: 0.8, mouthSmileRight: 0.2,
            mouthStretchLeft: 0.8, mouthStretchRight: 0.2
        )
        XCTAssertLessThan(shape.lipSymmetry, 1.0)
        XCTAssertGreaterThanOrEqual(shape.lipSymmetry, 0.0)
    }

    func test_blendshapes_equatable() {
        let a = FaceBlendshapes(jawOpen: 0.3, mouthFunnel: 0.5)
        let b = FaceBlendshapes(jawOpen: 0.3, mouthFunnel: 0.5)
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, FaceBlendshapes.neutral)
    }

    // MARK: - ARSessionError — localized descriptions

    func test_arSessionError_descriptions_areNonEmpty() {
        let errors: [ARSessionError] = [
            .notSupported,
            .cameraPermissionDenied,
            .sessionFailed("сбой трекинга")
        ]
        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true)
        }
    }

    func test_arSessionError_sessionFailed_carriesMessage() {
        let error = ARSessionError.sessionFailed("конкретная причина")
        XCTAssertEqual(error.errorDescription, "конкретная причина")
    }

    // MARK: - MockARSessionService — capability / lifecycle

    func test_mock_isSupportedByDefault() {
        let sut = MockARSessionService()
        XCTAssertTrue(sut.isSupported)
    }

    func test_mock_unsupportedConfiguration_startThrowsNotSupported() async {
        let sut = MockARSessionService(isSupported: false)
        do {
            try await sut.startSession()
            XCTFail("Старт на неподдерживаемом устройстве должен бросать")
        } catch let error as ARSessionError {
            if case .notSupported = error { } else {
                XCTFail("Ожидалась notSupported, получено \(error)")
            }
        } catch {
            XCTFail("Неверный тип ошибки: \(error)")
        }
    }

    func test_mock_initialState_isNotRunning() {
        let sut = MockARSessionService()
        XCTAssertFalse(sut.isRunning)
        XCTAssertNil(sut.currentBlendshapes)
    }

    func test_mock_startSession_setsRunning() async throws {
        let sut = MockARSessionService()
        try await sut.startSession()
        XCTAssertTrue(sut.isRunning)
        sut.stopSession()
    }

    func test_mock_stopSession_resetsState() async throws {
        let sut = MockARSessionService()
        try await sut.startSession()
        sut.stopSession()
        XCTAssertFalse(sut.isRunning)
        XCTAssertNil(sut.currentBlendshapes)
    }

    func test_mock_pauseSession_stopsRunning() async throws {
        let sut = MockARSessionService()
        try await sut.startSession()
        sut.pauseSession()
        XCTAssertFalse(sut.isRunning)
    }

    func test_mock_resumeSession_restartsRunning() async throws {
        let sut = MockARSessionService()
        try await sut.startSession()
        sut.pauseSession()
        try await sut.resumeSession()
        XCTAssertTrue(sut.isRunning)
        sut.stopSession()
    }

    func test_mock_pixelBufferStream_isNilOnSimulator() {
        // Симулятор не имеет камеры — 2D-fallback: pixelBufferStream отсутствует.
        let sut = MockARSessionService()
        XCTAssertNil(sut.pixelBufferStream)
    }

    func test_mock_underlyingSession_isNil() {
        let sut = MockARSessionService()
        XCTAssertNil(sut.underlyingSession)
    }

    func test_mock_doubleStart_isIdempotent() async throws {
        let sut = MockARSessionService()
        try await sut.startSession()
        try await sut.startSession()
        XCTAssertTrue(sut.isRunning)
        sut.stopSession()
    }
}

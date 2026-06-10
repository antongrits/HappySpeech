@testable import HappySpeech
import XCTest

// MARK: - MockARSessionScriptedTests
//
// A-03 — детерминированная верификация AR без TrueDepth-железа.
// Симулятор не поддерживает ARFaceTracking, поэтому MockARSessionService
// расширен «скриптованным» режимом: массив поз с длительностями проигрывается
// по порядку через тот же AsyncStream<FaceBlendshapes>. Это даёт unit/UI-тестам
// известный детерминированный вход (без синусоиды/рандома) для проверки
// набора звёзд/прогресса.
//
// Здесь покрыты: новые фикстуры FaceBlendshapes (.pucker/.tongueOut/.jawOpenWide/
// .asymmetric/.tongueUpProxy), сам скриптованный проигрыватель и его инвариант
// «эмитит ровно заданные позы по порядку».

@MainActor
final class MockARSessionScriptedTests: XCTestCase {

    // MARK: - Новые фикстуры FaceBlendshapes (пороги из исследования A-03)

    func test_puckerFixture_meetsThreshold() {
        // «Трубочка»: mouthPucker ≥ 0.6, улыбка низкая.
        XCTAssertGreaterThanOrEqual(FaceBlendshapes.pucker.mouthPucker, 0.6)
        XCTAssertLessThan(FaceBlendshapes.pucker.mouthSmileLeft, 0.3)
    }

    func test_tongueOutFixture_meetsThreshold() {
        // «Лопаточка»: tongueOut ≥ 0.5 при малом jawOpen.
        XCTAssertGreaterThanOrEqual(FaceBlendshapes.tongueOut.tongueOut, 0.5)
        XCTAssertTrue(FaceBlendshapes.tongueOut.isTongueOut)
        XCTAssertLessThan(FaceBlendshapes.tongueOut.jawOpen, 0.3)
    }

    func test_jawOpenWideFixture_meetsThreshold() {
        // Р-прокси: jawOpen ≥ 0.4 + подворот губ («грибок»).
        XCTAssertGreaterThanOrEqual(FaceBlendshapes.jawOpenWide.jawOpen, 0.4)
        XCTAssertGreaterThan(FaceBlendshapes.jawOpenWide.mouthRollLower, 0.5)
        XCTAssertGreaterThan(FaceBlendshapes.jawOpenWide.mouthRollUpper, 0.5)
    }

    func test_tongueUpProxyFixture_meetsThreshold() {
        // Л-прокси: приоткрытый рот + высунутый язык.
        XCTAssertGreaterThanOrEqual(FaceBlendshapes.tongueUpProxy.jawOpen, 0.4)
        XCTAssertGreaterThanOrEqual(FaceBlendshapes.tongueUpProxy.tongueOut, 0.5)
    }

    func test_asymmetricFixture_breaksLipSymmetry() {
        // Асимметрия: левый угол выше правого → lipSymmetry < 1.
        let shape = FaceBlendshapes.asymmetric
        XCTAssertNotEqual(shape.mouthSmileLeft, shape.mouthSmileRight)
        XCTAssertLessThan(shape.lipSymmetry, 1.0)
        XCTAssertGreaterThanOrEqual(shape.lipSymmetry, 0.0)
    }

    // MARK: - Скриптованный режим: проигрывание известной последовательности

    func test_scriptedMode_emitsPosesInOrder() async throws {
        let script: [MockARSessionService.ScriptedPose] = [
            .init(pose: .smile, duration: 1.0 / 15.0),   // ровно 1 кадр
            .init(pose: .funnel, duration: 1.0 / 15.0),
            .init(pose: .pucker, duration: 1.0 / 15.0)
        ]
        let sut = MockARSessionService(script: script)

        var collected: [FaceBlendshapes] = []
        let collector = Task { @MainActor in
            for await frame in sut.blendshapeStream {
                collected.append(frame)
                if collected.count >= 3 { break }
            }
        }

        try await sut.startSession()
        await collector.value
        sut.stopSession()

        XCTAssertEqual(collected.count, 3)
        XCTAssertEqual(collected[0], .smile)
        XCTAssertEqual(collected[1], .funnel)
        XCTAssertEqual(collected[2], .pucker)
    }

    func test_scriptedMode_holdsPoseForMultipleFrames() async throws {
        // Поза на 3 кадра (3/15 с) должна эмитнуться ~3 раза подряд.
        let frame = 1.0 / 15.0
        let script: [MockARSessionService.ScriptedPose] = [
            .init(pose: .smile, duration: frame * 3)
        ]
        let sut = MockARSessionService(script: script)

        var smileCount = 0
        let collector = Task { @MainActor in
            for await shape in sut.blendshapeStream {
                if shape == .smile { smileCount += 1 }
                if smileCount >= 3 { break }
            }
        }

        try await sut.startSession()
        await collector.value
        sut.stopSession()

        XCTAssertGreaterThanOrEqual(smileCount, 3)
    }

    func test_setScript_overridesSineLoop() async throws {
        let sut = MockARSessionService()              // дефолт — синусоида
        sut.setScript([.init(pose: .funnel, duration: 1.0 / 15.0)])

        var first: FaceBlendshapes?
        let collector = Task { @MainActor in
            for await shape in sut.blendshapeStream {
                first = shape
                break
            }
        }

        try await sut.startSession()
        await collector.value
        sut.stopSession()

        XCTAssertEqual(first, .funnel)
    }

    func test_scriptedMode_currentBlendshapesReflectsLastPose() async throws {
        let sut = MockARSessionService(script: [
            .init(pose: .pucker, duration: 1.0 / 15.0)
        ])

        let collector = Task { @MainActor in
            for await _ in sut.blendshapeStream { break }
        }
        try await sut.startSession()
        await collector.value

        XCTAssertEqual(sut.currentBlendshapes, .pucker)
        sut.stopSession()
        XCTAssertNil(sut.currentBlendshapes)
    }
}

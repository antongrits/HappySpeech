import XCTest
@testable import HappySpeech

/// Тесты интерактора «Акустического зеркала»: полный сценарий 5 раундов,
/// честный provision при отсутствии фрикативного звука, персистентность сессии
/// и подача исходов в планировщик повторов.
@MainActor
final class AcousticMirrorInteractorTests: XCTestCase {

    // MARK: - Spies

    /// Шпион презентера — копит вызовы.
    private final class PresenterSpy: AcousticMirrorPresentationLogic {
        var startResponses: [AcousticMirrorModels.Start.Response] = []
        var recordingCount = 0
        var analyzingCount = 0
        var attemptResponses: [AcousticMirrorModels.Attempt.Response] = []
        var completeResponses: [AcousticMirrorModels.Complete.Response] = []
        var failures: [Bool] = []

        func presentStart(_ response: AcousticMirrorModels.Start.Response) {
            startResponses.append(response)
        }
        func presentRecording() { recordingCount += 1 }
        func presentAnalyzing() { analyzingCount += 1 }
        func presentAttempt(_ response: AcousticMirrorModels.Attempt.Response) {
            attemptResponses.append(response)
        }
        func presentComplete(_ response: AcousticMirrorModels.Complete.Response) {
            completeResponses.append(response)
        }
        func presentFailure(permissionDenied: Bool) {
            failures.append(permissionDenied)
        }
    }

    /// Шпион персистентности сессий.
    private final class PersistenceSpy: SessionPersistenceCoordinating, @unchecked Sendable {
        private(set) var persisted: [SessionDTO] = []
        func persistAndSync(_ session: SessionDTO) async {
            persisted.append(session)
        }
    }

    /// Шпион планировщика — копит recordItemOutcome.
    private final class PlannerSpy: AdaptivePlannerService, @unchecked Sendable {
        struct Outcome: Equatable {
            let childId: String
            let itemId: String
            let sound: String
            let correct: Bool
        }
        private(set) var outcomes: [Outcome] = []

        func buildDailyRoute(for childId: String) async throws -> AdaptiveRoute {
            AdaptiveRoute(steps: [], maxDurationSec: 0, fatigueLevel: .fresh, disorder: .dyslalia)
        }
        func recordCompletion(sessionId: String, route: AdaptiveRoute) async throws {}
        func recordSessionResult(childId: String, soundTarget: String, qualityScore: SM2Quality) async throws {}
        func recordItemOutcome(childId: String, itemId: String, sound: String, correct: Bool) async {
            outcomes.append(Outcome(childId: childId, itemId: itemId, sound: sound, correct: correct))
        }
        func shouldTakeBreak(consecutiveWrong: Int, sessionDurationSec: Int, childAge: Int) -> Bool { false }
    }

    // MARK: - Helpers

    private func makeSUT(
        scripted: [SibilantEvaluation],
        childSounds: [String] = ["С"],
        audio: MockAudioService = MockAudioService()
    ) -> (AcousticMirrorInteractor, PresenterSpy, PersistenceSpy, PlannerSpy) {
        let presenter = PresenterSpy()
        let persistence = PersistenceSpy()
        let planner = PlannerSpy()
        let childRepo = MockChildRepository(children: [
            ChildProfileDTO(
                id: "child-1",
                name: "Тест",
                age: 6,
                targetSounds: childSounds,
                parentId: "local-parent"
            )
        ])
        let interactor = AcousticMirrorInteractor(
            childId: "child-1",
            audioService: audio,
            mirrorService: MockAcousticMirrorService(scripted: scripted),
            childRepository: childRepo,
            adaptivePlanner: planner,
            sessionPersistence: persistence,
            sleeper: { _ in } // без реальных задержек в тестах
        )
        interactor.presenter = presenter
        return (interactor, presenter, persistence, planner)
    }

    private func evaluation(stars: Int, verdict: SibilantVerdict, position: Double = 0.8) -> SibilantEvaluation {
        SibilantEvaluation(
            continuumPosition: position,
            verdict: verdict,
            flags: [],
            stars: stars,
            measurement: verdict == .noFrication ? nil : SibilantMeasurement(
                centroidHz: 6_800, spreadHz: 1_300, highBandShare: 0.6,
                fricationDuration: 0.8, peakRMS: 0.2, frameCount: 50
            ),
            targetPole: .whistling
        )
    }

    // MARK: - Tests

    func testStartResolvesSibilantFromProfile() async {
        let (sut, presenter, _, _) = makeSUT(scripted: [evaluation(stars: 3, verdict: .onTarget)], childSounds: ["Р", "Ш"])
        await sut.startSession(.init(childId: "child-1", preferredSound: ""))

        XCTAssertEqual(presenter.startResponses.count, 1)
        // Р — не сибилянт, пропускается; Ш — первый сибилянт профиля.
        XCTAssertEqual(presenter.startResponses.first?.targetSound, "Ш")
        XCTAssertEqual(presenter.startResponses.first?.totalRounds, AcousticMirrorModels.roundsPerSession)
    }

    func testStartFallsBackToDefaultSound() async {
        let (sut, presenter, _, _) = makeSUT(scripted: [evaluation(stars: 3, verdict: .onTarget)], childSounds: ["Р", "Л"])
        await sut.startSession(.init(childId: "child-1", preferredSound: ""))
        XCTAssertEqual(presenter.startResponses.first?.targetSound, "С")
    }

    func testPreferredSoundWins() async {
        let (sut, presenter, _, _) = makeSUT(scripted: [evaluation(stars: 3, verdict: .onTarget)])
        await sut.startSession(.init(childId: "child-1", preferredSound: "Ж"))
        XCTAssertEqual(presenter.startResponses.first?.targetSound, "Ж")
    }

    func testFullSessionCompletesAndPersists() async {
        let script = [
            evaluation(stars: 3, verdict: .onTarget),
            evaluation(stars: 2, verdict: .nearTarget),
            evaluation(stars: 0, verdict: .noFrication),
            evaluation(stars: 1, verdict: .oppositePole, position: 0.2),
            evaluation(stars: 3, verdict: .onTarget)
        ]
        let (sut, presenter, persistence, planner) = makeSUT(scripted: script)
        await sut.startSession(.init(childId: "child-1", preferredSound: "С"))

        for _ in 0 ..< AcousticMirrorModels.roundsPerSession {
            await sut.performAttempt(.init())
        }

        XCTAssertEqual(presenter.attemptResponses.count, 5)
        XCTAssertEqual(presenter.completeResponses.count, 1)
        let complete = presenter.completeResponses[0]
        XCTAssertEqual(complete.totalStars, 3 + 2 + 0 + 1 + 3)
        XCTAssertEqual(complete.maxStars, 15)

        // Сессия персистится ровно один раз с честными totals.
        XCTAssertEqual(persistence.persisted.count, 1)
        let dto = persistence.persisted[0]
        XCTAssertEqual(dto.childId, "child-1")
        XCTAssertEqual(dto.totalAttempts, 5)
        XCTAssertEqual(dto.correctAttempts, 3, "Зачёт — раунды с ≥2 звёздами")
        XCTAssertEqual(dto.targetSound, "С")
        XCTAssertEqual(dto.stage, CorrectionStage.isolated.rawValue)
        XCTAssertEqual(dto.templateType, TemplateType.visualAcoustic.rawValue)

        // Каждый раунд кормит FSRS-лестницу.
        XCTAssertEqual(planner.outcomes.count, 5)
        XCTAssertEqual(planner.outcomes.filter(\.correct).count, 3)
        XCTAssertEqual(planner.outcomes.first?.itemId, "acoustic-mirror-С")
    }

    func testNoExtraAttemptsAfterCompletion() async {
        let (sut, presenter, persistence, _) = makeSUT(
            scripted: [evaluation(stars: 3, verdict: .onTarget)]
        )
        await sut.startSession(.init(childId: "child-1", preferredSound: "С"))
        for _ in 0 ..< AcousticMirrorModels.roundsPerSession + 2 {
            await sut.performAttempt(.init())
        }
        XCTAssertEqual(presenter.attemptResponses.count, AcousticMirrorModels.roundsPerSession)
        XCTAssertEqual(persistence.persisted.count, 1, "Сессия персистится идемпотентно")
    }

    func testPermissionDeniedPresentsHonestFailure() async {
        // MockAudioService.requestPermission всегда возвращает true, поэтому для
        // негативного сценария используется отказная реализация.
        let denied = DenyingAudioService()
        let presenter = PresenterSpy()
        let interactor = AcousticMirrorInteractor(
            childId: "child-1",
            audioService: denied,
            mirrorService: MockAcousticMirrorService(),
            sleeper: { _ in }
        )
        interactor.presenter = presenter

        await interactor.startSession(.init(childId: "child-1", preferredSound: "С"))
        await interactor.performAttempt(.init())

        XCTAssertEqual(presenter.failures, [true], "Отказ микрофона → честный failure, не фейковая оценка")
        XCTAssertTrue(presenter.attemptResponses.isEmpty)
    }

    func testSwitchTargetSoundResetsRounds() async {
        let (sut, presenter, _, _) = makeSUT(scripted: [evaluation(stars: 3, verdict: .onTarget)])
        await sut.startSession(.init(childId: "child-1", preferredSound: "С"))
        await sut.performAttempt(.init())
        XCTAssertEqual(sut.roundNumber, 1)

        await sut.switchTargetSound(to: "Ш")
        XCTAssertEqual(sut.targetSound, "Ш")
        XCTAssertEqual(sut.roundNumber, 0)
        XCTAssertEqual(presenter.startResponses.last?.targetSound, "Ш")
    }

    func testSwitchToUnsupportedSoundIgnored() async {
        let (sut, _, _, _) = makeSUT(scripted: [evaluation(stars: 3, verdict: .onTarget)])
        await sut.startSession(.init(childId: "child-1", preferredSound: "С"))
        await sut.switchTargetSound(to: "Р")
        XCTAssertEqual(sut.targetSound, "С", "Несибилянт не должен приниматься")
    }
}

// MARK: - DenyingAudioService

/// AudioService, всегда отказывающий в разрешении микрофона (для негативных тестов).
private final class DenyingAudioService: AudioService, @unchecked Sendable {
    var isPermissionGranted: Bool { false }
    var amplitude: Float { 0 }
    var isRecording: Bool { false }
    func requestPermission() async -> Bool { false }
    func startRecording() async throws { throw AppError.audioPermissionDenied }
    func stopRecording() async throws -> URL { throw AppError.audioPermissionDenied }
    func playAudio(url: URL) async throws {}
    func stopPlayback() {}
    func amplitudeBuffer() -> [Float] { [] }
}

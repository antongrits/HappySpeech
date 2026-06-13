import XCTest
@testable import HappySpeech

/// Тесты интерактора «Скороговорки-ракеты»: полный сценарий 4 раундов с ротацией
/// рядов, честный provision при нераспознанном ряде, персистентность сессии,
/// подача исходов в планировщик и резолв возраста из профиля.
@MainActor
final class SyllableRaceInteractorTests: XCTestCase {

    // MARK: - Spies

    private final class PresenterSpy: SyllableRacePresentationLogic {
        var startResponses: [SyllableRaceModels.Start.Response] = []
        var recordingCount = 0
        var analyzingCount = 0
        var attemptResponses: [SyllableRaceModels.Attempt.Response] = []
        var completeResponses: [SyllableRaceModels.Complete.Response] = []
        var failures: [Bool] = []

        func presentStart(_ response: SyllableRaceModels.Start.Response) {
            startResponses.append(response)
        }
        func presentRecording() { recordingCount += 1 }
        func presentAnalyzing() { analyzingCount += 1 }
        func presentAttempt(_ response: SyllableRaceModels.Attempt.Response) {
            attemptResponses.append(response)
        }
        func presentComplete(_ response: SyllableRaceModels.Complete.Response) {
            completeResponses.append(response)
        }
        func presentFailure(permissionDenied: Bool) {
            failures.append(permissionDenied)
        }
    }

    private final class PersistenceSpy: SessionPersistenceCoordinating, @unchecked Sendable {
        private(set) var persisted: [SessionDTO] = []
        func persistAndSync(_ session: SessionDTO) async {
            persisted.append(session)
        }
    }

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

    private func evaluation(
        stars: Int,
        verdict: DDKVerdict,
        rate: Double = 4.5
    ) -> DDKEvaluation {
        DDKEvaluation(
            syllablesPerSecond: verdict == .notDetected ? 0 : rate,
            steadiness: verdict == .notDetected ? nil : 0.8,
            detectedSyllables: verdict == .notDetected ? 0 : 8,
            targetSyllables: 8,
            verdict: verdict,
            flags: [],
            stars: stars,
            measurement: verdict == .notDetected ? nil : SyllableRateMeasurement(
                syllableCount: 8, syllablesPerSecond: rate, voicedDurationSec: 1.5,
                intervalCV: 0.1, meanIntervalSec: 0.2, peakRMS: 0.2
            )
        )
    }

    private func makeSUT(
        scripted: [DDKEvaluation],
        childAge: Int = 6
    ) -> (SyllableRaceInteractor, PresenterSpy, PersistenceSpy, PlannerSpy) {
        let presenter = PresenterSpy()
        let persistence = PersistenceSpy()
        let planner = PlannerSpy()
        let childRepo = MockChildRepository(children: [
            ChildProfileDTO(
                id: "child-1",
                name: "Тест",
                age: childAge,
                targetSounds: ["Р"],
                parentId: "local-parent"
            )
        ])
        let interactor = SyllableRaceInteractor(
            childId: "child-1",
            audioService: MockAudioService(),
            raceService: MockSyllableRaceService(scripted: scripted),
            childRepository: childRepo,
            adaptivePlanner: planner,
            sessionPersistence: persistence,
            sleeper: { _ in }
        )
        interactor.presenter = presenter
        return (interactor, presenter, persistence, planner)
    }

    // MARK: - Tests

    func testStartPresentsFirstSequence() async {
        let (sut, presenter, _, _) = makeSUT(scripted: [evaluation(stars: 3, verdict: .fastSteady)])
        await sut.startSession(.init(childId: "child-1"))
        XCTAssertEqual(presenter.startResponses.count, 1)
        XCTAssertEqual(presenter.startResponses.first?.sequence.id, DDKCatalog.sequences.first?.id)
        XCTAssertEqual(presenter.startResponses.first?.totalRounds, SyllableRaceModels.roundsPerSession)
        XCTAssertEqual(presenter.startResponses.first?.childAge, 6)
    }

    func testResolvesChildAgeFromProfile() async {
        let (sut, presenter, _, _) = makeSUT(scripted: [evaluation(stars: 3, verdict: .fastSteady)], childAge: 8)
        await sut.startSession(.init(childId: "child-1"))
        XCTAssertEqual(presenter.startResponses.first?.childAge, 8,
                       "Возраст для возрастных норм темпа берётся из профиля")
    }

    func testSequenceRotatesEachRound() async {
        let (sut, presenter, _, _) = makeSUT(
            scripted: [evaluation(stars: 2, verdict: .steady)]
        )
        await sut.startSession(.init(childId: "child-1"))
        for _ in 0 ..< SyllableRaceModels.roundsPerSession {
            await sut.performAttempt(.init())
        }
        // 1 старт + по одному presentStart на следующий раунд (кроме последнего).
        let presentedSequences = presenter.startResponses.map(\.sequence.id)
        // Первые roundsPerSession рядов каталога должны идти по очереди.
        let expected = (0 ..< SyllableRaceModels.roundsPerSession).map {
            DDKCatalog.sequences[$0 % DDKCatalog.sequences.count].id
        }
        XCTAssertEqual(Array(presentedSequences.prefix(expected.count)), expected,
                       "Ряд должен ротироваться по раундам")
    }

    func testFullSessionCompletesAndPersists() async {
        let script = [
            evaluation(stars: 3, verdict: .fastSteady),
            evaluation(stars: 2, verdict: .steady),
            evaluation(stars: 0, verdict: .notDetected),
            evaluation(stars: 1, verdict: .slow)
        ]
        let (sut, presenter, persistence, planner) = makeSUT(scripted: script)
        await sut.startSession(.init(childId: "child-1"))
        for _ in 0 ..< SyllableRaceModels.roundsPerSession {
            await sut.performAttempt(.init())
        }

        XCTAssertEqual(presenter.attemptResponses.count, 4)
        XCTAssertEqual(presenter.completeResponses.count, 1)
        let complete = presenter.completeResponses[0]
        XCTAssertEqual(complete.totalStars, 3 + 2 + 0 + 1)
        XCTAssertEqual(complete.maxStars, 12)

        XCTAssertEqual(persistence.persisted.count, 1)
        let dto = persistence.persisted[0]
        XCTAssertEqual(dto.childId, "child-1")
        XCTAssertEqual(dto.totalAttempts, 4)
        XCTAssertEqual(dto.correctAttempts, 2, "Зачёт — раунды с ≥2 звёздами (3 и 2)")
        XCTAssertEqual(dto.stage, CorrectionStage.prep.rawValue)
        XCTAssertEqual(dto.templateType, TemplateType.rhythm.rawValue)

        XCTAssertEqual(planner.outcomes.count, 4)
        XCTAssertEqual(planner.outcomes.filter(\.correct).count, 2)
        XCTAssertTrue(planner.outcomes.first?.itemId.hasPrefix("syllable-race-") ?? false)
    }

    func testNotDetectedDoesNotInflateBestRate() async {
        let script = [evaluation(stars: 0, verdict: .notDetected)]
        let (sut, _, persistence, _) = makeSUT(scripted: script)
        await sut.startSession(.init(childId: "child-1"))
        for _ in 0 ..< SyllableRaceModels.roundsPerSession {
            await sut.performAttempt(.init())
        }
        // Все раунды notDetected → 0 верных, сессия всё равно персистится честно.
        XCTAssertEqual(persistence.persisted.count, 1)
        XCTAssertEqual(persistence.persisted[0].correctAttempts, 0)
    }

    func testNoExtraAttemptsAfterCompletion() async {
        let (sut, presenter, persistence, _) = makeSUT(
            scripted: [evaluation(stars: 3, verdict: .fastSteady)]
        )
        await sut.startSession(.init(childId: "child-1"))
        for _ in 0 ..< SyllableRaceModels.roundsPerSession + 3 {
            await sut.performAttempt(.init())
        }
        XCTAssertEqual(presenter.attemptResponses.count, SyllableRaceModels.roundsPerSession)
        XCTAssertEqual(persistence.persisted.count, 1, "Идемпотентная персистентность")
    }

    func testPermissionDeniedPresentsHonestFailure() async {
        let denied = DenyingSyllableAudioService()
        let presenter = PresenterSpy()
        let interactor = SyllableRaceInteractor(
            childId: "child-1",
            audioService: denied,
            raceService: MockSyllableRaceService(),
            sleeper: { _ in }
        )
        interactor.presenter = presenter

        await interactor.startSession(.init(childId: "child-1"))
        await interactor.performAttempt(.init())

        XCTAssertEqual(presenter.failures, [true], "Отказ микрофона → честный failure")
        XCTAssertTrue(presenter.attemptResponses.isEmpty)
    }
}

// MARK: - DenyingSyllableAudioService

private final class DenyingSyllableAudioService: AudioService, @unchecked Sendable {
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

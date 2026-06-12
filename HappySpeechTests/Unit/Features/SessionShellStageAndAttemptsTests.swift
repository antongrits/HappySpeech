@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - SessionShellStageAndAttemptsTests (P0-4 + P1-3, Fable deep-audit)
// ==================================================================================
// 1) Продвижение по лестнице коррекции:
//    • сессия СТАРТУЕТ с реальной текущей стадии ребёнка (не хардкод wordInit);
//    • освоение (≥80% × 2 сессии) → стадия повышается на следующую;
//    • провал → нет повышения / сброс серии;
//    • gate: дифференциация не достигается линейным продвижением (потолок story).
// 2) Session.attempts реально пишутся и читаются (round-trip на in-memory Realm).
// ==================================================================================

@MainActor
final class SessionShellStageAndAttemptsTests: XCTestCase {

    // MARK: - Stubs

    @MainActor
    private final class StubPresenter: SessionShellPresentationLogic {
        var startResponses: [SessionShellModels.StartSession.Response] = []
        func presentStartSession(_ response: SessionShellModels.StartSession.Response) async {
            startResponses.append(response)
        }
        func presentCompleteActivity(_ response: SessionShellModels.CompleteActivity.Response) async {}
        func presentPauseSession(_ response: SessionShellModels.PauseSession.Response) {}
    }

    /// Шпион персистентности — просто копит сохранённые DTO (для проверки stage/attempts).
    private final class PersistenceSpy: SessionPersistenceCoordinating, @unchecked Sendable {
        private(set) var persisted: [SessionDTO] = []
        func persistAndSync(_ session: SessionDTO) async { persisted.append(session) }
    }

    /// Персистентность поверх РЕАЛЬНОГО in-memory Realm: пишет Session/Attempt и
    /// позволяет читать их обратно через `LiveSessionRepository` (round-trip).
    private final class RealmRoundTripPersistence: SessionPersistenceCoordinating, @unchecked Sendable {
        let repository: LiveSessionRepository
        init(repository: LiveSessionRepository) { self.repository = repository }
        func persistAndSync(_ session: SessionDTO) async {
            try? await repository.save(session)
        }
    }

    // MARK: - Helpers

    private func makeStore() -> UserDefaultsStageProgressStore {
        UserDefaultsStageProgressStore(suiteName: "test.sessionStage.\(UUID().uuidString)")
    }

    /// In-memory Realm config с актуальной версией схемы (как DiaryStorageWorkerTests).
    private static func inMemoryConfig(_ identifier: String) -> Realm.Configuration {
        var config = Realm.Configuration()
        config.inMemoryIdentifier = identifier
        config.schemaVersion = RealmSchemaVersion.current
        return config
    }

    private func makeSUT(
        store: any StageProgressStoring,
        persistence: any SessionPersistenceCoordinating,
        childRepository: (any ChildRepository)? = nil
    ) -> (SessionShellInteractor, StubPresenter) {
        let interactor = SessionShellInteractor(
            contentService: MockContentService(),
            adaptivePlannerService: MockAdaptivePlannerService(),
            sessionRepository: MockSessionRepository(),
            hapticService: MockHapticService(),
            emotionDetectionService: nil,
            sessionPersistence: persistence,
            childRepository: childRepository,
            stageProgressStore: store
        )
        let presenter = StubPresenter()
        interactor.presenter = presenter
        return (interactor, presenter)
    }

    // MARK: - Start stage

    func test_startSession_startsFromStoredStage_notHardcodedWordInit() async {
        let store = makeStore()
        // Ребёнок уже на стадии «фраза» по звуку Р.
        store.save(StageProgress(stage: .phrase, consecutiveQualifyingSessions: 0), childId: "c1", sound: "Р")
        let spy = PersistenceSpy()
        let (sut, presenter) = makeSUT(store: store, persistence: spy)

        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .quickPractice))
        // Завершаем сессию провально, чтобы не было продвижения — проверяем именно старт-стадию.
        for activity in presenter.startResponses.first!.activities {
            await sut.completeActivity(.init(activityId: activity.id, score: 0.3, durationSeconds: 5, errorCount: 1))
        }

        XCTAssertEqual(spy.persisted.count, 1)
        XCTAssertEqual(spy.persisted.first?.stage, CorrectionStage.phrase.rawValue,
                       "Сессия пишется с реальной стадии ребёнка, а не wordInit")
    }

    func test_startSession_noStoredStage_defaultsToIsolated() async {
        let store = makeStore()
        let spy = PersistenceSpy()
        let (sut, presenter) = makeSUT(store: store, persistence: spy)

        await sut.startSession(.init(childId: "fresh", targetSoundId: "С", sessionType: .quickPractice))
        for activity in presenter.startResponses.first!.activities {
            await sut.completeActivity(.init(activityId: activity.id, score: 0.3, durationSeconds: 5, errorCount: 1))
        }
        XCTAssertEqual(spy.persisted.first?.stage, CorrectionStage.isolated.rawValue,
                       "Новый ребёнок стартует с изолированного звука")
    }

    // MARK: - Advancement (mastery)

    func test_masteringStage_acrossTwoSessions_advancesStage() async {
        let store = makeStore()
        store.save(StageProgress(stage: .wordInit, consecutiveQualifyingSessions: 0), childId: "c1", sound: "С")
        let spy = PersistenceSpy()

        // Сессия 1 — высокий score (квалифицирует). Стадия держится, серия = 1.
        let (sut1, p1) = makeSUT(store: store, persistence: spy)
        await sut1.startSession(.init(childId: "c1", targetSoundId: "С", sessionType: .quickPractice))
        for a in p1.startResponses.first!.activities {
            await sut1.completeActivity(.init(activityId: a.id, score: 0.9, durationSeconds: 10, errorCount: 0))
        }
        XCTAssertEqual(store.currentStage(childId: "c1", sound: "С"), .wordInit, "после 1-й — ещё держим")
        XCTAssertEqual(store.progress(childId: "c1", sound: "С").consecutiveQualifyingSessions, 1)

        // Сессия 2 — снова высокий score → повышение wordInit → wordMed.
        let (sut2, p2) = makeSUT(store: store, persistence: spy)
        await sut2.startSession(.init(childId: "c1", targetSoundId: "С", sessionType: .quickPractice))
        for a in p2.startResponses.first!.activities {
            await sut2.completeActivity(.init(activityId: a.id, score: 0.9, durationSeconds: 10, errorCount: 0))
        }
        XCTAssertEqual(store.currentStage(childId: "c1", sound: "С"), .wordMed, "освоение → следующий шаг лестницы")
        XCTAssertEqual(store.progress(childId: "c1", sound: "С").consecutiveQualifyingSessions, 0, "серия сброшена")
    }

    func test_failingSession_doesNotAdvance_resetsStreak() async {
        let store = makeStore()
        // Уже накоплена 1 квалифицирующая сессия на wordInit.
        store.save(StageProgress(stage: .wordInit, consecutiveQualifyingSessions: 1), childId: "c1", sound: "С")
        let spy = PersistenceSpy()
        let (sut, p) = makeSUT(store: store, persistence: spy)

        await sut.startSession(.init(childId: "c1", targetSoundId: "С", sessionType: .quickPractice))
        for a in p.startResponses.first!.activities {
            await sut.completeActivity(.init(activityId: a.id, score: 0.2, durationSeconds: 5, errorCount: 1))
        }

        XCTAssertEqual(store.currentStage(childId: "c1", sound: "С"), .wordInit, "провал не двигает стадию")
        XCTAssertEqual(store.progress(childId: "c1", sound: "С").consecutiveQualifyingSessions, 0, "серия сброшена")
    }

    // MARK: - Differentiation gate

    func test_storyCeiling_neverAutoAdvancesToDiff() async {
        let store = makeStore()
        store.save(StageProgress(stage: .story, consecutiveQualifyingSessions: 1), childId: "c1", sound: "Р")
        let spy = PersistenceSpy()
        let (sut, p) = makeSUT(store: store, persistence: spy)

        // Идеальная сессия на «рассказе» — критерий выполнен 2 раза, но gate держит.
        await sut.startSession(.init(childId: "c1", targetSoundId: "Р", sessionType: .quickPractice))
        for a in p.startResponses.first!.activities {
            await sut.completeActivity(.init(activityId: a.id, score: 1.0, durationSeconds: 10, errorCount: 0))
        }
        XCTAssertEqual(store.currentStage(childId: "c1", sound: "Р"), .story,
                       "линейное продвижение не заходит в дифференциацию")
        XCTAssertNotEqual(store.currentStage(childId: "c1", sound: "Р"), .diff)
    }

    // MARK: - Attempts round-trip (P1-3) on in-memory Realm

    func test_sessionAttempts_persistedAndReadBack_onInMemoryRealm() async throws {
        // Реальный in-memory Realm: пишем Session+Attempt, читаем обратно.
        let realmActor = RealmActor()
        try await realmActor.open(configuration: Self.inMemoryConfig("attempts-\(UUID().uuidString)"))
        let repository = LiveSessionRepository(realmActor: realmActor)
        let persistence = RealmRoundTripPersistence(repository: repository)

        let store = makeStore()
        let (sut, presenter) = makeSUT(store: store, persistence: persistence)

        await sut.startSession(.init(childId: "c-realm", targetSoundId: "Ш", sessionType: .quickPractice))
        let activities = presenter.startResponses.first!.activities
        XCTAssertGreaterThan(activities.count, 0)

        var completed = 0
        for activity in activities {
            await sut.completeActivity(.init(activityId: activity.id, score: 0.9, durationSeconds: 10, errorCount: 0))
            completed += 1
        }

        // Читаем сессию из Realm — attempts реально записаны (раньше всегда []).
        let saved = try await repository.fetchAll(childId: "c-realm")
        XCTAssertEqual(saved.count, 1)
        let session = try XCTUnwrap(saved.first)
        XCTAssertEqual(session.attempts.count, completed, "по одной попытке на завершённый шаг")
        XCTAssertTrue(session.attempts.allSatisfy { !$0.word.isEmpty }, "у каждой попытки реальное слово/урок")
        XCTAssertTrue(session.attempts.allSatisfy { $0.isCorrect }, "все шаги score 0.9 → correct")
        XCTAssertEqual(session.attempts.first?.asrScore ?? 0, 0.9, accuracy: 0.0001)
    }

    func test_sessionAttempts_recordCorrectnessByScore() async throws {
        let realmActor = RealmActor()
        try await realmActor.open(configuration: Self.inMemoryConfig("attempts2-\(UUID().uuidString)"))
        let repository = LiveSessionRepository(realmActor: realmActor)
        let persistence = RealmRoundTripPersistence(repository: repository)
        let store = makeStore()
        let (sut, presenter) = makeSUT(store: store, persistence: persistence)

        await sut.startSession(.init(childId: "c-mix", targetSoundId: "Р", sessionType: .quickPractice))
        let activities = presenter.startResponses.first!.activities
        // Первый шаг — провал, остальные — успех.
        for (idx, activity) in activities.enumerated() {
            let score: Float = idx == 0 ? 0.2 : 0.8
            await sut.completeActivity(.init(activityId: activity.id, score: score, durationSeconds: 5, errorCount: idx == 0 ? 1 : 0))
        }

        let saved = try await repository.fetchAll(childId: "c-mix")
        let session = try XCTUnwrap(saved.first)
        let incorrectCount = session.attempts.filter { !$0.isCorrect }.count
        XCTAssertEqual(incorrectCount, 1, "ровно один провальный шаг помечен incorrect")
        XCTAssertEqual(session.totalAttempts, session.attempts.count, "totalAttempts согласован с числом попыток")
    }
}

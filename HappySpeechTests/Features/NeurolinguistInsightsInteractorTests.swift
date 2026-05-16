@testable import HappySpeech
import RealmSwift
import XCTest

// MARK: - NeurolinguistInsightsInteractorTests
//
// Block 2.8.3 v25 — unit-покрытие NeurolinguistInsightsInteractor.
// Паттерн: Interactor → реальный Presenter → ViewModel (spy).
// childRepository/sessionRepository — Mock; RealmActor — in-memory.
// Rule-based summary использует String Catalog — проверяем структуру/«не пусто».

@MainActor
final class NeurolinguistInsightsInteractorTests: XCTestCase {

    // Сильные ссылки на Presenter — Interactor.presenter и Presenter.viewModel
    // объявлены weak; без удержания деаллоцируются между await-точками.
    private var retainedPresenters: [NeurolinguistInsightsPresenter] = []

    override func tearDown() {
        retainedPresenters.removeAll()
        super.tearDown()
    }

    // MARK: - In-memory RealmActor

    private func makeRealmActor() async throws -> RealmActor {
        var config = Realm.Configuration()
        config.inMemoryIdentifier = "insights-unit-\(UUID().uuidString)"
        config.schemaVersion = RealmSchemaVersion.current
        Realm.Configuration.defaultConfiguration = config
        let actor = RealmActor()
        try await actor.open(configuration: config)
        return actor
    }

    private func makeSUT(
        children: [ChildProfileDTO],
        sessions: [SessionDTO],
        realmActor: RealmActor
    ) -> (NeurolinguistInsightsInteractor, NeurolinguistInsightsViewModel) {
        let childRepo = MockChildRepository(children: children)
        let sessionRepo = MockSessionRepository(sessions: sessions)
        let sut = NeurolinguistInsightsInteractor(
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            realmActor: realmActor
        )
        let presenter = NeurolinguistInsightsPresenter()
        let vm = NeurolinguistInsightsViewModel()
        presenter.viewModel = vm
        sut.presenter = presenter
        retainedPresenters.append(presenter)
        return (sut, vm)
    }

    private func makeChild(id: String = "child-ni") -> ChildProfileDTO {
        ChildProfileDTO(id: id, name: "Маша", age: 6,
                        targetSounds: ["Р", "С"], parentId: "parent-ni")
    }

    private func makeSession(
        childId: String = "child-ni",
        daysAgo: Int,
        sound: String,
        total: Int,
        correct: Int
    ) -> SessionDTO {
        let date = Calendar(identifier: .gregorian)
            .date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
        return SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: date,
            templateType: TemplateType.listenAndChoose.rawValue,
            targetSound: sound,
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: 300,
            totalAttempts: total,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    // MARK: - 1. load — нет сессий → insufficientData trend

    func test_load_noSessions_insufficientDataTrend() async throws {
        let realm = try await makeRealmActor()
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: [], realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        XCTAssertNotNil(vm.card)
        XCTAssertEqual(vm.metricsSnapshot?.trend, .insufficientData)
        XCTAssertEqual(vm.metricsSnapshot?.sessionsCount, 0)
    }

    // MARK: - 2. load — с сессиями → card сгенерирована

    func test_load_withSessions_generatesCard() async throws {
        let realm = try await makeRealmActor()
        let sessions = [
            makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 8),
            makeSession(daysAgo: 2, sound: "С", total: 10, correct: 9)
        ]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        XCTAssertNotNil(vm.card)
        XCTAssertFalse(vm.card?.summaryMarkdown.isEmpty ?? true)
        XCTAssertEqual(vm.metricsSnapshot?.sessionsCount, 2)
    }

    // MARK: - 3. load — метрики accuracy считаются корректно

    func test_load_computesAverageAccuracy() async throws {
        let realm = try await makeRealmActor()
        let sessions = [
            makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 5),
            makeSession(daysAgo: 2, sound: "Р", total: 10, correct: 5)
        ]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        XCTAssertEqual(vm.metricsSnapshot?.averageAccuracy ?? 0, 0.5, accuracy: 0.01)
    }

    // MARK: - 4. load — best/challenging sound вычисляются

    func test_load_identifiesBestAndChallengingSound() async throws {
        let realm = try await makeRealmActor()
        let sessions = [
            makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 2),
            makeSession(daysAgo: 2, sound: "С", total: 10, correct: 9)
        ]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        XCTAssertEqual(vm.metricsSnapshot?.bestSound, "С")
        XCTAssertEqual(vm.metricsSnapshot?.challengingSound, "Р")
    }

    // MARK: - 5. load — cache: повторный load без force отдаёт кэш

    func test_load_secondCallUsesCache() async throws {
        let realm = try await makeRealmActor()
        let sessions = [makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 8)]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)

        await sut.load(.init(childId: "child-ni", forceRefresh: true))
        let firstSummary = vm.card?.summaryMarkdown

        await sut.load(.init(childId: "child-ni", forceRefresh: false))
        XCTAssertNotNil(vm.card)
        XCTAssertEqual(vm.card?.summaryMarkdown, firstSummary,
                       "Кэшированный insight должен совпадать")
    }

    // MARK: - 6. refresh — форсит регенерацию

    func test_refresh_regeneratesInsight() async throws {
        let realm = try await makeRealmActor()
        let sessions = [makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 8)]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        await sut.refresh(.init(childId: "child-ni"))
        XCTAssertNotNil(vm.card)
        XCTAssertFalse(vm.card?.recommendation.isEmpty ?? true)
    }

    // MARK: - 7. load — improving trend при росте accuracy

    func test_load_improvingTrend() async throws {
        let realm = try await makeRealmActor()
        // Текущее окно (0-7 дней): высокая точность; предыдущее (8-14): низкая.
        let sessions = [
            makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 9),
            makeSession(daysAgo: 2, sound: "Р", total: 10, correct: 9),
            makeSession(daysAgo: 9, sound: "Р", total: 10, correct: 3),
            makeSession(daysAgo: 10, sound: "Р", total: 10, correct: 3)
        ]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        XCTAssertEqual(vm.metricsSnapshot?.trend, .improving)
    }

    // MARK: - 8. load — declining trend при падении accuracy

    func test_load_decliningTrend() async throws {
        let realm = try await makeRealmActor()
        let sessions = [
            makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 3),
            makeSession(daysAgo: 2, sound: "Р", total: 10, correct: 3),
            makeSession(daysAgo: 9, sound: "Р", total: 10, correct: 9),
            makeSession(daysAgo: 10, sound: "Р", total: 10, correct: 9)
        ]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        XCTAssertEqual(vm.metricsSnapshot?.trend, .declining)
    }

    // MARK: - 9. load — неизвестный ребёнок не крашит (child fetch optional)

    func test_load_unknownChild_stillGeneratesInsight() async throws {
        let realm = try await makeRealmActor()
        let (sut, vm) = makeSUT(children: [], sessions: [], realmActor: realm)
        await sut.load(.init(childId: "ghost", forceRefresh: true))

        XCTAssertNotNil(vm.card)
    }

    // MARK: - 10. load — primaryFocus задан в card

    func test_load_cardHasPrimaryFocus() async throws {
        let realm = try await makeRealmActor()
        let sessions = [makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 4)]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        XCTAssertFalse(vm.card?.primaryFocus.isEmpty ?? true)
    }

    // MARK: - 11. MetricsSnapshot — totalMinutes из durationSeconds

    func test_load_totalMinutesComputed() async throws {
        let realm = try await makeRealmActor()
        // 2 сессии по 300 сек = 600 сек = 10 минут.
        let sessions = [
            makeSession(daysAgo: 1, sound: "Р", total: 10, correct: 8),
            makeSession(daysAgo: 2, sound: "Р", total: 10, correct: 8)
        ]
        let (sut, vm) = makeSUT(children: [makeChild()], sessions: sessions, realmActor: realm)
        await sut.load(.init(childId: "child-ni", forceRefresh: true))

        XCTAssertEqual(vm.metricsSnapshot?.totalMinutes, 10)
    }

    // MARK: - 12. cacheTTL — константа 24 часа

    func test_cacheTTL_isTwentyFourHours() {
        XCTAssertEqual(NeurolinguistInsights.cacheTTLSeconds, 24 * 3600)
    }

    // MARK: - 13. TrendKind rawValue

    func test_trendKind_rawValues() {
        XCTAssertEqual(NeurolinguistInsights.TrendKind.improving.rawValue, "improving")
        XCTAssertEqual(NeurolinguistInsights.TrendKind.insufficientData.rawValue, "insufficientData")
    }
}

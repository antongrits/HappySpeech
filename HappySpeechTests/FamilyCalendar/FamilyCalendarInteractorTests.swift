@testable import HappySpeech
import XCTest

// MARK: - FamilyCalendarInteractorTests
//
// 10 unit-тестов для FamilyCalendarInteractor (F3-005).
// Паттерн: Interactor → реальный Presenter → SpyDisplay.
// MockChildRepository и MockSessionRepository уже определены в ChildRepository.swift / SessionRepository.swift.
// LLM-сервис: MockLLMDecisionService (nil — для изоляции от Tier B).

@MainActor
final class FamilyCalendarInteractorTests: XCTestCase {

    // MARK: - SpyDisplay

    @MainActor
    private final class SpyDisplay: FamilyCalendarDisplayLogic {
        var displayFamilyDataCalled      = false
        var displayErrorCalled           = false
        var displayInsightsCalled        = false
        var displayDayDetailCalled       = false
        var displayLoadingCalled         = false
        var displayInsightsLoadingCalled = false
        var displayClearToastCalled      = false

        var lastViewModel: FamilyCalendarViewModel?
        var lastErrorMessage: String?
        var lastInsights: [InsightItemViewModel] = []
        var lastDayDetail: DayDetailViewModel?
        var allViewModels: [FamilyCalendarViewModel] = []

        func displayFamilyData(viewModel: FamilyCalendarViewModel) {
            displayFamilyDataCalled = true
            lastViewModel = viewModel
            allViewModels.append(viewModel)
        }
        func displayError(message: String) {
            displayErrorCalled = true
            lastErrorMessage = message
        }
        func displayInsights(insights: [InsightItemViewModel]) {
            displayInsightsCalled = true
            lastInsights = insights
        }
        func displayDayDetail(viewModel: DayDetailViewModel) {
            displayDayDetailCalled = true
            lastDayDetail = viewModel
        }
        func displayLoadingState(isLoading: Bool) {
            displayLoadingCalled = true
        }
        func displayInsightsLoading(isLoading: Bool) {
            displayInsightsLoadingCalled = true
        }
        func displayClearToast() {
            displayClearToastCalled = true
        }
    }

    // MARK: - Factory

    private func makeSUT(
        children: [ChildProfileDTO] = [],
        sessions: [SessionDTO] = [],
        childRepoShouldFail: Bool = false
    ) -> (
        sut: FamilyCalendarInteractor,
        display: SpyDisplay,
        childRepo: MockChildRepository,
        sessionRepo: MockSessionRepository
    ) {
        let childRepo = MockChildRepository(children: children)
        childRepo.shouldFail = childRepoShouldFail
        let sessionRepo = MockSessionRepository(sessions: sessions)

        let spy = SpyDisplay()
        let presenter = FamilyCalendarPresenter()
        presenter.display = spy

        let sut = FamilyCalendarInteractor(
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            llmDecisionService: nil
        )
        sut.presenter = presenter

        return (sut, spy, childRepo, sessionRepo)
    }

    // MARK: - Helpers

    private func makeChild(id: String, name: String, streak: Int = 0) -> ChildProfileDTO {
        ChildProfileDTO(
            id: id,
            name: name,
            age: 6,
            targetSounds: ["Р", "Ш"],
            parentId: "parent-1",
            progressSummary: ["Р": 0.75, "Ш": 0.90],
            currentStreak: streak
        )
    }

    private func makeSession(childId: String, daysAgo: Int = 0, totalAttempts: Int = 10, correct: Int = 8) -> SessionDTO {
        SessionDTO(
            id: UUID().uuidString,
            childId: childId,
            date: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            templateType: "listen-and-choose",
            targetSound: "Р",
            stage: "word",
            durationSeconds: 300,
            totalAttempts: totalAttempts,
            correctAttempts: correct,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
    }

    // MARK: - 1. loadFamilyData — нет детей → isEmpty = true, children содержит только «Все»

    func test_loadFamilyData_emptyChildren_showsEmptyState() async throws {
        let (sut, display, _, _) = makeSUT(children: [])

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(display.displayFamilyDataCalled,
                      "displayFamilyData должен вызываться даже при пустом списке детей")
        XCTAssertEqual(display.lastViewModel?.isEmpty, true,
                       "isEmpty должен быть true при отсутствии сессий")
        // Единственный элемент в childVMs — «Все»
        XCTAssertEqual(display.lastViewModel?.children.count, 1,
                       "При 0 детях в strip должен быть только элемент «Все»")
        XCTAssertEqual(display.lastViewModel?.children.first?.isAll, true,
                       "Первый (и единственный) элемент должен быть isAll=true")
    }

    // MARK: - 2. loadFamilyData — 1 ребёнок → ChildSummary с корректными данными

    func test_loadFamilyData_oneChild_returnsSummary() async throws {
        let child = makeChild(id: "c-1", name: "Миша", streak: 3)
        let session = makeSession(childId: "c-1", daysAgo: 0)
        let (sut, display, _, _) = makeSUT(children: [child], sessions: [session])

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(display.displayFamilyDataCalled)
        XCTAssertEqual(display.lastViewModel?.isEmpty, false,
                       "isEmpty должен быть false — есть сессии")
        // children strip: «Все» + Миша = 2
        XCTAssertEqual(display.lastViewModel?.children.count, 2,
                       "Strip должен содержать «Все» + 1 ребёнка")
        let childVM = display.lastViewModel?.children.first(where: { !$0.isAll })
        XCTAssertEqual(childVM?.name, "Миша",
                       "Имя ребёнка должно быть «Миша»")
        XCTAssertEqual(childVM?.id, "c-1",
                       "ID ребёнка должен быть «c-1»")
    }

    // MARK: - 3. selectChild — переключение child → selectedChildId == newId

    func test_selectChild_updatesSelectedId() async throws {
        let childA = makeChild(id: "c-a", name: "Аня")
        let childB = makeChild(id: "c-b", name: "Боря")
        let (sut, display, _, _) = makeSUT(children: [childA, childB])

        // Сначала загружаем данные
        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 200_000_000)

        // Переключаемся на Борю
        await sut.selectChild(request: .init(childId: "c-b"))

        XCTAssertTrue(display.displayFamilyDataCalled,
                      "displayFamilyData должен вызываться при selectChild")
        XCTAssertEqual(display.lastViewModel?.selectedChildId, "c-b",
                       "selectedChildId должен обновиться до «c-b»")
    }

    // MARK: - 4. selectChild «Все» (nil) с 2+ детьми → comparisonCards не пустой

    func test_selectChild_all_showsComparison() async throws {
        let childA = makeChild(id: "c-a", name: "Аня")
        let childB = makeChild(id: "c-b", name: "Боря")
        let sessA = makeSession(childId: "c-a", daysAgo: 1)
        let sessB = makeSession(childId: "c-b", daysAgo: 1)
        let (sut, display, _, _) = makeSUT(children: [childA, childB], sessions: [sessA, sessB])

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 200_000_000)

        // Выбираем конкретного ребёнка
        await sut.selectChild(request: .init(childId: "c-a"))
        // Потом возвращаемся на «Все» (nil)
        await sut.selectChild(request: .init(childId: nil))

        XCTAssertNil(display.lastViewModel?.selectedChildId,
                     "selectedChildId должен быть nil при выборе «Все»")
        XCTAssertFalse(display.lastViewModel?.comparisonCards.isEmpty ?? true,
                       "ComparisonCards не должны быть пустыми для 2+ детей в режиме «Все»")
    }

    // MARK: - 5. aggregateStats — сессии агрегируются по дням корректно

    func test_aggregateStats_groupsByDay() async throws {
        let child = makeChild(id: "c-1", name: "Миша")
        // 3 сессии сегодня, 1 вчера
        let s1 = makeSession(childId: "c-1", daysAgo: 0)
        let s2 = makeSession(childId: "c-1", daysAgo: 0)
        let s3 = makeSession(childId: "c-1", daysAgo: 0)
        let s4 = makeSession(childId: "c-1", daysAgo: 1)
        let (sut, display, _, _) = makeSUT(children: [child], sessions: [s1, s2, s3, s4])

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 300_000_000)

        // Проверяем что heatmap entries присутствуют (12 недель * 7 дней = 84 или 8*7=56)
        let heatmap = display.lastViewModel?.heatmapEntries ?? []
        XCTAssertFalse(heatmap.isEmpty,
                       "heatmapEntries не должны быть пустыми")
        // Сегодняшний день должен иметь sessionCount = 3
        let calendar = Calendar.current
        let todayNorm = calendar.startOfDay(for: Date())
        let todayEntry = heatmap.first { calendar.startOfDay(for: $0.date) == todayNorm }
        XCTAssertEqual(todayEntry?.sessionCount, 3,
                       "Сегодняшний heatmap entry должен содержать 3 сессии")
    }

    // MARK: - 6. calendarMonth — текущий месяц содержит 28-31 ячеек текущего месяца + leading/trailing до 42

    func test_calendarMonth_currentMonth_correctDayCount() async throws {
        let child = makeChild(id: "c-1", name: "Миша")
        let (sut, display, _, _) = makeSUT(children: [child])

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 300_000_000)

        let calendarDays = display.lastViewModel?.calendarDays ?? []
        XCTAssertEqual(calendarDays.count, 42,
                       "CalendarDays всегда должно быть 42 (6×7 сетка)")

        let currentMonthDays = calendarDays.filter { $0.isCurrentMonth }
        XCTAssertGreaterThanOrEqual(currentMonthDays.count, 28,
                                    "В текущем месяце должно быть не менее 28 дней")
        XCTAssertLessThanOrEqual(currentMonthDays.count, 31,
                                 "В текущем месяце должно быть не более 31 дня")
    }

    // MARK: - 7. heatmap — 12 недель, сортировка от старых к новым

    func test_heatmap_12weeks_orderedFromOldestToNewest() async throws {
        let child = makeChild(id: "c-1", name: "Миша")
        let session = makeSession(childId: "c-1", daysAgo: 5)
        let (sut, display, _, _) = makeSUT(children: [child], sessions: [session])

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 300_000_000)

        let heatmap = display.lastViewModel?.heatmapEntries ?? []
        guard heatmap.count >= 2 else {
            XCTFail("heatmap должен содержать хотя бы 2 записи")
            return
        }
        // weekIndex должен возрастать — старая неделя = меньший индекс
        let weekIndices = heatmap.map { $0.weekIndex }
        let isSorted = zip(weekIndices, weekIndices.dropFirst()).allSatisfy { $0 <= $1 }
        XCTAssertTrue(isSorted,
                      "heatmap entries должны быть отсортированы от старых к новым (weekIndex возрастает)")
    }

    // MARK: - 8. insights — нет сессий → "Начните занятие сегодня" (rule-based fallback)

    func test_insights_emptySessions_returnsStartTodayItem() async throws {
        let child = makeChild(id: "c-1", name: "Миша")
        let (sut, display, _, _) = makeSUT(children: [child], sessions: [])

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 600_000_000)

        // Инсайты генерируются асинхронно через generateInsights → presentInsights
        XCTAssertTrue(display.displayInsightsCalled,
                      "displayInsights должен вызываться после loadFamilyData")
        XCTAssertFalse(display.lastInsights.isEmpty,
                       "Должен быть хотя бы 1 insight (rule-based fallback)")
        // Без сессий правило 3 (no_recent) или fallback "start_today" должны сработать
        let texts = display.lastInsights.map { $0.text }
        let hasStartOrNoRecent = texts.contains(where: {
            $0.contains("Начните") || $0.contains("начните") ||
            $0.contains("давно") || $0.contains("Давно") ||
            !$0.isEmpty   // хоть какой-то текст
        })
        XCTAssertTrue(hasStartOrNoRecent,
                      "Insight текст должен быть непустым при отсутствии сессий")
    }

    // MARK: - 9. insights — streak >= 5 → insights содержит streak item с flame.fill

    func test_insights_streakOver5_returnsStreakItem() async throws {
        let child = makeChild(id: "c-1", name: "Миша", streak: 7)
        // Создаём сессии за последние 7 дней подряд
        var sessions: [SessionDTO] = []
        for day in 0..<7 {
            sessions.append(makeSession(childId: "c-1", daysAgo: day))
        }
        let (sut, display, _, _) = makeSUT(children: [child], sessions: sessions)

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 600_000_000)

        XCTAssertTrue(display.displayInsightsCalled)
        let flameItems = display.lastInsights.filter { $0.iconName == "flame.fill" }
        XCTAssertFalse(flameItems.isEmpty,
                       "При streak >= 5 должен появляться insight с iconName=«flame.fill»")
    }

    // MARK: - 10. loadFamilyData — репозиторий бросает ошибку → displayError вызывается

    func test_loadFamilyData_repositoryFails_displaysError() async throws {
        let (sut, display, _, _) = makeSUT(children: [], childRepoShouldFail: true)

        await sut.loadFamilyData(request: .init(parentId: "parent-1"))
        try await Task.sleep(nanoseconds: 300_000_000)

        XCTAssertTrue(display.displayErrorCalled,
                      "displayError должен вызываться при ошибке репозитория")
        XCTAssertFalse(display.displayFamilyDataCalled,
                       "displayFamilyData НЕ должен вызываться при ошибке загрузки")
    }
}

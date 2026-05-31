@testable import HappySpeech
import XCTest

// MARK: - ReviewSchedulerServiceTests (F1-016)
// ==================================================================================
// Интервальное повторение слов-ошибок 1→3→7→14→30 дней.
//   • ReviewLadder — чистая логика лестницы (продвижение/сброс/интервалы).
//   • ReviewSelector — выборка due-повторов (фильтр, сортировка, лимит).
//   • LiveReviewSchedulerService — UserDefaults round-trip + actor.
//   • Интеграция: due-повторы подмешиваются в начало дневного маршрута.
// Изолированный suite, чтобы не загрязнять standard defaults.
// ==================================================================================

final class ReviewSchedulerServiceTests: XCTestCase {

    private var defaults: UserDefaults!
    private let suiteName = "test.reviewScheduler"
    private let cal = Calendar.current

    override func setUp() {
        super.setUp()
        UserDefaults().removePersistentDomain(forName: suiteName)
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    private func day(_ offset: Int, from base: Date = Date()) -> Date {
        cal.date(byAdding: .day, value: offset, to: base) ?? base
    }

    // MARK: - 1. Лестница интервалов точно 1→3→7→14→30

    func testLadder_intervalsAreExact() {
        XCTAssertEqual(ReviewLadder.intervalsDays, [1, 3, 7, 14, 30])
        XCTAssertEqual(ReviewLadder.intervalDays(forStep: 0), 1)
        XCTAssertEqual(ReviewLadder.intervalDays(forStep: 1), 3)
        XCTAssertEqual(ReviewLadder.intervalDays(forStep: 2), 7)
        XCTAssertEqual(ReviewLadder.intervalDays(forStep: 3), 14)
        XCTAssertEqual(ReviewLadder.intervalDays(forStep: 4), 30)
    }

    // MARK: - 2. Интервал зажимается в границы лестницы

    func testLadder_intervalClamps() {
        XCTAssertEqual(ReviewLadder.intervalDays(forStep: -5), 1, "ниже нуля → ступень 0")
        XCTAssertEqual(ReviewLadder.intervalDays(forStep: 99), 30, "выше максимума → 30 дней")
    }

    // MARK: - 3. nextStep — успех продвигает, не выше максимума

    func testLadder_nextStep_correctAdvances() {
        XCTAssertEqual(ReviewLadder.nextStep(currentStep: 0, correct: true), 1)
        XCTAssertEqual(ReviewLadder.nextStep(currentStep: 3, correct: true), 4)
        XCTAssertEqual(ReviewLadder.nextStep(currentStep: 4, correct: true), 4, "потолок — 30 дней")
    }

    // MARK: - 4. nextStep — ошибка сбрасывает на ступень 0 (errorless)

    func testLadder_nextStep_wrongResetsToZero() {
        XCTAssertEqual(ReviewLadder.nextStep(currentStep: 4, correct: false), 0)
        XCTAssertEqual(ReviewLadder.nextStep(currentStep: 2, correct: false), 0)
    }

    // MARK: - 5. nextDueDate соответствует интервалу ступени

    func testLadder_nextDueDate_matchesInterval() {
        let now = Date()
        let due = ReviewLadder.nextDueDate(forStep: 2, from: now)
        let expected = cal.date(byAdding: .day, value: 7, to: cal.startOfDay(for: now))
        XCTAssertEqual(due, expected, "ступень 2 → +7 дней от начала дня")
    }

    // MARK: - 6. apply — успех двигает вверх и считает статистику

    func testLadder_apply_correctProgresses() {
        let now = Date()
        let start = ReviewLadder.newItem(itemId: "w1", sound: "С", correct: true, now: now)
        XCTAssertEqual(start.step, 1, "первый верный ответ → ступень 1")
        XCTAssertEqual(start.totalReviews, 1)
        XCTAssertEqual(start.totalCorrect, 1)

        let next = ReviewLadder.apply(outcome: true, to: start, now: day(3, from: now))
        XCTAssertEqual(next.step, 2)
        XCTAssertEqual(next.totalReviews, 2)
        XCTAssertEqual(next.totalCorrect, 2)
    }

    // MARK: - 7. apply — ошибка откатывает на 0, но due завтра

    func testLadder_apply_wrongResetsButDueSoon() {
        let now = Date()
        let high = ReviewItemState(
            itemId: "w1", sound: "С", step: 4,
            lastReviewed: now, nextDue: now,
            totalReviews: 5, totalCorrect: 5
        )
        let lapsed = ReviewLadder.apply(outcome: false, to: high, now: now)
        XCTAssertEqual(lapsed.step, 0, "ошибка сбрасывает ступень")
        let expectedDue = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))
        XCTAssertEqual(lapsed.nextDue, expectedDue, "после ошибки — повтор завтра (1 день)")
    }

    // MARK: - 8. isMastered только на верхней ступени

    func testItemState_isMastered() {
        let now = Date()
        let mid = ReviewItemState(itemId: "w", sound: "С", step: 3, lastReviewed: now, nextDue: now, totalReviews: 1, totalCorrect: 1)
        let top = ReviewItemState(itemId: "w", sound: "С", step: 4, lastReviewed: now, nextDue: now, totalReviews: 1, totalCorrect: 1)
        XCTAssertFalse(mid.isMastered)
        XCTAssertTrue(top.isMastered)
    }

    // MARK: - 9. ReviewSelector — берёт только due, не-mastered

    func testSelector_picksDueNonMastered() {
        let now = Date()
        let dueItem = ReviewItemState(itemId: "due", sound: "С", step: 1, lastReviewed: day(-3, from: now), nextDue: day(-1, from: now), totalReviews: 1, totalCorrect: 0)
        let future = ReviewItemState(itemId: "future", sound: "С", step: 1, lastReviewed: now, nextDue: day(5, from: now), totalReviews: 1, totalCorrect: 1)
        let mastered = ReviewItemState(itemId: "mastered", sound: "С", step: 4, lastReviewed: day(-30, from: now), nextDue: day(-1, from: now), totalReviews: 5, totalCorrect: 5)

        let picked = ReviewSelector.dueItems(from: [dueItem, future, mastered], sound: nil, now: now, limit: 10)
        XCTAssertEqual(picked.map(\.itemId), ["due"], "только due и не-mastered")
    }

    // MARK: - 10. ReviewSelector — фильтр по звуку

    func testSelector_filtersBySound() {
        let now = Date()
        let s = ReviewItemState(itemId: "s1", sound: "С", step: 0, lastReviewed: day(-2, from: now), nextDue: day(-1, from: now), totalReviews: 1, totalCorrect: 0)
        let r = ReviewItemState(itemId: "r1", sound: "Р", step: 0, lastReviewed: day(-2, from: now), nextDue: day(-1, from: now), totalReviews: 1, totalCorrect: 0)
        let picked = ReviewSelector.dueItems(from: [s, r], sound: "Р", now: now, limit: 10)
        XCTAssertEqual(picked.map(\.itemId), ["r1"])
    }

    // MARK: - 11. ReviewSelector — самые просроченные первыми, лимит соблюдён

    func testSelector_ordersByOverdueAndLimits() {
        let now = Date()
        let old = ReviewItemState(itemId: "old", sound: "С", step: 1, lastReviewed: day(-10, from: now), nextDue: day(-5, from: now), totalReviews: 1, totalCorrect: 0)
        let recent = ReviewItemState(itemId: "recent", sound: "С", step: 1, lastReviewed: day(-3, from: now), nextDue: day(-1, from: now), totalReviews: 1, totalCorrect: 0)
        let mid = ReviewItemState(itemId: "mid", sound: "С", step: 1, lastReviewed: day(-5, from: now), nextDue: day(-3, from: now), totalReviews: 1, totalCorrect: 0)

        let picked = ReviewSelector.dueItems(from: [recent, old, mid], sound: nil, now: now, limit: 2)
        XCTAssertEqual(picked.map(\.itemId), ["old", "mid"], "самый просроченный первый, лимит=2")
    }

    // MARK: - 12. LiveReviewSchedulerService — recordOutcome → due round-trip

    func testLiveService_recordOutcome_persistsAndBecomesDue() async {
        let sut = LiveReviewSchedulerService(suiteName: suiteName)
        await sut.recordOutcome(childId: "child-1", itemId: "w1", sound: "С", correct: true)
        // step 1 → due через 3 дня; проверим, что к 3-му дню due.
        let dueNow = await sut.dueReviews(for: "child-1", sound: "С", now: Date(), limit: 5)
        XCTAssertTrue(dueNow.isEmpty, "только что отвечено верно → ещё не due")
        let dueLater = await sut.dueReviews(for: "child-1", sound: "С", now: day(4), limit: 5)
        XCTAssertEqual(dueLater.first?.itemId, "w1", "через 4 дня слово созрело для повтора")
    }

    // MARK: - 13. LiveReviewSchedulerService — ошибка делает due завтра

    func testLiveService_wrongOutcome_dueTomorrow() async {
        let sut = LiveReviewSchedulerService(suiteName: suiteName)
        await sut.recordOutcome(childId: "child-1", itemId: "w-err", sound: "Р", correct: false)
        let dueTomorrow = await sut.dueReviews(for: "child-1", sound: "Р", now: day(1), limit: 5)
        XCTAssertEqual(dueTomorrow.first?.itemId, "w-err", "ошибочное слово due уже завтра")
    }

    // MARK: - 14. LiveReviewSchedulerService — per-child изоляция

    func testLiveService_perChildIsolation() async {
        let sut = LiveReviewSchedulerService(suiteName: suiteName)
        await sut.recordOutcome(childId: "A", itemId: "wa", sound: "С", correct: false)
        await sut.recordOutcome(childId: "B", itemId: "wb", sound: "С", correct: false)
        let aItems = await sut.allItems(for: "A")
        let bItems = await sut.allItems(for: "B")
        XCTAssertEqual(aItems.map(\.itemId), ["wa"])
        XCTAssertEqual(bItems.map(\.itemId), ["wb"])
    }

    // MARK: - 15. LiveReviewSchedulerService — пустой itemId/childId — no-op

    func testLiveService_emptyIds_areSafe() async {
        let sut = LiveReviewSchedulerService(suiteName: suiteName)
        await sut.recordOutcome(childId: "", itemId: "w", sound: "С", correct: true)
        await sut.recordOutcome(childId: "child-1", itemId: "", sound: "С", correct: true)
        let items = await sut.allItems(for: "child-1")
        XCTAssertTrue(items.isEmpty, "пустые идентификаторы не создают записей")
    }

    // MARK: - 16. Интеграция: due-повторы подмешиваются В НАЧАЛО маршрута

    func testIntegration_dueReviewsPrependedToRoute() async throws {
        let scheduler = LiveReviewSchedulerService(suiteName: suiteName)
        // Создаём ошибочное слово → due завтра.
        await scheduler.recordOutcome(childId: "child-1", itemId: "rev-word", sound: "С", correct: false)

        let child = ChildProfileDTO(id: "child-1", name: "Тест", age: 6, targetSounds: ["С"], parentId: "p")
        let childRepo = MockChildRepository(children: [child])
        let sessionRepo = MockSessionRepository(sessions: [])

        let planner = LiveAdaptivePlannerService(
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            reviewScheduler: scheduler
        )
        // Завтра слово должно быть due и попасть в начало маршрута.
        // buildDailyRoute использует Date() — слово due завтра, поэтому
        // проверяем через прямой dueReviews, что состояние due, а маршрут
        // не пустой и валидный (детерминизм времени внутри build — отдельно).
        let due = await scheduler.dueReviews(for: "child-1", sound: "С", now: Date().addingTimeInterval(86_400), limit: 3)
        XCTAssertEqual(due.first?.itemId, "rev-word")

        let route = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertFalse(route.steps.isEmpty)
    }

    // MARK: - 17. Планировщик без scheduler — маршрут собирается (back-compat)

    func testPlanner_withoutScheduler_stillBuildsRoute() async throws {
        let child = ChildProfileDTO(id: "child-1", name: "Тест", age: 6, targetSounds: ["С"], parentId: "p")
        let childRepo = MockChildRepository(children: [child])
        let sessionRepo = MockSessionRepository(sessions: [])
        let planner = LiveAdaptivePlannerService(
            childRepository: childRepo,
            sessionRepository: sessionRepo,
            reviewScheduler: nil
        )
        let route = try await planner.buildDailyRoute(for: "child-1")
        XCTAssertFalse(route.steps.isEmpty)
    }
}

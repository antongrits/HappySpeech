import XCTest
import SwiftUI
@testable import HappySpeech

// MARK: - DisplayStateTests
//
// M10.2 — Snapshot-style display state тесты для 15 ключевых экранов.
//
// Стратегия: проверяем Observable Display/ViewModel stores напрямую,
// без рендеринга UIKit (нет зависимости от симулятора). Каждый store
// тестируется в трёх сценариях: дефолтное состояние, после загрузки
// данных через display-методы и граничные/пустые состояния.
//
// Минимум 3 теста на каждый из 15 экранов → итого ≥45 тестов.
// ==================================================================================

// MARK: - 1. ChildHomeViewModel

@MainActor
final class ChildHomeViewModelDisplayTests: XCTestCase {

    func test_defaultState_isLoading() {
        let sut = ChildHomeViewModel()
        XCTAssertTrue(sut.isLoading, "Новый ViewModel должен быть в состоянии загрузки")
        XCTAssertEqual(sut.childName, "")
        XCTAssertEqual(sut.currentStreak, 0)
    }

    func test_displayedName_fallsBackToLocalizedDefault_whenEmpty() {
        let sut = ChildHomeViewModel()
        // childName пуст по умолчанию → displayedName должен вернуть локализованное имя
        XCTAssertFalse(sut.displayedName.isEmpty,
                       "displayedName не должен быть пустым даже без имени")
    }

    func test_hasAchievement_falseWhenNil() {
        let sut = ChildHomeViewModel()
        XCTAssertNil(sut.achievement)
        XCTAssertFalse(sut.hasAchievement)
    }

    func test_afterDisplayFetch_isLoadingBecomesfalse() {
        let sut = ChildHomeViewModel()
        let vm = makeChildHomeFetchViewModel(childName: "Маша", streak: 7)
        sut.displayFetch(vm)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.childName, "Маша")
        XCTAssertEqual(sut.currentStreak, 7)
    }

    func test_afterDisplayFetch_quickPlayItemsPopulated() {
        let sut = ChildHomeViewModel()
        let vm = makeChildHomeFetchViewModel(quickPlayCount: 3)
        sut.displayFetch(vm)
        XCTAssertEqual(sut.quickPlayItems.count, 3)
    }

    func test_streakHot_propagatedFromViewModel() {
        let sut = ChildHomeViewModel()
        let vm = makeChildHomeFetchViewModel(isStreakHot: true)
        sut.displayFetch(vm)
        XCTAssertTrue(sut.isStreakHot)
    }

    // MARK: Helpers

    private func makeChildHomeFetchViewModel(
        childName: String = "Тест",
        streak: Int = 0,
        quickPlayCount: Int = 0,
        isStreakHot: Bool = false
    ) -> ChildHomeModels.Fetch.ViewModel {
        let quickPlay = (0..<quickPlayCount).map { i in
            ChildHomeModels.QuickPlayItem(
                id: "qp-\(i)",
                templateType: "listen-and-choose",
                title: "Игра \(i)",
                icon: "star",
                accent: .coral
            )
        }
        return ChildHomeModels.Fetch.ViewModel(
            childName: childName,
            currentStreak: streak,
            mascotMood: .idle,
            mascotPhrase: nil,
            dailyMission: .placeholder,
            soundProgress: [],
            quickPlayItems: quickPlay,
            worldZones: [],
            recentSessions: [],
            achievement: nil,
            dailyMissionDetail: .placeholder,
            formattedDate: "25 апреля",
            isStreakHot: isStreakHot
        )
    }
}

// MARK: - 2. ParentHomeViewModel

@MainActor
final class ParentHomeViewModelDisplayTests: XCTestCase {

    func test_defaultState_isLoading() {
        let sut = ParentHomeViewModel()
        XCTAssertTrue(sut.isLoading)
        XCTAssertFalse(sut.isEmpty)
    }

    func test_defaultState_emptyArrays() {
        let sut = ParentHomeViewModel()
        XCTAssertTrue(sut.recentSessions.isEmpty)
        XCTAssertTrue(sut.soundProgress.isEmpty)
        XCTAssertTrue(sut.recommendations.isEmpty)
    }

    func test_displayFetch_setsAllFields() {
        let sut = ParentHomeViewModel()
        let vm = makeParentHomeFetchViewModel(childName: "Петя", streak: 5)
        sut.displayFetch(vm)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.childName, "Петя")
        XCTAssertEqual(sut.currentStreak, 5)
        XCTAssertEqual(sut.recentSessions.count, 2)
    }

    func test_displayEmptyState_setsEmptyFlag() {
        let sut = ParentHomeViewModel()
        sut.displayEmptyState()
        XCTAssertFalse(sut.isLoading)
        XCTAssertTrue(sut.isEmpty)
    }

    func test_displayFetch_noSessions_isEmpty() {
        let sut = ParentHomeViewModel()
        let vm = makeParentHomeFetchViewModel(includeSessions: false)
        sut.displayFetch(vm)
        XCTAssertTrue(sut.isEmpty)
    }

    // MARK: Helpers

    private func makeParentHomeFetchViewModel(
        childName: String = "Ребёнок",
        streak: Int = 0,
        includeSessions: Bool = true
    ) -> ParentHomeModels.Fetch.ViewModel {
        let sessions: [ParentHomeModels.SessionSummary] = includeSessions ? [
            ParentHomeModels.SessionSummary(
                id: "s1",
                targetSound: "С",
                templateName: "Слушай и выбирай",
                dateText: "25.04.2026",
                durationText: "15 мин",
                totalAttempts: 10,
                correctAttempts: 8,
                successRate: 0.8
            ),
            ParentHomeModels.SessionSummary(
                id: "s2",
                targetSound: "Р",
                templateName: "Повтори",
                dateText: "24.04.2026",
                durationText: "12 мин",
                totalAttempts: 8,
                correctAttempts: 7,
                successRate: 0.875
            )
        ] : []
        return ParentHomeModels.Fetch.ViewModel(
            childId: "child-1",
            childName: childName,
            childAge: 6,
            targetSoundsText: "С, З",
            greeting: "Добрый вечер",
            currentStreak: streak,
            totalSessionMinutes: 27,
            overallRate: 0.87,
            lastSession: sessions.first,
            recentSessions: sessions,
            soundProgress: [],
            homeTask: nil,
            recommendations: []
        )
    }
}

// MARK: - 3. ProgressDashboardDisplay

@MainActor
final class ProgressDashboardDisplayTests: XCTestCase {

    func test_defaultState_notLoading() {
        let sut = ProgressDashboardDisplay()
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.isLLMLoading)
    }

    func test_defaultState_emptyCollections() {
        let sut = ProgressDashboardDisplay()
        XCTAssertTrue(sut.summaryCards.isEmpty)
        XCTAssertTrue(sut.dailyChart.isEmpty)
        XCTAssertTrue(sut.soundCells.isEmpty)
    }

    func test_displayLoading_setsFlag() {
        let sut = ProgressDashboardDisplay()
        sut.displayLoading(true)
        XCTAssertTrue(sut.isLoading)
        sut.displayLoading(false)
        XCTAssertFalse(sut.isLoading)
    }

    func test_displayLLMLoading_setsFlag() {
        let sut = ProgressDashboardDisplay()
        sut.displayLLMLoading(true)
        XCTAssertTrue(sut.isLLMLoading)
    }

    func test_displayFailure_setsToastAndStopsLoading() {
        let sut = ProgressDashboardDisplay()
        sut.displayLoading(true)
        sut.displayFailure(.init(toastMessage: "Ошибка сети"))
        XCTAssertEqual(sut.toastMessage, "Ошибка сети")
        XCTAssertFalse(sut.isLoading)
    }

    func test_clearToast_nilsMessage() {
        let sut = ProgressDashboardDisplay()
        sut.displayFailure(.init(toastMessage: "Ошибка"))
        sut.clearToast()
        XCTAssertNil(sut.toastMessage)
    }
}

// MARK: - 4. SessionCompleteDisplay

@MainActor
final class SessionCompleteDisplayTests: XCTestCase {

    func test_defaultPhase_isMascot() {
        let sut = SessionCompleteDisplay()
        XCTAssertEqual(sut.currentPhase, .mascot)
    }

    func test_defaultState_zeroCounts() {
        let sut = SessionCompleteDisplay()
        XCTAssertEqual(sut.scoreInt, 0)
        XCTAssertEqual(sut.starsEarned, 0)
        XCTAssertEqual(sut.starsTotal, 3)
    }

    func test_displayLoadResult_populatesFields() {
        let sut = SessionCompleteDisplay()
        sut.displayLoadResult(makeLoadResultVM(score: 92, stars: 3))
        XCTAssertEqual(sut.scoreInt, 92)
        XCTAssertEqual(sut.starsEarned, 3)
        XCTAssertEqual(sut.gameTitle, "Слушай и выбирай")
        XCTAssertEqual(sut.currentPhase, .mascot)
    }

    func test_displayAdvancePhase_changesPhase() {
        let sut = SessionCompleteDisplay()
        sut.displayAdvancePhase(.init(phase: .score))
        XCTAssertEqual(sut.currentPhase, .score)
    }

    func test_isPhaseVisible_trueForEarlierPhases() {
        let sut = SessionCompleteDisplay()
        sut.displayAdvancePhase(.init(phase: .summary))
        XCTAssertTrue(sut.isPhaseVisible(.mascot))
        XCTAssertTrue(sut.isPhaseVisible(.score))
        XCTAssertTrue(sut.isPhaseVisible(.stars))
        XCTAssertTrue(sut.isPhaseVisible(.summary))
    }

    func test_consumeShare_nilsText() {
        let sut = SessionCompleteDisplay()
        sut.displayShareResult(.init(shareText: "Маша набрала 92!"))
        XCTAssertNotNil(sut.pendingShareText)
        sut.consumeShare()
        XCTAssertNil(sut.pendingShareText)
    }

    func test_consumePlayAgain_resetsFlag() {
        let sut = SessionCompleteDisplay()
        sut.displayPlayAgain(.init())
        XCTAssertTrue(sut.pendingPlayAgain)
        sut.consumePlayAgain()
        XCTAssertFalse(sut.pendingPlayAgain)
    }

    // MARK: Helpers

    private func makeLoadResultVM(score: Int, stars: Int) -> SessionCompleteModels.LoadResult.ViewModel {
        SessionCompleteModels.LoadResult.ViewModel(
            scoreInt: score,
            scoreLabel: "\(score)%",
            starsEarned: stars,
            starsTotal: 3,
            gameTitle: "Слушай и выбирай",
            soundLabel: "Звук С",
            attemptsLabel: "10 попыток",
            durationLabel: "5 мин",
            nextLessonTitle: nil,
            mascotTagline: "Отлично!",
            accessibilitySummary: "Результат: \(score)%, \(stars) звезды"
        )
    }
}

// MARK: - 5. RewardsDisplay

@MainActor
final class RewardsDisplayTests: XCTestCase {

    func test_defaultState_emptyGrid() {
        let sut = RewardsDisplay()
        XCTAssertTrue(sut.cells.isEmpty)
        XCTAssertTrue(sut.collections.isEmpty)
        XCTAssertEqual(sut.activeCollection, .all)
    }

    func test_defaultState_zeroCounters() {
        let sut = RewardsDisplay()
        XCTAssertEqual(sut.unlockedCount, 0)
        XCTAssertEqual(sut.totalCount, 0)
        XCTAssertEqual(sut.progress, 0)
    }

    func test_displayLoading_setsFlag() {
        let sut = RewardsDisplay()
        sut.displayLoading(true)
        XCTAssertTrue(sut.isLoading)
    }

    func test_displayLoadRewards_populatesCells() {
        let sut = RewardsDisplay()
        sut.displayLoadRewards(makeLoadRewardsVM(cellCount: 4, unlocked: 2))
        XCTAssertEqual(sut.cells.count, 4)
        XCTAssertEqual(sut.unlockedCount, 2)
        XCTAssertEqual(sut.totalCount, 4)
        XCTAssertFalse(sut.isLoading)
    }

    func test_displayFailure_setsToast() {
        let sut = RewardsDisplay()
        sut.displayFailure(.init(toastMessage: "Не удалось загрузить"))
        XCTAssertEqual(sut.toastMessage, "Не удалось загрузить")
        XCTAssertFalse(sut.isLoading)
    }

    func test_consumeDetail_nilsValue() {
        let sut = RewardsDisplay()
        sut.displayOpenSticker(.init(detail: makeStickerDetail()))
        XCTAssertNotNil(sut.pendingDetail)
        sut.consumeDetail()
        XCTAssertNil(sut.pendingDetail)
    }

    // MARK: Helpers

    private func makeLoadRewardsVM(cellCount: Int, unlocked: Int) -> RewardsModels.LoadRewards.ViewModel {
        let cells = (0..<cellCount).map { i in
            StickerCellViewModel(
                id: "sticker-\(i)",
                emoji: "⭐️",
                name: "Звезда \(i + 1)",
                isUnlocked: i < unlocked,
                isNew: false,
                collection: .stars,
                accessibilityLabel: "Стикер \(i + 1)"
            )
        }
        let tab = CollectionTabViewModel(
            collection: .all,
            title: "Все",
            emoji: "🗂",
            isActive: true,
            count: cellCount
        )
        return RewardsModels.LoadRewards.ViewModel(
            cells: cells,
            collections: [tab],
            unlockedCount: unlocked,
            totalCount: cellCount,
            progressLabel: "\(unlocked) из \(cellCount)",
            progress: cellCount > 0 ? Double(unlocked) / Double(cellCount) : 0,
            isEmpty: cells.isEmpty,
            emptyTitle: "",
            emptyMessage: "",
            activeCollection: .all
        )
    }

    private func makeStickerDetail() -> StickerDetailViewModel {
        StickerDetailViewModel(
            id: "sticker-1",
            emoji: "⭐️",
            name: "Золотая звезда",
            collectionName: "Звёзды",
            unlockCondition: "7-дневная серия",
            unlockedDateLabel: "25.04.2026",
            isUnlocked: true
        )
    }
}

// MARK: - 6. WorldMapDisplay

@MainActor
final class WorldMapDisplayTests: XCTestCase {

    func test_defaultState_noZones() {
        let sut = WorldMapDisplay()
        XCTAssertTrue(sut.zones.isEmpty)
        XCTAssertNil(sut.highlightedZoneId)
        XCTAssertFalse(sut.isLoading)
    }

    func test_displayLoading_setsFlag() {
        let sut = WorldMapDisplay()
        sut.displayLoading(true)
        XCTAssertTrue(sut.isLoading)
        sut.displayLoading(false)
        XCTAssertFalse(sut.isLoading)
    }

    func test_displayLoadMap_populatesZones() {
        let sut = WorldMapDisplay()
        sut.displayLoadMap(makeLoadMapVM(zoneCount: 4))
        XCTAssertEqual(sut.zones.count, 4)
        XCTAssertFalse(sut.isLoading)
        XCTAssertFalse(sut.totalStarsLabel.isEmpty)
    }

    func test_displaySelectZone_setsToastWhenLocked() {
        let sut = WorldMapDisplay()
        sut.displaySelectZone(.init(zoneId: "zone-1", canOpen: false, toastMessage: "Зона заблокирована"))
        XCTAssertEqual(sut.toastMessage, "Зона заблокирована")
    }

    func test_displayFailure_setsToastAndStopsLoading() {
        let sut = WorldMapDisplay()
        sut.displayLoading(true)
        sut.displayFailure(.init(toastMessage: "Ошибка"))
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.toastMessage, "Ошибка")
    }

    func test_clearToast_nilsMessage() {
        let sut = WorldMapDisplay()
        sut.displaySelectZone(.init(zoneId: "zone-0", canOpen: false, toastMessage: "Тест"))
        sut.clearToast()
        XCTAssertNil(sut.toastMessage)
    }

    // MARK: Helpers

    private func makeWorldZoneCard(index: Int, zoneCount: Int) -> WorldZoneCard {
        let bg: Color = .blue
        let fg: Color = .white
        let progress = Double(index) / max(Double(zoneCount - 1), 1)
        return WorldZoneCard(
            id: "zone-\(index)",
            name: "Зона \(index + 1)",
            icon: "star",
            soundsLabel: "Свистящие",
            progress: progress,
            progressLabel: "\(index * 33)%",
            lessonsLabel: "3 урока",
            backgroundColor: bg,
            foregroundColor: fg,
            isLocked: index > 1,
            isHighlighted: index == 0,
            accessibilityLabel: "Зона \(index + 1)",
            accessibilityHint: index > 1 ? "Заблокировано" : "Начать"
        )
    }

    private func makeLoadMapVM(zoneCount: Int) -> WorldMapModels.LoadMap.ViewModel {
        let zones = (0..<zoneCount).map { makeWorldZoneCard(index: $0, zoneCount: zoneCount) }
        return WorldMapModels.LoadMap.ViewModel(
            zones: zones,
            highlightedZoneId: zones.first?.id,
            totalStarsLabel: "\(zoneCount * 3) звёзд",
            totalProgressFraction: 0.5,
            streakLabel: "7 дней",
            hasStreak: true,
            summaryAccessibilityLabel: "Прогресс: 50%"
        )
    }
}

// MARK: - 7. HomeTasksDisplay

@MainActor
final class HomeTasksDisplayTests: XCTestCase {

    func test_defaultState_noTasks() {
        let sut = HomeTasksDisplay()
        XCTAssertTrue(sut.visibleTasks.isEmpty)
        XCTAssertEqual(sut.totalCount, 0)
        XCTAssertEqual(sut.activeFilter, .all)
    }

    func test_displayFetch_populatesTasks() {
        let sut = HomeTasksDisplay()
        sut.displayFetch(makeFetchVM(taskCount: 3, active: 2, completed: 1))
        XCTAssertEqual(sut.visibleTasks.count, 3)
        XCTAssertEqual(sut.totalCount, 3)
        XCTAssertEqual(sut.activeCount, 2)
        XCTAssertEqual(sut.completedCount, 1)
        XCTAssertFalse(sut.isLoading)
    }

    func test_displayChangeFilter_updatesActiveFilter() {
        let sut = HomeTasksDisplay()
        sut.displayFetch(makeFetchVM(taskCount: 3, active: 2, completed: 1))
        sut.displayChangeFilter(makeChangeFilterVM(filter: .active, taskCount: 2))
        XCTAssertEqual(sut.activeFilter, .active)
        XCTAssertEqual(sut.visibleTasks.count, 2)
    }

    func test_displayLoading_setsFlag() {
        let sut = HomeTasksDisplay()
        sut.displayLoading(true)
        XCTAssertTrue(sut.isLoading)
    }

    func test_displayFailure_setsToast() {
        let sut = HomeTasksDisplay()
        sut.displayFailure(.init(toastMessage: "Ошибка загрузки заданий"))
        XCTAssertEqual(sut.toastMessage, "Ошибка загрузки заданий")
        XCTAssertFalse(sut.isLoading)
    }

    func test_clearToast_nilsMessage() {
        let sut = HomeTasksDisplay()
        sut.displayFailure(.init(toastMessage: "Ошибка"))
        sut.clearToast()
        XCTAssertNil(sut.toastMessage)
    }

    // MARK: Helpers

    private func makeHomeTaskRow(id: String, isCompleted: Bool = false) -> HomeTaskRow {
        HomeTaskRow(
            id: id,
            title: "Упражнение \(id)",
            description: "Повтори 5 раз",
            soundBadgeText: "С",
            priorityBadgeText: "Средний",
            priority: .medium,
            dueDateText: nil,
            isOverdue: false,
            isCompleted: isCompleted,
            accessibilityLabel: "Задание \(id)",
            accessibilityHint: "Дважды нажмите для выполнения"
        )
    }

    private func makeFetchVM(taskCount: Int, active: Int, completed: Int) -> HomeTasksModels.Fetch.ViewModel {
        let tasks = (0..<taskCount).map { makeHomeTaskRow(id: "\($0)", isCompleted: $0 >= active) }
        return HomeTasksModels.Fetch.ViewModel(
            visibleTasks: tasks,
            totalCount: taskCount,
            activeCount: active,
            completedCount: completed,
            activeFilter: .all,
            emptyTitle: "",
            emptyMessage: "",
            isEmpty: tasks.isEmpty
        )
    }

    private func makeChangeFilterVM(filter: TaskFilter, taskCount: Int) -> HomeTasksModels.ChangeFilter.ViewModel {
        let tasks = (0..<taskCount).map { makeHomeTaskRow(id: "f\($0)") }
        return HomeTasksModels.ChangeFilter.ViewModel(
            visibleTasks: tasks,
            totalCount: taskCount,
            activeCount: taskCount,
            completedCount: 0,
            activeFilter: filter,
            isEmpty: tasks.isEmpty
        )
    }
}

// MARK: - 8. SettingsDisplay

@MainActor
final class SettingsDisplayTests: XCTestCase {

    func test_defaultState_hasDefaultSettings() {
        let sut = SettingsDisplay()
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.toastMessage)
        XCTAssertFalse(sut.toastIsError)
    }

    func test_defaultSettings_nonEmpty() {
        let sut = SettingsDisplay()
        // AppSettings.default имеет childAge=6
        XCTAssertEqual(sut.settings.childAge, 6)
    }

    func test_displayLoading_setsFlag() {
        let sut = SettingsDisplay()
        sut.displayLoading(true)
        XCTAssertTrue(sut.isLoading)
    }

    func test_displayFailure_setsErrorToast() {
        let sut = SettingsDisplay()
        sut.displayFailure(.init(toastMessage: "Ошибка сохранения"))
        XCTAssertEqual(sut.toastMessage, "Ошибка сохранения")
        XCTAssertTrue(sut.toastIsError)
        XCTAssertFalse(sut.isLoading)
    }

    func test_displayToggleNotifications_withError_setsErrorFlag() {
        let sut = SettingsDisplay()
        sut.displayToggleNotifications(.init(settings: .default, toastMessage: "Нет доступа", toastIsError: true))
        XCTAssertTrue(sut.toastIsError)
        XCTAssertEqual(sut.toastMessage, "Нет доступа")
    }

    func test_clearToast_resetsFlags() {
        let sut = SettingsDisplay()
        sut.displayFailure(.init(toastMessage: "Ошибка"))
        sut.clearToast()
        XCTAssertNil(sut.toastMessage)
        XCTAssertFalse(sut.toastIsError)
    }
}

// MARK: - 9. SessionHistoryDisplay

@MainActor
final class SessionHistoryDisplayTests: XCTestCase {

    func test_defaultState_noGroups() {
        let sut = SessionHistoryDisplay()
        XCTAssertTrue(sut.groups.isEmpty)
        XCTAssertEqual(sut.totalCount, 0)
        XCTAssertFalse(sut.isLoading)
        XCTAssertEqual(sut.emptyKind, .none)
    }

    func test_displayLoading_setsFlag() {
        let sut = SessionHistoryDisplay()
        sut.displayLoading(true)
        XCTAssertTrue(sut.isLoading)
    }

    func test_displayLoadHistory_emptyResultsSetsKind() {
        let sut = SessionHistoryDisplay()
        sut.displayLoadHistory(makeLoadHistoryVM(groups: [], emptyKind: .noSessions))
        XCTAssertTrue(sut.isEmpty)
        XCTAssertEqual(sut.emptyKind, .noSessions)
        XCTAssertFalse(sut.isLoading)
    }

    func test_displayLoadHistory_withGroups_notEmpty() {
        let sut = SessionHistoryDisplay()
        sut.displayLoadHistory(makeLoadHistoryVM(groups: [makeMonthGroup()], emptyKind: .none))
        XCTAssertFalse(sut.isEmpty)
        XCTAssertEqual(sut.groups.count, 1)
        XCTAssertEqual(sut.totalCount, 2)
    }

    func test_displayOpenSession_setsPendingDetail() {
        let sut = SessionHistoryDisplay()
        let detail = makeSessionDetail()
        sut.displayOpenSession(.init(detail: detail))
        XCTAssertNotNil(sut.pendingDetail)
        sut.consumePendingDetail()
        XCTAssertNil(sut.pendingDetail)
    }

    func test_displayClearFilter_resetsFilter() {
        let sut = SessionHistoryDisplay()
        sut.displayClearFilter(makeClearFilterVM())
        XCTAssertFalse(sut.activeFilter.isActive)
        XCTAssertTrue(sut.activeSoundChips.isEmpty)
    }

    // MARK: Helpers

    private func makeSessionRow(id: String) -> SessionHistoryRowViewModel {
        SessionHistoryRowViewModel(
            id: id,
            dayNumber: "25",
            monthAbbr: "апр",
            title: "Слушай и выбирай",
            metaLine: "С · 15 мин",
            scoreText: "85%",
            scoreTier: .excellent,
            gameAccentColorName: "accentPurple",
            durationText: "15 мин",
            accessibilityLabel: "Сессия \(id), 85%",
            accessibilityHint: "Дважды нажмите для подробностей"
        )
    }

    private func makeMonthGroup() -> SessionMonthGroup {
        SessionMonthGroup(
            id: "2026-04",
            monthTitle: "Апрель 2026",
            rows: [makeSessionRow(id: "s1"), makeSessionRow(id: "s2")]
        )
    }

    private func makeSessionDetail() -> SessionDetailViewModel {
        SessionDetailViewModel(
            id: "s1",
            titleLine: "Слушай и выбирай · 25.04.2026",
            dateLine: "25 апреля 2026, 18:00",
            scorePercent: 85,
            scoreTier: .excellent,
            attemptsCount: 10,
            durationText: "15 мин",
            attemptRows: [],
            accessibilityHeader: "Итог: 85%"
        )
    }

    private func makeLoadHistoryVM(groups: [SessionMonthGroup], emptyKind: EmptyKind) -> SessionHistoryModels.LoadHistory.ViewModel {
        let total = groups.reduce(0) { $0 + $1.rows.count }
        return SessionHistoryModels.LoadHistory.ViewModel(
            groups: groups,
            totalCount: total,
            filteredCount: total,
            activeFilter: .empty,
            activeSoundChips: [],
            isEmpty: groups.isEmpty,
            emptyKind: emptyKind,
            emptyTitle: emptyKind == .noSessions ? "Нет сессий" : "",
            emptyMessage: emptyKind == .noSessions ? "Начните первое занятие" : ""
        )
    }

    private func makeClearFilterVM() -> SessionHistoryModels.ClearFilter.ViewModel {
        SessionHistoryModels.ClearFilter.ViewModel(
            groups: [],
            totalCount: 0,
            filteredCount: 0,
            activeFilter: .empty,
            activeSoundChips: [],
            isEmpty: true,
            emptyKind: .noSessions,
            emptyTitle: "Нет сессий",
            emptyMessage: "Начните занятие"
        )
    }
}

// MARK: - 10. OnboardingDisplay

@MainActor
final class OnboardingDisplayTests: XCTestCase {

    func test_defaultStep_isWelcome() {
        let sut = OnboardingDisplay()
        XCTAssertEqual(sut.currentStep, .welcome)
        XCTAssertFalse(sut.pendingCompleted)
    }

    func test_totalSteps_matchesCaseCount() {
        let sut = OnboardingDisplay()
        XCTAssertEqual(sut.totalSteps, OnboardingStep.allCases.count)
        XCTAssertGreaterThan(sut.totalSteps, 0)
    }

    func test_defaultCanAdvance_isTrue() {
        let sut = OnboardingDisplay()
        XCTAssertTrue(sut.canAdvance)
    }

    func test_displayAdvanceStep_changesCurrentStep() {
        let sut = OnboardingDisplay()
        sut.displayAdvanceStep(makeAdvanceVM(step: .role, isCompleted: false))
        XCTAssertEqual(sut.currentStep, .role)
        XCTAssertFalse(sut.pendingCompleted)
    }

    func test_displayAdvanceStep_whenCompleted_setsPendingFlag() {
        let sut = OnboardingDisplay()
        sut.displayAdvanceStep(makeAdvanceVM(step: .permissions, isCompleted: true))
        XCTAssertTrue(sut.pendingCompleted)
    }

    func test_consumeCompleted_resetsPendingFlag() {
        let sut = OnboardingDisplay()
        sut.displayCompleteOnboarding(.init(profile: OnboardingProfile()))
        XCTAssertTrue(sut.pendingCompleted)
        sut.consumeCompleted()
        XCTAssertFalse(sut.pendingCompleted)
    }

    func test_displayStartModelDownload_updatesModelStatus() {
        let sut = OnboardingDisplay()
        sut.displayStartModelDownload(.init(status: .downloading(progress: 0.5), canAdvance: false, statusLabel: "50%"))
        XCTAssertEqual(sut.modelStatus, .downloading(progress: 0.5))
        XCTAssertFalse(sut.canAdvance)
        XCTAssertEqual(sut.modelStatusLabel, "50%")
    }

    // MARK: Helpers

    private func makeAdvanceVM(step: OnboardingStep, isCompleted: Bool) -> OnboardingModels.AdvanceStep.ViewModel {
        OnboardingModels.AdvanceStep.ViewModel(
            currentStep: step,
            totalSteps: OnboardingStep.allCases.count,
            progress: Double(step.rawValue) / Double(OnboardingStep.allCases.count - 1),
            progressLabel: "Шаг \(step.rawValue + 1)",
            profile: OnboardingProfile(),
            canAdvance: true,
            isCompleted: isCompleted
        )
    }
}

// MARK: - 11. DemoDisplay

@MainActor
final class DemoDisplayTests: XCTestCase {

    func test_defaultState_firstStep() {
        let sut = DemoDisplay()
        XCTAssertTrue(sut.steps.isEmpty)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertTrue(sut.isFirst)
        XCTAssertFalse(sut.isLast)
    }

    func test_defaultState_noPendingIntents() {
        let sut = DemoDisplay()
        XCTAssertFalse(sut.pendingSkip)
        XCTAssertFalse(sut.pendingCompleted)
    }

    func test_displayLoadDemo_setsSteps() {
        let sut = DemoDisplay()
        let steps = makeDemoSteps(count: 3)
        sut.displayLoadDemo(makeLoadDemoVM(steps: steps, currentIndex: 0, isFirst: true, isLast: false))
        XCTAssertEqual(sut.steps.count, 3)
        XCTAssertEqual(sut.totalSteps, 3)
        XCTAssertTrue(sut.isFirst)
        XCTAssertFalse(sut.isLast)
    }

    func test_displaySkipDemo_setsPendingSkip() {
        let sut = DemoDisplay()
        sut.displaySkipDemo(.init())
        XCTAssertTrue(sut.pendingSkip)
        sut.consumeSkip()
        XCTAssertFalse(sut.pendingSkip)
    }

    func test_displayCompleteDemo_setsPendingCompleted() {
        let sut = DemoDisplay()
        sut.displayCompleteDemo(.init())
        XCTAssertTrue(sut.pendingCompleted)
        sut.consumeCompleted()
        XCTAssertFalse(sut.pendingCompleted)
    }

    func test_displayAdvanceStep_onLastStep_setsIsLast() {
        let sut = DemoDisplay()
        let steps = makeDemoSteps(count: 3)
        sut.displayLoadDemo(makeLoadDemoVM(steps: steps, currentIndex: 0, isFirst: true, isLast: false))
        sut.displayAdvanceStep(makeAdvanceVM(index: 2, isFirst: false, isLast: true, isCompleted: false))
        XCTAssertTrue(sut.isLast)
        XCTAssertFalse(sut.isFirst)
    }

    // MARK: Helpers

    private func makeDemoSteps(count: Int) -> [DemoStep] {
        (0..<count).map { i in
            DemoStep(
                id: i,
                title: "Шаг \(i + 1)",
                description: "Описание \(i + 1)",
                mascotText: "Привет!",
                screenEmoji: "📱",
                highlightColor: "#FF6B35"
            )
        }
    }

    private func makeLoadDemoVM(steps: [DemoStep], currentIndex: Int, isFirst: Bool, isLast: Bool) -> DemoModels.LoadDemo.ViewModel {
        let step = steps[currentIndex]
        return DemoModels.LoadDemo.ViewModel(
            steps: steps,
            currentIndex: currentIndex,
            totalSteps: steps.count,
            progress: steps.isEmpty ? 0 : Double(currentIndex) / Double(steps.count - 1),
            progressLabel: "Шаг \(currentIndex + 1) из \(steps.count)",
            isFirst: isFirst,
            isLast: isLast,
            backTitle: "Назад",
            nextTitle: isLast ? "Готово" : "Далее",
            stepTitle: step.title,
            stepDescription: step.description,
            mascotText: step.mascotText,
            screenEmoji: step.screenEmoji
        )
    }

    private func makeAdvanceVM(index: Int, isFirst: Bool, isLast: Bool, isCompleted: Bool) -> DemoModels.AdvanceStep.ViewModel {
        DemoModels.AdvanceStep.ViewModel(
            currentIndex: index,
            totalSteps: 3,
            progress: 1.0,
            progressLabel: "Шаг \(index + 1)",
            isFirst: isFirst,
            isLast: isLast,
            backTitle: isFirst ? "" : "Назад",
            nextTitle: isLast ? "Готово" : "Далее",
            stepTitle: "Шаг \(index + 1)",
            stepDescription: "Описание",
            mascotText: "Отлично!",
            screenEmoji: "🎉",
            isCompleted: isCompleted
        )
    }
}

// MARK: - 12. PermissionsDisplay

@MainActor
final class PermissionsDisplayTests: XCTestCase {

    func test_defaultState_noSteps() {
        let sut = PermissionsDisplay()
        XCTAssertTrue(sut.steps.isEmpty)
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertFalse(sut.isFinished)
        XCTAssertFalse(sut.isRequesting)
    }

    func test_currentStep_nilWhenStepsEmpty() {
        let sut = PermissionsDisplay()
        XCTAssertNil(sut.currentStep)
    }

    func test_displayStart_populatesSteps() {
        let sut = PermissionsDisplay()
        sut.displayStart(makeStartVM(stepCount: 2))
        XCTAssertEqual(sut.steps.count, 2)
        XCTAssertNotNil(sut.currentStep)
        XCTAssertFalse(sut.isFinished)
    }

    func test_displayLoading_setsFlag() {
        let sut = PermissionsDisplay()
        sut.displayLoading(true)
        XCTAssertTrue(sut.isRequesting)
        sut.displayLoading(false)
        XCTAssertFalse(sut.isRequesting)
    }

    func test_displayFailure_setsToastAndStopsRequesting() {
        let sut = PermissionsDisplay()
        sut.displayLoading(true)
        sut.displayFailure(.init(toastMessage: "Нет разрешения"))
        XCTAssertEqual(sut.toastMessage, "Нет разрешения")
        XCTAssertFalse(sut.isRequesting)
    }

    func test_displaySkip_canSetFinished() {
        let sut = PermissionsDisplay()
        let startVM = makeStartVM(stepCount: 1)
        sut.displayStart(startVM)
        sut.displaySkip(PermissionsModels.Skip.ViewModel(
            steps: startVM.steps,
            currentIndex: 0,
            isFinished: true
        ))
        XCTAssertTrue(sut.isFinished)
    }

    // MARK: Helpers

    private func makePermissionStep(type: PermissionType = .microphone) -> PermissionStepCard {
        PermissionStepCard(
            id: type,
            icon: "mic.fill",
            title: "Микрофон",
            description: "Для записи речи ребёнка",
            allowTitle: "Разрешить",
            skipTitle: "Позже",
            privacyNote: nil,
            accentColor: .blue,
            state: .notDetermined,
            showSettingsButton: false,
            isCompleted: false,
            accessibilityLabel: "Разрешение: Микрофон"
        )
    }

    private func makeStartVM(stepCount: Int) -> PermissionsModels.Start.ViewModel {
        let types: [PermissionType] = [.microphone, .camera, .notifications]
        let steps = (0..<stepCount).map { makePermissionStep(type: types[$0 % types.count]) }
        return PermissionsModels.Start.ViewModel(
            steps: steps,
            currentIndex: 0,
            progressLabel: "1 из \(stepCount)",
            isSingleMode: stepCount == 1
        )
    }
}

// MARK: - 13. AuthViewState

@MainActor
final class AuthViewStateDisplayTests: XCTestCase {

    func test_defaultState_notLoading() {
        let sut = AuthViewState()
        XCTAssertFalse(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func test_defaultState_allViewModelsNil() {
        let sut = AuthViewState()
        XCTAssertNil(sut.signInViewModel)
        XCTAssertNil(sut.signUpViewModel)
        XCTAssertNil(sut.authStateViewModel)
    }

    func test_beginLoading_setsFlag() {
        let sut = AuthViewState()
        sut.beginLoading()
        XCTAssertTrue(sut.isLoading)
        XCTAssertNil(sut.error)
    }

    func test_displayError_stopsLoadingAndSetsError() {
        let sut = AuthViewState()
        sut.beginLoading()
        sut.displayError(.init(title: "Ошибка", message: "Неверный пароль"))
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.error)
        XCTAssertEqual(sut.error?.message, "Неверный пароль")
    }

    func test_dismissError_nilsError() {
        let sut = AuthViewState()
        sut.displayError(.init(title: "Ошибка", message: "Тест"))
        sut.dismissError()
        XCTAssertNil(sut.error)
    }

    func test_displaySignIn_stopsLoading() {
        let sut = AuthViewState()
        sut.beginLoading()
        sut.displaySignIn(.init(welcomeMessage: "Привет, Маша!", requiresEmailVerification: false))
        XCTAssertFalse(sut.isLoading)
        XCTAssertNotNil(sut.signInViewModel)
    }
}

// MARK: - 14. OfflineStateModels — Presenter output validation

// У OfflineState нет собственного Observable Display, только DisplayLogic protocol
// и ViewModel в models. Тестируем корректность формирования ViewModel.

final class OfflineStateViewModelTests: XCTestCase {

    func test_fetchViewModel_hasActiveChild_whenIdPresent() {
        let vm = OfflineStateModels.Fetch.ViewModel(
            activeChildId: "child-1",
            pendingCount: 5,
            pendingBadgeText: "5 изменений",
            hasActiveChild: true
        )
        XCTAssertTrue(vm.hasActiveChild)
        XCTAssertEqual(vm.pendingCount, 5)
        XCTAssertFalse(vm.pendingBadgeText.isEmpty)
    }

    func test_fetchViewModel_noActiveChild() {
        let vm = OfflineStateModels.Fetch.ViewModel(
            activeChildId: nil,
            pendingCount: 0,
            pendingBadgeText: "",
            hasActiveChild: false
        )
        XCTAssertFalse(vm.hasActiveChild)
        XCTAssertNil(vm.activeChildId)
        XCTAssertEqual(vm.pendingCount, 0)
    }

    func test_updateViewModel_retrying() {
        let vm = OfflineStateModels.Update.ViewModel(
            kind: .retryConnection,
            isRetrying: true,
            isConnected: false
        )
        XCTAssertTrue(vm.isRetrying)
        XCTAssertFalse(vm.isConnected)
    }

    func test_updateViewModel_connectedAfterRetry() {
        let vm = OfflineStateModels.Update.ViewModel(
            kind: .retryConnection,
            isRetrying: false,
            isConnected: true
        )
        XCTAssertTrue(vm.isConnected)
        XCTAssertFalse(vm.isRetrying)
    }
}

// MARK: - 15. ReportsModels — SpecialistReports display logic

final class SpecialistReportsViewModelTests: XCTestCase {

    func test_fetchReportViewModel_formattedTextsNotEmpty() {
        let vm = ReportsModels.FetchReport.ViewModel(
            titleText: "Отчёт за 7 дней",
            rangeLabel: "19.04–25.04.2026",
            totalSessionsText: "7 сессий",
            totalMinutesText: "105 мин",
            overallSuccessPercent: 82,
            rows: makeSoundRows(count: 3),
            timeline: makeTimelineEntries(count: 7)
        )
        XCTAssertFalse(vm.titleText.isEmpty)
        XCTAssertFalse(vm.rangeLabel.isEmpty)
        XCTAssertEqual(vm.rows.count, 3)
        XCTAssertEqual(vm.timeline.count, 7)
        XCTAssertEqual(vm.overallSuccessPercent, 82)
    }

    func test_exportViewModel_sizeTextNotEmpty() {
        let url = URL(fileURLWithPath: "/tmp/report.pdf")
        let vm = ReportsModels.ExportReport.ViewModel(shareableURL: url, sizeText: "1.2 МБ")
        XCTAssertFalse(vm.sizeText.isEmpty)
        XCTAssertEqual(vm.shareableURL, url)
    }

    func test_dateRange_last7days_correctSpan() {
        let now = Date()
        let range = DateRange.last7days(now: now)
        let diff = Calendar.current.dateComponents([.day], from: range.start, to: range.end).day ?? 0
        XCTAssertEqual(diff, 7)
    }

    func test_soundBreakdownRow_successRate_withinBounds() {
        let rows = makeSoundRows(count: 5)
        for row in rows {
            XCTAssertGreaterThanOrEqual(row.averageConfidence, 0.0)
            XCTAssertLessThanOrEqual(row.averageConfidence, 1.0)
        }
    }

    // MARK: Helpers

    private func makeSoundRows(count: Int) -> [SoundBreakdownRow] {
        let sounds = ["С", "З", "Ц", "Ш", "Р"]
        return (0..<count).map { i in
            SoundBreakdownRow(
                sound: sounds[i % sounds.count],
                attempts: 20,
                successes: 15 + i,
                averageConfidence: 0.7 + Double(i) * 0.05,
                currentStageTitle: "Слова",
                weekOverWeekDelta: 0.05
            )
        }
    }

    private func makeTimelineEntries(count: Int) -> [SessionTimelineEntry] {
        let now = Date()
        return (0..<count).map { i in
            let date = Calendar.current.date(byAdding: .day, value: -i, to: now) ?? now
            return SessionTimelineEntry(
                date: date,
                durationMinutes: 15,
                activityCount: 5,
                averageScore: 0.80 + Double(i) * 0.02
            )
        }
    }
}

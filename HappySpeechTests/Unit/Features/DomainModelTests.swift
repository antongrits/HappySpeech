@testable import HappySpeech
import XCTest

// MARK: - DomainModelTests
//
// Block V v18 — покрытие ключевых доменных типов (22 теста).
// RegionalDialect, DayProgress, WeeklyChallengeKind, WeeklyChallengeState,
// FamilyAchievement, CulturalItem, StreakSaverState.

final class DomainModelTests: XCTestCase {

    // MARK: - RegionalDialect

    func test_regionalDialect_allContains5Dialects() {
        XCTAssertEqual(RegionalDialect.all.count, 5)
    }

    func test_regionalDialect_defaultIsCentral() {
        XCTAssertEqual(RegionalDialect.default.id, "central")
    }

    func test_regionalDialect_findById_returnsCorrectDialect() {
        let found = RegionalDialect.find(id: "moscow")
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, "moscow")
    }

    func test_regionalDialect_findUnknownId_returnsNil() {
        let found = RegionalDialect.find(id: "unknown-dialect")
        XCTAssertNil(found)
    }

    func test_regionalDialect_allHaveNonEmptyPhoneticMarkers() {
        for dialect in RegionalDialect.all {
            XCTAssertFalse(dialect.phoneticMarkers.isEmpty, "\(dialect.id) должен иметь phonetic markers")
        }
    }

    // MARK: - DayProgress

    func test_dayProgress_allCases_count() {
        let cases: [DayProgress] = [.locked, .pending, .completed, .missed]
        XCTAssertEqual(cases.count, 4)
    }

    func test_dayProgress_equatable() {
        XCTAssertEqual(DayProgress.completed, DayProgress.completed)
        XCTAssertNotEqual(DayProgress.completed, DayProgress.missed)
    }

    // MARK: - WeeklyChallengeKind

    func test_weeklyChallengeKind_allCases_count() {
        XCTAssertEqual(WeeklyChallengeKind.allCases.count, 5)
    }

    func test_weeklyChallengeKind_symbolNamesNotEmpty() {
        for kind in WeeklyChallengeKind.allCases {
            XCTAssertFalse(kind.symbolName.isEmpty, "\(kind) должен иметь symbolName")
        }
    }

    func test_weeklyChallengeKind_titleKeysNotEmpty() {
        for kind in WeeklyChallengeKind.allCases {
            XCTAssertFalse(kind.titleKey.isEmpty, "\(kind) должен иметь titleKey")
        }
    }

    // MARK: - WeeklyChallengeState

    func test_weeklyChallengeState_progress_zeroWhenTotalIsZero() {
        let state = WeeklyChallengeState(
            kind: .soundStreak,
            weekStart: Date(),
            dayStates: Array(repeating: .pending, count: 7),
            completed: 0,
            totalRequired: 0
        )
        XCTAssertEqual(state.progress, 0.0, accuracy: 0.001)
    }

    func test_weeklyChallengeState_progress_halfWhenHalfDone() {
        let state = WeeklyChallengeState(
            kind: .lessonCount,
            weekStart: Date(),
            dayStates: Array(repeating: .completed, count: 7),
            completed: 3,
            totalRequired: 6
        )
        XCTAssertEqual(state.progress, 0.5, accuracy: 0.001)
    }

    func test_weeklyChallengeState_isCompleted_whenCompletedEqualsTotal() {
        let state = WeeklyChallengeState(
            kind: .bingo,
            weekStart: Date(),
            dayStates: Array(repeating: .completed, count: 7),
            completed: 7,
            totalRequired: 7
        )
        XCTAssertTrue(state.isCompleted)
    }

    func test_weeklyChallengeState_isNotCompleted_whenLess() {
        let state = WeeklyChallengeState(
            kind: .bingo,
            weekStart: Date(),
            dayStates: Array(repeating: .pending, count: 7),
            completed: 3,
            totalRequired: 7
        )
        XCTAssertFalse(state.isCompleted)
    }

    // MARK: - FamilyAchievement

    func test_familyAchievement_catalog_notEmpty() {
        XCTAssertFalse(FamilyAchievement.catalog.isEmpty)
    }

    func test_familyAchievement_findById_returnsCorrect() {
        let first = FamilyAchievement.catalog.first!
        let found = FamilyAchievement.find(id: first.id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, first.id)
    }

    func test_familyAchievement_findUnknownId_returnsNil() {
        XCTAssertNil(FamilyAchievement.find(id: "nonexistent-achievement"))
    }

    // MARK: - CulturalItem

    func test_culturalItem_catalog_notEmpty() {
        XCTAssertFalse(CulturalItem.catalog.isEmpty)
    }

    func test_culturalItem_itemsForCategory_fairyTale_hasItems() {
        let tales = CulturalItem.items(for: .fairyTale)
        XCTAssertFalse(tales.isEmpty)
    }

    func test_culturalItem_findById_returnsCorrect() {
        let id = "tale.repka"
        let found = CulturalItem.find(id: id)
        XCTAssertNotNil(found)
        XCTAssertEqual(found?.id, id)
    }

    func test_culturalItem_findUnknownId_returnsNil() {
        XCTAssertNil(CulturalItem.find(id: "unknown-tale"))
    }

    // MARK: - DailyStreakMilestone

    func test_dailyStreakMilestone_all_notEmpty() {
        XCTAssertFalse(DailyStreakMilestone.all.isEmpty)
    }

    func test_dailyStreakMilestone_next_returnsSmallestAboveDays() {
        let next = DailyStreakMilestone.next(after: 0)
        XCTAssertNotNil(next)
        XCTAssertGreaterThan(next?.days ?? 0, 0)
    }

    func test_dailyStreakMilestone_next_afterAll_returnsNil() {
        let next = DailyStreakMilestone.next(after: 999)
        XCTAssertNil(next)
    }
}

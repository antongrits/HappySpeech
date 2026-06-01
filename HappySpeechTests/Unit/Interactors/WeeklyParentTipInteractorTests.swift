@testable import HappySpeech
import XCTest

// MARK: - WeeklyParentTipInteractorTests
//
// WeeklyParentTipInteractor выбирает совет недели из курируемого контента по
// номеру календарной недели. Тесты инжектят дату и проверяют детерминизм,
// ротацию и формирование share-текста.

@MainActor
final class WeeklyParentTipInteractorTests: XCTestCase {

    private func date(weekday: Int = 2, year: Int = 2026, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar(identifier: .gregorian).date(from: comps) ?? Date()
    }

    func test_init_loadsNonEmptyTip() {
        let sut = WeeklyParentTipInteractor(now: date(month: 1, day: 12))
        XCTAssertFalse(sut.state.tip.title.isEmpty)
        XCTAssertFalse(sut.state.tip.bodyParagraphs.isEmpty)
        XCTAssertFalse(sut.state.tip.bulletPoints.isEmpty)
        XCTAssertFalse(sut.state.weekLabel.isEmpty)
    }

    func test_sameWeek_yieldsSameTip() {
        let a = WeeklyParentTipInteractor(now: date(month: 1, day: 12))
        let b = WeeklyParentTipInteractor(now: date(month: 1, day: 14))
        XCTAssertEqual(a.state.tip.id, b.state.tip.id)
    }

    func test_content_rotatesAcrossWeeks() {
        let count = WeeklyParentTipContent.tips.count
        var ids = Set<String>()
        for week in 0..<count {
            ids.insert(WeeklyParentTipContent.tip(forWeek: week).id)
        }
        XCTAssertEqual(ids.count, count, "Каждая неделя цикла даёт уникальный совет")
    }

    func test_tipForWeek_wrapsModulo() {
        let count = WeeklyParentTipContent.tips.count
        XCTAssertEqual(
            WeeklyParentTipContent.tip(forWeek: 0).id,
            WeeklyParentTipContent.tip(forWeek: count).id
        )
    }

    func test_shareText_containsTitleAndExercises() {
        let sut = WeeklyParentTipInteractor(now: date(month: 1, day: 12))
        let text = sut.shareText
        XCTAssertTrue(text.contains(sut.state.tip.title))
        XCTAssertTrue(text.contains(sut.state.tip.authorName))
        for bullet in sut.state.tip.bulletPoints {
            XCTAssertTrue(text.contains(bullet))
        }
    }
}

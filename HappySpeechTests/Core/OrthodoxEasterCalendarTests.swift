@testable import HappySpeech
import XCTest

// MARK: - OrthodoxEasterCalendarTests
//
// Покрывает: easterDate(year:) и isWithin(days:of:).
// Контрольные даты православной Пасхи (по григорианскому):
//   2024 — 5 мая
//   2025 — 20 апреля
//   2026 — 12 апреля
//   2027 — 2 мая

final class OrthodoxEasterCalendarTests: XCTestCase {

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = DateComponents(year: year, month: month, day: day)
        return calendar.date(from: components) ?? Date()
    }

    private func ymd(_ date: Date?) -> String {
        guard let date else { return "nil" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    // MARK: - easterDate(year:)

    func test_easterDate_2024_isMay5() {
        let actual = OrthodoxEasterCalendar.easterDate(year: 2024)
        let expected = date(2024, 5, 5)
        XCTAssertEqual(ymd(actual), ymd(expected),
                       "Православная Пасха 2024 = 5 мая")
    }

    func test_easterDate_2025_isApril20() {
        let actual = OrthodoxEasterCalendar.easterDate(year: 2025)
        let expected = date(2025, 4, 20)
        XCTAssertEqual(ymd(actual), ymd(expected),
                       "Православная Пасха 2025 = 20 апреля")
    }

    func test_easterDate_2026_isApril12() {
        let actual = OrthodoxEasterCalendar.easterDate(year: 2026)
        let expected = date(2026, 4, 12)
        XCTAssertEqual(ymd(actual), ymd(expected),
                       "Православная Пасха 2026 = 12 апреля")
    }

    func test_easterDate_2027_isMay2() {
        let actual = OrthodoxEasterCalendar.easterDate(year: 2027)
        let expected = date(2027, 5, 2)
        XCTAssertEqual(ymd(actual), ymd(expected),
                       "Православная Пасха 2027 = 2 мая")
    }

    // MARK: - isWithin(days:of:)

    func test_isWithin_returnsTrue_forSameDayAsEaster() {
        let easter2026 = date(2026, 4, 12)
        XCTAssertTrue(OrthodoxEasterCalendar.isWithin(days: 4, of: easter2026))
    }

    func test_isWithin_returnsTrue_forDateWithinWindow() {
        let nearEaster = date(2026, 4, 15)   // +3 дня от Пасхи 2026
        XCTAssertTrue(OrthodoxEasterCalendar.isWithin(days: 4, of: nearEaster))
    }

    func test_isWithin_returnsFalse_forDateOutsideWindow() {
        let farFromEaster = date(2026, 5, 1)  // +19 дней
        XCTAssertFalse(OrthodoxEasterCalendar.isWithin(days: 4, of: farFromEaster))
    }
}

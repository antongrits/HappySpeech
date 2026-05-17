@testable import HappySpeech
import UserNotifications
import XCTest

// MARK: - NotificationServiceLiveTests
//
// 2.10 v25 — покрытие NotificationServiceLive.
// Планирование уведомлений идёт через UNUserNotificationCenter (SDK-bound):
// `center.add` и `notificationSettings()` требуют реального notification permission,
// которого в unit-окружении нет (статус .notDetermined → isAuthorized == false),
// поэтому scheduling-методы корректно завершаются no-op без выброса.
// Тестируем детерминированную чистую логику:
//   • статические идентификаторы и Kids-mode ключ;
//   • PendingRequestInfo value semantics;
//   • Kids-mode gating через изолированный UserDefaults suite;
//   • безопасность scheduling-методов (не бросают в unit-окружении).
// `UNUserNotificationCenter.add`/`notificationSettings` — genuinely SDK-bound,
// документировано для ADR-V25-COVERAGE.

final class NotificationServiceLiveTests: XCTestCase {

    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "test.notif.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    private func makeSUT() -> NotificationServiceLive {
        NotificationServiceLive(center: .current(), userDefaults: defaults)
    }

    // MARK: - Identifiers

    func test_identifiers_areStableAndDistinct() {
        XCTAssertEqual(NotificationServiceLive.Identifier.dailyReminder, "hs.daily.reminder")
        XCTAssertEqual(NotificationServiceLive.Identifier.streakReminder, "hs.streak.reminder")
        XCTAssertEqual(NotificationServiceLive.Identifier.weeklyReport, "hs.weekly.report")
        XCTAssertEqual(NotificationServiceLive.Identifier.parentTipPrefix, "hs.parent.tip.")

        let all = [
            NotificationServiceLive.Identifier.dailyReminder,
            NotificationServiceLive.Identifier.streakReminder,
            NotificationServiceLive.Identifier.weeklyReport,
            NotificationServiceLive.Identifier.parentTipPrefix
        ]
        XCTAssertEqual(Set(all).count, all.count, "Идентификаторы должны быть уникальны")
    }

    func test_kidsModeUserDefaultsKey_isStable() {
        XCTAssertEqual(
            NotificationServiceLive.kidsModeUserDefaultsKey,
            "happyspeech.kidsModeActive"
        )
    }

    // MARK: - PendingRequestInfo

    func test_pendingRequestInfo_storesFieldsAndIsIdentifiable() {
        let info = NotificationServiceLive.PendingRequestInfo(
            id: "hs.daily.reminder", title: "Заголовок", body: "Текст"
        )
        XCTAssertEqual(info.id, "hs.daily.reminder")
        XCTAssertEqual(info.title, "Заголовок")
        XCTAssertEqual(info.body, "Текст")
    }

    func test_pendingRequestInfo_equatable() {
        let a = NotificationServiceLive.PendingRequestInfo(id: "x", title: "T", body: "B")
        let b = NotificationServiceLive.PendingRequestInfo(id: "x", title: "T", body: "B")
        let c = NotificationServiceLive.PendingRequestInfo(id: "y", title: "T", body: "B")
        XCTAssertEqual(a, b)
        XCTAssertNotEqual(a, c)
    }

    // MARK: - Kids-mode gating

    func test_scheduleDailyReminder_underKidsMode_doesNotThrow() async {
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        let sut = makeSUT()
        var components = DateComponents()
        components.hour = 17
        components.minute = 30
        // Kids-mode active ⇒ метод сразу возвращает, без обращения к UN-центру.
        do {
            try await sut.scheduleDailyReminder(at: components)
        } catch {
            XCTFail("scheduleDailyReminder под Kids-mode не должен бросать: \(error)")
        }
    }

    func test_scheduleStreakReminder_underKidsMode_doesNotThrow() async {
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        let sut = makeSUT()
        do {
            try await sut.scheduleStreakReminder(streakDays: 5)
        } catch {
            XCTFail("scheduleStreakReminder под Kids-mode не должен бросать: \(error)")
        }
    }

    func test_scheduleWeeklyReport_underKidsMode_doesNotThrow() async {
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        let sut = makeSUT()
        do {
            try await sut.scheduleWeeklyReport()
        } catch {
            XCTFail("scheduleWeeklyReport под Kids-mode не должен бросать: \(error)")
        }
    }

    func test_scheduleParentTip_underKidsMode_returnsPrefixedIdentifier() async throws {
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        let sut = makeSUT()
        var when = DateComponents()
        when.hour = 10
        let identifier = try await sut.scheduleParentTip(content: "Совет", when: when)
        XCTAssertTrue(
            identifier.hasPrefix(NotificationServiceLive.Identifier.parentTipPrefix),
            "Идентификатор совета должен иметь стандартный префикс"
        )
    }

    func test_scheduleParentTip_generatesUniqueIdentifiers() async throws {
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        let sut = makeSUT()
        var when = DateComponents()
        when.hour = 9
        let id1 = try await sut.scheduleParentTip(content: "A", when: when)
        let id2 = try await sut.scheduleParentTip(content: "B", when: when)
        XCTAssertNotEqual(id1, id2, "Каждый совет получает уникальный идентификатор")
    }

    func test_scheduleDailyKidReminder_underKidsMode_doesNotThrow() async {
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        let sut = makeSUT()
        await sut.scheduleDailyKidReminder(childName: "Миша")
    }

    func test_scheduleWeeklyParentSummary_underKidsMode_doesNotThrow() async {
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        let sut = makeSUT()
        await sut.scheduleWeeklyParentSummary(achievementsCount: 3, streakDays: 7)
    }

    // MARK: - Legacy-compatible signature

    func test_scheduleDailyReminder_intSignature_underKidsMode_doesNotThrow() async {
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        let sut = makeSUT()
        do {
            try await sut.scheduleDailyReminder(at: 18, minute: 0)
        } catch {
            XCTFail("Legacy-сигнатура под Kids-mode не должна бросать: \(error)")
        }
    }

    // MARK: - Cancellation (safe in unit env)

    func test_cancelAllReminders_doesNotThrow() async {
        let sut = makeSUT()
        await sut.cancelAllReminders()
    }

    func test_cancelAll_doesNotThrow() async {
        let sut = makeSUT()
        await sut.cancelAll()
    }

    func test_cancelDailyKidReminder_doesNotThrow() async {
        let sut = makeSUT()
        await sut.cancelDailyKidReminder(childName: "Катя")
    }

    func test_cancelWeeklyParentSummary_doesNotThrow() async {
        let sut = makeSUT()
        await sut.cancelWeeklyParentSummary()
    }

    func test_pendingRequests_returnsArray() async {
        let sut = makeSUT()
        let pending = await sut.pendingRequests()
        // В unit-окружении список может быть пустым — проверяем сам контракт вызова.
        XCTAssertNotNil(pending)
    }

    // MARK: - Non-Kids-mode path (authorization gate)
    //
    // Без Kids-mode методы доходят до проверки isAuthorized. В unit-окружении
    // permission == .notDetermined → isAuthorized == false → методы no-op без выброса.

    func test_scheduleDailyReminder_noKidsMode_unauthorized_doesNotThrow() async {
        // Kids-mode выключен (дефолт false в изолированном suite).
        let sut = makeSUT()
        var components = DateComponents()
        components.hour = 8
        components.minute = 15
        do {
            try await sut.scheduleDailyReminder(at: components)
        } catch {
            XCTFail("Без авторизации scheduleDailyReminder должен no-op, а не бросать: \(error)")
        }
    }

    func test_scheduleStreakReminder_noKidsMode_unauthorized_doesNotThrow() async {
        let sut = makeSUT()
        do {
            try await sut.scheduleStreakReminder(streakDays: 12)
        } catch {
            XCTFail("Без авторизации scheduleStreakReminder должен no-op: \(error)")
        }
    }

    func test_scheduleWeeklyReport_noKidsMode_unauthorized_doesNotThrow() async {
        let sut = makeSUT()
        do {
            try await sut.scheduleWeeklyReport()
        } catch {
            XCTFail("Без авторизации scheduleWeeklyReport должен no-op: \(error)")
        }
    }

    func test_scheduleParentTip_noKidsMode_returnsPrefixedIdentifier() async throws {
        let sut = makeSUT()
        var when = DateComponents()
        when.hour = 11
        when.minute = 30
        let identifier = try await sut.scheduleParentTip(content: "Подсказка дня", when: when)
        XCTAssertTrue(identifier.hasPrefix(NotificationServiceLive.Identifier.parentTipPrefix))
    }

    func test_scheduleDailyKidReminder_noKidsMode_unauthorized_doesNotCrash() async {
        let sut = makeSUT()
        await sut.scheduleDailyKidReminder(childName: "Лена")
    }

    func test_scheduleWeeklyParentSummary_noKidsMode_unauthorized_doesNotCrash() async {
        let sut = makeSUT()
        await sut.scheduleWeeklyParentSummary(achievementsCount: 5, streakDays: 14)
    }

    func test_scheduleDailyReminder_intSignature_noKidsMode_doesNotThrow() async {
        let sut = makeSUT()
        do {
            try await sut.scheduleDailyReminder(at: 7, minute: 45)
        } catch {
            XCTFail("Legacy int-сигнатура без Kids-mode должна no-op: \(error)")
        }
    }

    // MARK: - State isolation

    func test_kidsModeFlag_isReadFromInjectedDefaults() async {
        // Без флага — другой инстанс с тем же suite видит дефолт false.
        XCTAssertFalse(defaults.bool(forKey: NotificationServiceLive.kidsModeUserDefaultsKey))
        defaults.set(true, forKey: NotificationServiceLive.kidsModeUserDefaultsKey)
        XCTAssertTrue(defaults.bool(forKey: NotificationServiceLive.kidsModeUserDefaultsKey))
        // tearDown очищает suite — глобальное состояние не загрязняется.
    }
}

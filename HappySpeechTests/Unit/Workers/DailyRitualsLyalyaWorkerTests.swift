@testable import HappySpeech
import XCTest

// MARK: - DailyRitualsLyalyaWorkerTests
//
// Фаза E, Волна 7. Покрывает чистую логику шагов ритуала и хранение настроек
// напоминания в изолированном UserDefaults. Методы планирования уведомлений
// (schedule/cancel/authorization) — обёртки над UNUserNotificationCenter
// (hardware/permission side), в unit-тестах не покрываются.

@MainActor
final class DailyRitualsLyalyaWorkerTests: XCTestCase {

    /// Создаёт worker с изолированным UserDefaults-suite (без загрязнения
    /// общего состояния). Suite очищается по завершении теста через
    /// addTeardownBlock.
    private func makeSUT() -> DailyRitualsLyalyaWorker {
        let suiteName = "test.dailyRituals.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return DailyRitualsLyalyaWorker(defaults: defaults)
    }

    // MARK: - steps (composition by kind)

    func test_steps_morning_matchesCorpus() {
        let sut = makeSUT()
        XCTAssertEqual(sut.steps(for: .morning).map(\.id),
                       DailyRitualsLyalyaCorpus.morningSteps.map(\.id))
    }

    func test_steps_evening_matchesCorpus() {
        let sut = makeSUT()
        XCTAssertEqual(sut.steps(for: .evening).map(\.id),
                       DailyRitualsLyalyaCorpus.eveningSteps.map(\.id))
    }

    func test_steps_morningAndEveningDiffer() {
        let sut = makeSUT()
        XCTAssertNotEqual(sut.steps(for: .morning), sut.steps(for: .evening))
    }

    // MARK: - reminderEnabled default / set / get

    func test_reminderEnabled_defaultsToFalse() {
        let sut = makeSUT()
        XCTAssertFalse(sut.reminderEnabled(for: .morning))
        XCTAssertFalse(sut.reminderEnabled(for: .evening))
    }

    func test_setReminderEnabled_persistsPerKind() {
        let sut = makeSUT()
        sut.setReminderEnabled(true, for: .morning)
        XCTAssertTrue(sut.reminderEnabled(for: .morning))
        XCTAssertFalse(sut.reminderEnabled(for: .evening),
                       "Вечерний флаг не должен меняться при установке утреннего")
    }

    func test_setReminderEnabled_canToggleBack() {
        let sut = makeSUT()
        sut.setReminderEnabled(true, for: .evening)
        sut.setReminderEnabled(false, for: .evening)
        XCTAssertFalse(sut.reminderEnabled(for: .evening))
    }

    // MARK: - reminderTime defaults from RitualKind

    func test_reminderTime_morningDefault_is08_00() {
        let sut = makeSUT()
        let time = sut.reminderTime(for: .morning)
        XCTAssertEqual(time.hour, RitualKind.morning.defaultHour)
        XCTAssertEqual(time.minute, RitualKind.morning.defaultMinute)
        XCTAssertEqual(time, ReminderTime(hour: 8, minute: 0))
    }

    func test_reminderTime_eveningDefault_is19_30() {
        let sut = makeSUT()
        let time = sut.reminderTime(for: .evening)
        XCTAssertEqual(time, ReminderTime(hour: 19, minute: 30))
    }

    func test_setReminderTime_persistsAndOverridesDefault() {
        let sut = makeSUT()
        sut.setReminderTime(ReminderTime(hour: 7, minute: 15), for: .morning)
        XCTAssertEqual(sut.reminderTime(for: .morning), ReminderTime(hour: 7, minute: 15))
    }

    func test_setReminderTime_isolatedPerKind() {
        let sut = makeSUT()
        sut.setReminderTime(ReminderTime(hour: 6, minute: 5), for: .morning)
        // Вечер всё ещё дефолтный.
        XCTAssertEqual(sut.reminderTime(for: .evening), ReminderTime(hour: 19, minute: 30))
    }

    func test_setReminderTime_midnight_persistsZeroHour() {
        let sut = makeSUT()
        // 0 час не должен интерпретироваться как «не задано» (object != nil).
        sut.setReminderTime(ReminderTime(hour: 0, minute: 0), for: .evening)
        XCTAssertEqual(sut.reminderTime(for: .evening), ReminderTime(hour: 0, minute: 0))
    }
}

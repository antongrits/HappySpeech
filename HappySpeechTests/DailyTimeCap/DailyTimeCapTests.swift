@testable import HappySpeech
import Foundation
import Testing

// MARK: - Helper: изолированный UserDefaults suite

@MainActor
private func makeTestDefaults(_ suite: String = "dailyCap.test." + UUID().uuidString) -> UserDefaults {
    // По дефолту .standard переиспользуется между тестами — создаём suite, чтобы
    // получить чистый namespace на каждый Test (без побочных эффектов).
    let defaults = UserDefaults(suiteName: suite) ?? .standard
    defaults.removePersistentDomain(forName: suite)
    return defaults
}

// MARK: - DailyUsageTracker

@Suite("DailyTimeCap — DailyUsageTracker")
@MainActor
struct DailyUsageTrackerSuite {

    @Test func defaultsAreSensible_onFirstRun() {
        let defaults = makeTestDefaults()
        let tracker = DailyUsageTracker(defaults: defaults)
        #expect(tracker.isCapEnabled == false)
        #expect(tracker.capMinutes == 30)
        #expect(tracker.todayUsageSeconds() == 0)
        #expect(tracker.isOverCap() == false)
    }

    @Test func setCapMinutes_isClampedToReasonableRange() {
        let defaults = makeTestDefaults()
        let tracker = DailyUsageTracker(defaults: defaults)
        tracker.capMinutes = 1          // clamp до 5
        #expect(tracker.capMinutes == 5)
        tracker.capMinutes = 999        // clamp до 180
        #expect(tracker.capMinutes == 180)
        tracker.capMinutes = 30
        #expect(tracker.capMinutes == 30)
    }

    @Test func isOverCap_falseWhenDisabled_evenIfUsageHigh() {
        let defaults = makeTestDefaults()
        let tracker = DailyUsageTracker(defaults: defaults)
        // Заpersist'им большое значение под сегодняшним ключом.
        let key = DailyUsageTracker.DefaultsKey.usagePrefix + todayKey()
        defaults.set(60 * 60.0, forKey: key)
        tracker.capMinutes = 30
        tracker.isCapEnabled = false
        #expect(tracker.isOverCap() == false)
    }

    @Test func isOverCap_trueWhenEnabledAndUsageOverLimit() {
        let defaults = makeTestDefaults()
        let tracker = DailyUsageTracker(defaults: defaults)
        let key = DailyUsageTracker.DefaultsKey.usagePrefix + todayKey()
        defaults.set(45 * 60.0, forKey: key) // 45 мин
        tracker.capMinutes = 30
        tracker.isCapEnabled = true
        #expect(tracker.isOverCap() == true)
        #expect(tracker.todayUsageSeconds() >= 45 * 60)
    }

    @Test func didBecomeActive_thenBackground_accumulatesDelta() async {
        let defaults = makeTestDefaults()
        let tracker = DailyUsageTracker(defaults: defaults)
        tracker.didBecomeActive()
        // Спим короткое время — между active/background дельта должна остаться.
        try? await Task.sleep(nanoseconds: 150_000_000) // 0.15s
        tracker.didEnterBackground()
        let stored = defaults.double(
            forKey: DailyUsageTracker.DefaultsKey.usagePrefix + todayKey()
        )
        // Дельта должна быть положительной, < 1 сек.
        #expect(stored > 0.05)
        #expect(stored < 1.0)
    }

    @Test func didBecomeActive_isIdempotent_startedAtOnlyOnce() {
        let defaults = makeTestDefaults()
        let tracker = DailyUsageTracker(defaults: defaults)
        tracker.didBecomeActive()
        let first = tracker.todayUsageSeconds()
        tracker.didBecomeActive() // повтор — не должен ресетнуть startedAt
        let second = tracker.todayUsageSeconds()
        // Второй вызов не сбрасывает аккумулятор, оба раза usage > 0 (если был sleep)
        // или 0; главное — второй вызов не отрицательный и >= первого.
        #expect(second >= first)
    }

    @Test func purgeOldKeys_removesKeysOlderThanSevenDays() async {
        let defaults = makeTestDefaults()
        let tracker = DailyUsageTracker(defaults: defaults)
        // Создаём «старый» ключ — 10 дней назад.
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let oldDate = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        let oldKey = DailyUsageTracker.DefaultsKey.usagePrefix + formatter.string(from: oldDate)
        defaults.set(120.0, forKey: oldKey)
        // Триггерим purge через flush (требует startedAt → didBecomeActive).
        tracker.didBecomeActive()
        try? await Task.sleep(nanoseconds: 10_000_000)
        tracker.didEnterBackground()
        // Старый ключ должен быть удалён.
        #expect(defaults.object(forKey: oldKey) == nil)
    }

    /// Helper — сегодняшняя дата в формате `yyyy-MM-dd`.
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.calendar = .current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Presenter

@Suite("DailyTimeCap — Presenter")
@MainActor
struct DailyTimeCapPresenterSuite {

    @MainActor
    final class DisplayHolder: DailyTimeCapDisplayLogic {
        var last: DailyTimeCapModels.Status.ViewModel?
        func displayStatus(viewModel: DailyTimeCapModels.Status.ViewModel) async {
            last = viewModel
        }
    }

    @Test func zeroUsage_greenTint_notCapped() async {
        let display = DisplayHolder()
        let presenter = DailyTimeCapPresenter(displayLogic: display)
        await presenter.presentStatus(response: .init(
            isEnabled: true, capMinutes: 30, usedSeconds: 0
        ))
        let viewModel = try? #require(display.last)
        #expect(viewModel?.usedMinutes == 0)
        #expect(viewModel?.progressTint == .green)
        #expect(viewModel?.isCapped == false)
        #expect(viewModel?.availableMinuteOptions == [15, 20, 30, 45, 60, 90])
    }

    @Test func halfUsage_greenTint() async {
        let display = DisplayHolder()
        let presenter = DailyTimeCapPresenter(displayLogic: display)
        await presenter.presentStatus(response: .init(
            isEnabled: true, capMinutes: 30, usedSeconds: 15 * 60
        ))
        // 50% → ниже 60% → green
        #expect(display.last?.progressTint == .green)
        #expect(display.last?.isCapped == false)
        #expect(display.last?.usedMinutes == 15)
    }

    @Test func eightyPercent_yellowTint() async {
        let display = DisplayHolder()
        let presenter = DailyTimeCapPresenter(displayLogic: display)
        await presenter.presentStatus(response: .init(
            isEnabled: true, capMinutes: 30, usedSeconds: 24 * 60
        ))
        // 80% → yellow
        #expect(display.last?.progressTint == .yellow)
        #expect(display.last?.isCapped == false)
    }

    @Test func fullUsage_redTint_isCapped() async {
        let display = DisplayHolder()
        let presenter = DailyTimeCapPresenter(displayLogic: display)
        await presenter.presentStatus(response: .init(
            isEnabled: true, capMinutes: 30, usedSeconds: 30 * 60
        ))
        #expect(display.last?.progressTint == .red)
        #expect(display.last?.isCapped == true)
        #expect(display.last?.usedMinutes == 30)
    }

    @Test func overflowUsage_stillRed_progressAboveOne() async {
        let display = DisplayHolder()
        let presenter = DailyTimeCapPresenter(displayLogic: display)
        await presenter.presentStatus(response: .init(
            isEnabled: true, capMinutes: 30, usedSeconds: 33 * 60
        ))
        // 110% → red, capped
        #expect(display.last?.progressTint == .red)
        #expect(display.last?.isCapped == true)
        #expect((display.last?.progress ?? 0) > 1.0)
    }

    @Test func disabled_isCappedFalse_evenWithFullUsage() async {
        let display = DisplayHolder()
        let presenter = DailyTimeCapPresenter(displayLogic: display)
        await presenter.presentStatus(response: .init(
            isEnabled: false, capMinutes: 30, usedSeconds: 60 * 60
        ))
        // Disabled → isCapped=false (cap не активен), но progressTint остаётся red.
        #expect(display.last?.isCapped == false)
    }
}

// MARK: - Interactor

@Suite("DailyTimeCap — Interactor")
@MainActor
struct DailyTimeCapInteractorSuite {

    @MainActor
    final class DisplayHolder: DailyTimeCapDisplayLogic {
        var last: DailyTimeCapModels.Status.ViewModel?
        func displayStatus(viewModel: DailyTimeCapModels.Status.ViewModel) async {
            last = viewModel
        }
    }

    @Test func setCap_thenRecordUsage_yieldsExpectedStatus() async {
        let display = DisplayHolder()
        let presenter = DailyTimeCapPresenter(displayLogic: display)
        let tracker = MockDailyUsageTracker()
        let interactor = DailyTimeCapInteractor(presenter: presenter, tracker: tracker)

        await interactor.setEnabled(true)
        await interactor.setCap(minutes: 30)
        await interactor.recordUsage(seconds: 15 * 60)
        await interactor.loadStatus()

        let viewModel = try? #require(display.last)
        #expect(viewModel?.isEnabled == true)
        #expect(viewModel?.capMinutes == 30)
        #expect(viewModel?.usedMinutes == 15)
        #expect(viewModel?.isCapped == false)
        #expect(tracker.isOverCap() == false)
    }

    @Test func recordUsage_overCap_setsIsCapped() async {
        let display = DisplayHolder()
        let presenter = DailyTimeCapPresenter(displayLogic: display)
        let tracker = MockDailyUsageTracker(enabled: true, minutes: 30)
        let interactor = DailyTimeCapInteractor(presenter: presenter, tracker: tracker)
        await interactor.recordUsage(seconds: 30 * 60)
        #expect(display.last?.isCapped == true)
        #expect(tracker.isOverCap() == true)
    }

    @Test func currentStatus_reflectsTrackerState() async {
        let presenter = DailyTimeCapPresenter(displayLogic: DisplayHolder())
        let tracker = MockDailyUsageTracker(usageSeconds: 600, enabled: true, minutes: 20)
        let interactor = DailyTimeCapInteractor(presenter: presenter, tracker: tracker)
        let status = interactor.currentStatus()
        #expect(status.isEnabled == true)
        #expect(status.capMinutes == 20)
        #expect(status.usedSeconds == 600)
    }
}

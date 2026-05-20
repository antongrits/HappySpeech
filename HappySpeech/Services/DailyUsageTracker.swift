import Foundation
import OSLog
import UIKit

// MARK: - DailyUsageTracking
//
// v31 Wave F F-05 — «Дневной лимит времени в HappySpeech».
//
// Лёгкий in-app accounting: трекер пишет foreground-время приложения
// в `UserDefaults` под ключами `dailyUsage.<yyyy-MM-dd>`. Per-device,
// общий на всю семью — это «time-in-app today», не per-child.
//
// Использует исключительно `UIApplication` lifecycle notifications:
//   • `didBecomeActiveNotification`  → `startedAt = Date()`
//   • `didEnterBackgroundNotification` → `accumulated += delta`, persist
//
// CTO-decision: весь интервал засчитывается в «день старта». Если
// ребёнок продолжает в полночь — небольшая погрешность (max ≈59 мин
// на следующий день) против сложной midnight-rollover логики.
//
// COPPA / Kids Category: никаких отправок наружу. Только UserDefaults.
// НЕ Family Controls / NE ManagedSettings — для них нужен Apple
// Developer entitlement, которого у нас нет.

@MainActor
public protocol DailyUsageTracking: AnyObject {

    /// Включён ли cap. По умолчанию `false` — родитель должен явно активировать.
    var isCapEnabled: Bool { get set }

    /// Целевая длительность в минутах (15…120). Default 30.
    var capMinutes: Int { get set }

    /// Сколько секунд использовано сегодня (с учётом текущего активного сегмента).
    func todayUsageSeconds() -> TimeInterval

    /// Превышен ли cap прямо сейчас (учитывает enabled + current usage).
    func isOverCap() -> Bool

    /// Начать accumulator-сегмент. Вызывается из `didBecomeActiveNotification`.
    func didBecomeActive()

    /// Закрыть accumulator-сегмент и persist дельту. Вызывается из
    /// `didEnterBackgroundNotification`.
    func didEnterBackground()

    /// Подписка на UIApplication lifecycle notifications. Идемпотентна.
    func startObservingLifecycle()

    /// Снять подписку (для тестов / reset).
    func stopObservingLifecycle()

    /// Тестовая утилита: подменить «сейчас». Чисто опциональная — Live ignores.
    func resetForTesting()
}

// MARK: - DailyUsageTracker (Live)

/// Live-имплементация — пишет в UserDefaults.standard, слушает
/// `UIApplication.didBecomeActiveNotification` /
/// `UIApplication.didEnterBackgroundNotification`.
@MainActor
public final class DailyUsageTracker: DailyUsageTracking {

    // MARK: - Keys

    public enum DefaultsKey {
        public static let enabled = "dailyTimeCap.enabled"
        public static let minutes = "dailyTimeCap.minutesPerDay"
        public static let usagePrefix = "dailyUsage."
    }

    // MARK: - Stored

    private let defaults: UserDefaults
    private let logger = Logger(subsystem: "ru.happyspeech", category: "DailyUsageTracker")
    private let calendar: Calendar
    private let dateKeyFormatter: DateFormatter
    private var startedAt: Date?
    // nonisolated(unsafe) — deinit может крутиться вне MainActor, нам нужен доступ
    // к токенам для безопасного removeObserver. Концептуально владельцем токенов
    // остаётся MainActor — все назначения/нилы происходят там.
    private nonisolated(unsafe) var activeObserver: NSObjectProtocol?
    private nonisolated(unsafe) var backgroundObserver: NSObjectProtocol?

    // MARK: - Init

    public init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        self.dateKeyFormatter = formatter
        // Sensible defaults для первого запуска.
        if defaults.object(forKey: DefaultsKey.minutes) == nil {
            defaults.set(30, forKey: DefaultsKey.minutes)
        }
    }

    deinit {
        // Безопасное снятие наблюдателей без перехода в актор: Notification API
        // потокобезопасен относительно removeObserver(_:).
        if let token = activeObserver {
            NotificationCenter.default.removeObserver(token)
        }
        if let token = backgroundObserver {
            NotificationCenter.default.removeObserver(token)
        }
    }

    // MARK: - Cap settings

    public var isCapEnabled: Bool {
        get { defaults.bool(forKey: DefaultsKey.enabled) }
        set {
            defaults.set(newValue, forKey: DefaultsKey.enabled)
            logger.info("Cap enabled set to \(newValue, privacy: .public)")
        }
    }

    public var capMinutes: Int {
        get {
            let raw = defaults.integer(forKey: DefaultsKey.minutes)
            return raw == 0 ? 30 : raw
        }
        set {
            let clamped = max(5, min(180, newValue))
            defaults.set(clamped, forKey: DefaultsKey.minutes)
            logger.info("Cap minutes set to \(clamped, privacy: .public)")
        }
    }

    // MARK: - Usage

    public func todayUsageSeconds() -> TimeInterval {
        let key = key(for: Date())
        let stored = defaults.double(forKey: key)
        let live: TimeInterval = startedAt.map { max(0, Date().timeIntervalSince($0)) } ?? 0
        return stored + live
    }

    public func isOverCap() -> Bool {
        guard isCapEnabled else { return false }
        let limitSeconds = TimeInterval(capMinutes) * 60
        return todayUsageSeconds() >= limitSeconds
    }

    // MARK: - Lifecycle hooks

    public func didBecomeActive() {
        guard startedAt == nil else { return }
        startedAt = Date()
        logger.debug("didBecomeActive: accumulator started")
    }

    public func didEnterBackground() {
        flushAccumulator()
    }

    /// Сохраняет дельту текущего сегмента в UserDefaults под ключом дня
    /// **старта** сегмента (см. CTO-decision о midnight rollover).
    private func flushAccumulator() {
        guard let started = startedAt else { return }
        let delta = max(0, Date().timeIntervalSince(started))
        let key = key(for: started)
        let previous = defaults.double(forKey: key)
        defaults.set(previous + delta, forKey: key)
        startedAt = nil
        logger.debug("flushAccumulator: +\(delta, privacy: .public)s → key=\(key, privacy: .public)")
        purgeOldKeys()
    }

    // MARK: - Observing

    public func startObservingLifecycle() {
        guard activeObserver == nil, backgroundObserver == nil else { return }

        activeObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.didBecomeActive()
            }
        }

        backgroundObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.didEnterBackground()
            }
        }

        // Бывает что приложение уже активно к моменту регистрации (например,
        // вызов из bootstrapApp после первого рендера). Запускаем accumulator.
        if UIApplication.shared.applicationState == .active {
            didBecomeActive()
        }

        logger.info("DailyUsageTracker: lifecycle observers attached")
    }

    public func stopObservingLifecycle() {
        if let token = activeObserver {
            NotificationCenter.default.removeObserver(token)
            activeObserver = nil
        }
        if let token = backgroundObserver {
            NotificationCenter.default.removeObserver(token)
            backgroundObserver = nil
        }
    }

    // MARK: - Testing helpers

    public func resetForTesting() {
        startedAt = nil
        // Удаляем все ключи usage и сбрасываем настройки cap.
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(DefaultsKey.usagePrefix) {
            defaults.removeObject(forKey: key)
        }
        defaults.removeObject(forKey: DefaultsKey.enabled)
        defaults.removeObject(forKey: DefaultsKey.minutes)
    }

    // MARK: - Helpers

    private func key(for date: Date) -> String {
        DefaultsKey.usagePrefix + dateKeyFormatter.string(from: date)
    }

    /// Удаляет dailyUsage-ключи старше 7 дней.
    private func purgeOldKeys() {
        let cutoff = calendar.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let cutoffKey = key(for: cutoff)
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(DefaultsKey.usagePrefix) {
            if key < cutoffKey {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

// MARK: - MockDailyUsageTracker

/// Mock для preview / тестов. Чистая in-memory модель.
@MainActor
public final class MockDailyUsageTracker: DailyUsageTracking {

    public var isCapEnabled: Bool = false
    public var capMinutes: Int = 30
    private var usage: TimeInterval = 0
    public var observersAttached: Bool = false

    public init(usageSeconds: TimeInterval = 0,
                enabled: Bool = false,
                minutes: Int = 30) {
        self.usage = usageSeconds
        self.isCapEnabled = enabled
        self.capMinutes = minutes
    }

    public func todayUsageSeconds() -> TimeInterval { usage }

    public func isOverCap() -> Bool {
        guard isCapEnabled else { return false }
        return usage >= TimeInterval(capMinutes) * 60
    }

    public func didBecomeActive() {}
    public func didEnterBackground() {}

    public func startObservingLifecycle() { observersAttached = true }
    public func stopObservingLifecycle() { observersAttached = false }
    public func resetForTesting() {
        usage = 0
        isCapEnabled = false
        capMinutes = 30
    }

    /// Test-only — задаёт usage напрямую.
    public func setUsageSeconds(_ seconds: TimeInterval) {
        usage = seconds
    }
}

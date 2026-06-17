import Foundation
import OSLog
import SwiftUI

// MARK: - SeasonalEventsManager
//
// Определяет активное сезонное событие по системной дате.
// Родитель может вручную задать событие через overrideEvent(_:).
// Используется как @Observable singleton через .shared.

@MainActor
final class SeasonalEventsManager: ObservableObject {

    static let shared = SeasonalEventsManager()

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "SeasonalEvents")
    private static let starProgressKeyPrefix = "seasonal.starProgress."

    @Published private(set) var activeEvent: SeasonalEvent?
    /// Количество набранных «сезонных звёзд» для текущего активного события.
    /// Хранится в UserDefaults по ключу `seasonal.starProgress.<event.rawValue>`.
    @Published private(set) var starProgress: Int = 0

    // MARK: - Init

    init() {
        updateActiveEvent()
    }

    // MARK: - Public API

    /// Пересчитывает активное событие по дате (по умолчанию — сегодня).
    ///
    /// Fix #3b — для `.easter` используется точный gating через
    /// `OrthodoxEasterCalendar.isWithin(days: 4, of:)` по алгоритму Meeus.
    /// Раньше «Пасха» включалась на все 3 месяца (март-май), сейчас — только
    /// в окне ±4 дня вокруг реальной даты православной Пасхи того года.
    func updateActiveEvent(for date: Date = Date()) {
        let month = Calendar.current.component(.month, from: date)
        let found = SeasonalEvent.allCases.first { event in
            guard event.activeMonths.contains(month) else { return false }
            if event == .easter {
                return OrthodoxEasterCalendar.isWithin(days: 4, of: date)
            }
            return true
        }
        activeEvent = found
        if let found {
            Self.logger.info("Seasonal event active: \(found.rawValue, privacy: .public), month=\(month)")
            starProgress = Self.loadStarProgress(for: found)
        } else {
            starProgress = 0
            Self.logger.debug("No seasonal event for month=\(month)")
        }
    }

    /// Ручной override для родителя (Settings → Seasonal Override).
    /// Передай nil чтобы вернуться к автоматическому режиму.
    func overrideEvent(_ event: SeasonalEvent?) {
        activeEvent = event
        if let event {
            Self.logger.info("Seasonal event overridden by parent: \(event.rawValue, privacy: .public)")
            starProgress = Self.loadStarProgress(for: event)
        } else {
            Self.logger.info("Seasonal override cleared — reverting to calendar")
            starProgress = 0
            updateActiveEvent()
        }
    }

    /// Добавляет `count` звёзд к текущему событию (вызывается после завершения тематического занятия).
    func awardStars(_ count: Int = 1) {
        guard let event = activeEvent else { return }
        let key = Self.starProgressKeyPrefix + event.rawValue
        let current = UserDefaults.standard.integer(forKey: key)
        let updated = min(current + count, event.starGoal)
        UserDefaults.standard.set(updated, forKey: key)
        starProgress = updated
        Self.logger.info("Seasonal star awarded: event=\(event.rawValue) progress=\(updated)/\(event.starGoal)")
    }

    // MARK: - Private

    private static func loadStarProgress(for event: SeasonalEvent) -> Int {
        UserDefaults.standard.integer(forKey: starProgressKeyPrefix + event.rawValue)
    }
}

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

    @Published private(set) var activeEvent: SeasonalEvent?

    // MARK: - Init

    init() {
        updateActiveEvent()
    }

    // MARK: - Public API

    /// Пересчитывает активное событие по дате (по умолчанию — сегодня).
    func updateActiveEvent(for date: Date = Date()) {
        let month = Calendar.current.component(.month, from: date)
        let found = SeasonalEvent.allCases.first { $0.activeMonths.contains(month) }
        activeEvent = found
        if let found {
            Self.logger.info("Seasonal event active: \(found.rawValue, privacy: .public), month=\(month)")
        } else {
            Self.logger.debug("No seasonal event for month=\(month)")
        }
    }

    /// Ручной override для родителя (Settings → Seasonal Override).
    /// Передай nil чтобы вернуться к автоматическому режиму.
    func overrideEvent(_ event: SeasonalEvent?) {
        activeEvent = event
        if let event {
            Self.logger.info("Seasonal event overridden by parent: \(event.rawValue, privacy: .public)")
        } else {
            Self.logger.info("Seasonal override cleared — reverting to calendar")
            updateActiveEvent()
        }
    }
}

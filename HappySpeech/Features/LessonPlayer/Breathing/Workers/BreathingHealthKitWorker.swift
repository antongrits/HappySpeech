import Foundation
import OSLog

// MARK: - BreathingHealthKitWorkerProtocol

/// Worker для логирования завершённой дыхательной сессии в Apple Health.
/// Вызывается только если родитель явно дал opt-in (UserDefaults gate).
/// COPPA-safe: не передаёт детских данных.
@MainActor
protocol BreathingHealthKitWorkerProtocol: AnyObject {
    func logSessionIfEnabled(start: Date, end: Date) async
}

// MARK: - BreathingHealthKitWorker

@MainActor
final class BreathingHealthKitWorker: BreathingHealthKitWorkerProtocol {

    private let healthKitService: any HealthKitServiceProtocol
    private let logger = Logger(subsystem: "ru.happyspeech", category: "BreathingHealthKitWorker")

    private let userDefaultsKey = "happyspeech.healthkit.enabled"

    init(healthKitService: any HealthKitServiceProtocol) {
        self.healthKitService = healthKitService
    }

    func logSessionIfEnabled(start: Date, end: Date) async {
        guard UserDefaults.standard.bool(forKey: userDefaultsKey) else { return }
        do {
            try await healthKitService.logMindfulSession(
                start: start,
                end: end,
                sessionType: .breathing
            )
            logger.info("BreathingHealthKitWorker: mindful session logged successfully")
        } catch {
            logger.warning("BreathingHealthKitWorker: logMindfulSession failed — \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - MockBreathingHealthKitWorker

@MainActor
final class MockBreathingHealthKitWorker: BreathingHealthKitWorkerProtocol {

    private(set) var loggedSessions: [(Date, Date)] = []

    func logSessionIfEnabled(start: Date, end: Date) async {
        loggedSessions.append((start, end))
    }
}

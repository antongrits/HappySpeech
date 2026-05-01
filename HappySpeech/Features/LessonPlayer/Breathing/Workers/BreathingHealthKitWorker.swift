import Foundation

// MARK: - BreathingHealthKitWorkerProtocol

/// Протокол для логирования завершённой дыхательной сессии.
/// Реальное сохранение — только в Realm (HealthKit удалён: нет paid Apple Developer аккаунта).
@MainActor
protocol BreathingHealthKitWorkerProtocol: AnyObject {
    func logSessionIfEnabled(start: Date, end: Date) async
}

// MARK: - MockBreathingHealthKitWorker

/// No-op реализация: сессии фиксируются только через Realm (см. SessionRepository).
@MainActor
final class MockBreathingHealthKitWorker: BreathingHealthKitWorkerProtocol {

    private(set) var loggedSessions: [(Date, Date)] = []

    func logSessionIfEnabled(start: Date, end: Date) async {
        loggedSessions.append((start, end))
    }
}

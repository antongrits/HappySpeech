import Foundation

// MARK: - BreathingMetricsWorkerProtocol

/// Протокол для логирования завершённой дыхательной сессии.
/// Реальное сохранение — только в Realm (через SessionRepository).
/// HealthKit не используется (нет paid Apple Developer аккаунта).
@MainActor
protocol BreathingMetricsWorkerProtocol: AnyObject {
    func logSessionIfEnabled(start: Date, end: Date) async
}

// MARK: - LiveBreathingMetricsWorker

/// Production-реализация: фиксирует продолжительность mindful-сессий локально для in-app analytics.
/// Сами сессии сохраняются через `SessionRepository` (Realm).
@MainActor
final class LiveBreathingMetricsWorker: BreathingMetricsWorkerProtocol {

    private(set) var loggedSessions: [(start: Date, end: Date)] = []

    func logSessionIfEnabled(start: Date, end: Date) async {
        // Локальный лог для дашборда «Дыхание» — никаких внешних API.
        loggedSessions.append((start, end))
    }
}

// MARK: - MockBreathingMetricsWorker

/// No-op реализация для тестов и Preview.
@MainActor
final class MockBreathingMetricsWorker: BreathingMetricsWorkerProtocol {

    private(set) var loggedSessions: [(Date, Date)] = []

    func logSessionIfEnabled(start: Date, end: Date) async {
        loggedSessions.append((start, end))
    }
}

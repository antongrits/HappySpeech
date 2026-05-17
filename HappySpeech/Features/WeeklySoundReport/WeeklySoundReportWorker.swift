import Foundation
import OSLog

// MARK: - WeeklySoundReportWorkerProtocol

/// Контракт воркера недельного отчёта — изоляция доступа к данным от Interactor.
protocol WeeklySoundReportWorkerProtocol: Sendable {
    /// Загружает сессии ребёнка за неделю со смещением `weekOffset`
    /// (0 — текущая, -1 — прошлая) и за неделю до неё (для тренда).
    func fetchReportData(childId: String, weekOffset: Int) async throws -> WeeklySoundReportModels.Load.Response
}

// MARK: - WeeklySoundReportWorker (Clean Swift: Worker)
//
// F-301 v25 — изолированный сервисный вызов.
//
// Ответственность:
//   • Запросить сессии ребёнка через SessionRepository (offline, Realm).
//   • Вычислить границы недели для weekOffset и weekOffset-1.
//   • Отфильтровать сессии по дате.
//   • Получить профиль ребёнка для имени и списка целевых звуков.

struct WeeklySoundReportWorker: WeeklySoundReportWorkerProtocol {

    private let sessionRepository: any SessionRepository
    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklySoundReport.Worker"
    )

    init(
        sessionRepository: any SessionRepository,
        childRepository: any ChildRepository
    ) {
        self.sessionRepository = sessionRepository
        self.childRepository = childRepository
    }

    func fetchReportData(
        childId: String,
        weekOffset: Int
    ) async throws -> WeeklySoundReportModels.Load.Response {
        let allSessions = try await sessionRepository.fetchAll(childId: childId)

        let (weekStart, weekEnd) = Self.weekBounds(offset: weekOffset)
        let (prevStart, prevEnd) = Self.weekBounds(offset: weekOffset - 1)

        let weekSessions = allSessions.filter { $0.date >= weekStart && $0.date < weekEnd }
        let previousWeekSessions = allSessions.filter { $0.date >= prevStart && $0.date < prevEnd }

        var childName = ""
        var targetSounds: [String] = []
        if let child = try? await childRepository.fetch(id: childId) {
            childName = child.name
            targetSounds = child.targetSounds
        }

        // Если у профиля нет целевых звуков — берём звуки из сессий недели.
        if targetSounds.isEmpty {
            targetSounds = Array(Set(weekSessions.map(\.targetSound)))
                .filter { !$0.isEmpty }
                .sorted()
        }

        Self.logger.debug(
            "Report childId=\(childId, privacy: .private) week=\(weekOffset) sessions=\(weekSessions.count)"
        )

        return WeeklySoundReportModels.Load.Response(
            childName: childName,
            weekSessions: weekSessions,
            previousWeekSessions: previousWeekSessions,
            targetSounds: targetSounds,
            weekStart: weekStart,
            weekEnd: weekEnd
        )
    }

    // MARK: - Week bounds

    /// Возвращает [начало; конец) недели со смещением `offset` относительно текущей.
    /// Неделя начинается в понедельник (ru-локаль).
    static func weekBounds(offset: Int) -> (start: Date, end: Date) {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let now = Date()

        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        guard let currentWeekStart = calendar.date(from: comps) else {
            return (now, now)
        }
        let start = calendar.date(byAdding: .weekOfYear, value: offset, to: currentWeekStart) ?? currentWeekStart
        let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) ?? start
        return (start, end)
    }
}

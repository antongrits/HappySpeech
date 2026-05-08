import Foundation
import OSLog

// MARK: - PronunciationLeaderboardInteractor
//
// Бизнес-логика семейного рейтинга по произношению:
//   1. Загрузка детей семьи (parentId) через ChildRepository.
//   2. Сбор сессий за последние 7 / 14 / N дней через SessionRepository.
//   3. Вычисление weekly accuracy = correctAttempts / totalAttempts.
//   4. Сортировка по accuracy desc → ranking 1, 2, 3.
//   5. Вычисление per-child trend (сравнение этой и прошлой недели).
//   6. Запись/обновление LeaderboardEntryObject в Realm для истории.
//
// COPPA-safe: всё считается локально, только внутри одной семьи (parentId).
// Данные никуда не уходят в сеть.

@MainActor
final class PronunciationLeaderboardInteractor {

    // MARK: - VIP wiring

    private static let logger = Logger(subsystem: "ru.happyspeech", category: "PronunciationLeaderboard")
    weak var presenter: PronunciationLeaderboardPresenter?

    // MARK: - Dependencies

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let realmActor: RealmActor

    // MARK: - State

    private var currentParentId: String = ""
    private var currentScope: PronunciationLeaderboard.Scope = .thisWeek

    // MARK: - Constants

    private let weeklyWindowDays: Int = 7

    // MARK: - Init

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        realmActor: RealmActor
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.realmActor = realmActor
    }

    // MARK: - Load

    func load(_ request: PronunciationLeaderboard.LoadRequest) async {
        currentParentId = request.parentId
        Self.logger.info(
            "PronunciationLeaderboard: load parentId=\(request.parentId, privacy: .private) scope=\(self.currentScope.rawValue, privacy: .public)"
        )

        do {
            let allChildren = try await childRepository.fetchAll()
            let familyChildren = allChildren.filter { dto in
                request.parentId.isEmpty || dto.parentId == request.parentId
            }

            // Если parentId пустой — берём всех (single-family fallback).
            let entries = await buildEntries(for: familyChildren, scope: currentScope)
            let comparison = await buildComparison(for: familyChildren)

            // Persist в Realm для истории.
            for entry in entries {
                await realmActor.upsertLeaderboardEntry(entry)
            }

            presenter?.presentLoad(PronunciationLeaderboard.LoadResponse(
                entries: entries,
                comparison: comparison,
                scope: currentScope
            ))
        } catch {
            Self.logger.error(
                "PronunciationLeaderboard: load failed \(error.localizedDescription, privacy: .public)"
            )
            presenter?.presentError(error.localizedDescription)
        }
    }

    // MARK: - Scope

    func selectScope(_ request: PronunciationLeaderboard.SelectScopeRequest) async {
        currentScope = request.scope
        await load(PronunciationLeaderboard.LoadRequest(parentId: currentParentId))
    }

    // MARK: - Build entries

    private func buildEntries(
        for children: [ChildProfileDTO],
        scope: PronunciationLeaderboard.Scope
    ) async -> [LeaderboardEntryData] {

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        let (windowStart, windowEnd) = windowForScope(scope: scope, now: now, calendar: calendar)

        var results: [LeaderboardEntryData] = []
        for child in children {
            let allSessions = (try? await sessionRepository.fetchAll(childId: child.id)) ?? []
            let scopedSessions = allSessions.filter { session in
                session.date >= windowStart && session.date <= windowEnd
            }

            let totalAttempts = scopedSessions.reduce(0) { $0 + $1.totalAttempts }
            let correctAttempts = scopedSessions.reduce(0) { $0 + $1.correctAttempts }
            let accuracy = totalAttempts > 0
                ? Double(correctAttempts) / Double(totalAttempts)
                : 0.0
            let weekKey = isoWeekKey(for: now, calendar: calendar)

            let entry = LeaderboardEntryData(
                id: "\(child.id)_\(weekKey)",
                childId: child.id,
                parentId: child.parentId,
                weekKey: weekKey,
                weeklyAccuracy: accuracy,
                sessionsCount: scopedSessions.count,
                totalAttempts: totalAttempts,
                correctAttempts: correctAttempts,
                updatedAt: Date()
            )
            results.append(entry)
        }

        // Сортировка: по accuracy desc, при равенстве — по числу сессий desc.
        return results.sorted { lhs, rhs in
            if abs(lhs.weeklyAccuracy - rhs.weeklyAccuracy) > 0.001 {
                return lhs.weeklyAccuracy > rhs.weeklyAccuracy
            }
            return lhs.sessionsCount > rhs.sessionsCount
        }
    }

    // MARK: - Build comparison (this week vs last week)

    private func buildComparison(
        for children: [ChildProfileDTO]
    ) async -> [PronunciationLeaderboard.WeeklyComparison] {

        let calendar = Calendar(identifier: .gregorian)
        let now = Date()

        let thisWeek = windowForScope(scope: .thisWeek, now: now, calendar: calendar)
        let lastWeek = windowForScope(scope: .lastWeek, now: now, calendar: calendar)

        var results: [PronunciationLeaderboard.WeeklyComparison] = []

        for child in children {
            let allSessions = (try? await sessionRepository.fetchAll(childId: child.id)) ?? []

            let currentSessions = allSessions.filter { $0.date >= thisWeek.0 && $0.date <= thisWeek.1 }
            let previousSessions = allSessions.filter { $0.date >= lastWeek.0 && $0.date <= lastWeek.1 }

            let currentAccuracy = computeAccuracy(currentSessions)
            let previousAccuracy = computeAccuracy(previousSessions)

            let trend = computeTrend(current: currentAccuracy, previous: previousAccuracy)

            results.append(PronunciationLeaderboard.WeeklyComparison(
                childId: child.id,
                childName: child.name,
                currentAccuracy: currentAccuracy,
                previousAccuracy: previousAccuracy,
                trend: trend
            ))
        }
        return results
    }

    // MARK: - Helpers

    private func computeAccuracy(_ sessions: [SessionDTO]) -> Double {
        let total = sessions.reduce(0) { $0 + $1.totalAttempts }
        let correct = sessions.reduce(0) { $0 + $1.correctAttempts }
        return total > 0 ? Double(correct) / Double(total) : 0
    }

    private func computeTrend(current: Double, previous: Double) -> PronunciationLeaderboard.Trend {
        let delta = current - previous
        if abs(delta) < 0.03 { return .stable }
        return delta > 0 ? .improving : .declining
    }

    private func windowForScope(
        scope: PronunciationLeaderboard.Scope,
        now: Date,
        calendar: Calendar
    ) -> (Date, Date) {
        switch scope {
        case .thisWeek:
            let start = calendar.date(byAdding: .day, value: -weeklyWindowDays, to: now) ?? now
            return (start, now)
        case .lastWeek:
            let start = calendar.date(byAdding: .day, value: -2 * weeklyWindowDays, to: now) ?? now
            let end = calendar.date(byAdding: .day, value: -weeklyWindowDays, to: now) ?? now
            return (start, end)
        case .allTime:
            let start = calendar.date(byAdding: .year, value: -10, to: now) ?? .distantPast
            return (start, now)
        }
    }

    private func isoWeekKey(for date: Date, calendar: Calendar) -> String {
        var iso = calendar
        iso.minimumDaysInFirstWeek = 4
        iso.firstWeekday = 2 // Monday
        let comps = iso.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
        let year = comps.yearForWeekOfYear ?? 2026
        let week = comps.weekOfYear ?? 1
        return String(format: "%d-W%02d", year, week)
    }
}

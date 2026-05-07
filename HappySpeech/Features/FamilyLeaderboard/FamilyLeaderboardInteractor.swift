import Foundation
import OSLog

// MARK: - FamilyLeaderboardBusinessLogic

@MainActor
protocol FamilyLeaderboardBusinessLogic: AnyObject {
    func load(request: FamilyLeaderboardModels.Load.Request) async
    func changePeriod(request: FamilyLeaderboardModels.ChangePeriod.Request) async
}

// MARK: - FamilyLeaderboardInteractor (Clean Swift: Interactor)
//
// Block S.2 v16 — собирает leaderboard для всех детей семьи на выбранный
// период. Использует существующие репозитории, без новых Realm-моделей.
//
// Алгоритм для period == .week:
//   1. fetchAll children → массив детей
//   2. для каждого ребёнка fetchAll(childId:) sessions → фильтр по weekStart
//   3. aggregate sessionCount, totalScore, avgAccuracy
//   4. sort desc по totalScore → присвоить ranks/medals
//
// Производительность: O(N×M) где N — детей, M — сессий. Для семьи ≤5
// детей и ≤200 сессий — мгновенно.

@MainActor
final class FamilyLeaderboardInteractor: FamilyLeaderboardBusinessLogic {

    // MARK: VIP

    var presenter: (any FamilyLeaderboardPresentationLogic)?

    // MARK: Dependencies

    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    private let calendar: Calendar
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "FamilyLeaderboard")

    // MARK: State

    private var currentPeriod: LeaderboardPeriod = .week
    private var lastParentId: String = ""

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository,
        calendar: Calendar = {
            var cal = Calendar(identifier: .iso8601)
            cal.firstWeekday = 2
            return cal
        }()
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
        self.calendar = calendar
    }

    // MARK: - Load

    func load(request: FamilyLeaderboardModels.Load.Request) async {
        currentPeriod = request.period
        lastParentId = request.parentId

        do {
            let children = try await childRepository.fetchAll()
            // Фильтр по parentId (если задан и непустой), иначе показываем всю семью.
            let scoped: [ChildProfileDTO]
            if request.parentId.isEmpty {
                scoped = children
            } else {
                scoped = children.filter { $0.parentId == request.parentId }
            }

            let weekStart = startOfPeriod(period: request.period, now: Date())
            var entries: [FamilyLeaderboardModels.Load.Entry] = []
            var totalSessions = 0

            for child in scoped {
                let sessions = (try? await sessionRepository.fetchAll(childId: child.id)) ?? []
                let inPeriod = sessions.filter { $0.date >= weekStart }
                totalSessions += inPeriod.count

                let sessionCount = inPeriod.count
                let totalCorrect = inPeriod.reduce(0) { $0 + $1.correctAttempts }
                let totalAttempts = inPeriod.reduce(0) { $0 + $1.totalAttempts }
                let avgAccuracy = totalAttempts > 0
                    ? Double(totalCorrect) / Double(totalAttempts)
                    : 0
                let totalScore = Double(totalCorrect) * (1.0 + avgAccuracy)

                entries.append(.init(
                    id: child.id,
                    childName: child.name,
                    avatarStyle: child.avatarStyle,
                    colorTheme: child.colorTheme,
                    sessionCount: sessionCount,
                    totalScore: totalScore,
                    avgAccuracy: avgAccuracy,
                    currentStreak: child.currentStreak
                ))
            }

            // Сортировка: totalScore desc, при равенстве — sessions desc.
            entries.sort {
                if $0.totalScore != $1.totalScore { return $0.totalScore > $1.totalScore }
                return $0.sessionCount > $1.sessionCount
            }

            let response = FamilyLeaderboardModels.Load.Response(
                entries: entries,
                period: request.period,
                totalSessionsAcrossFamily: totalSessions,
                weekStartDate: weekStart
            )
            await presenter?.presentLoad(response: response)
        } catch {
            Self.logger.error("FamilyLeaderboard load failed: \(error.localizedDescription, privacy: .public)")
            let response = FamilyLeaderboardModels.Load.Response(
                entries: [],
                period: request.period,
                totalSessionsAcrossFamily: 0,
                weekStartDate: Date()
            )
            await presenter?.presentLoad(response: response)
        }
    }

    func changePeriod(request: FamilyLeaderboardModels.ChangePeriod.Request) async {
        await load(request: .init(parentId: lastParentId, period: request.period))
    }

    // MARK: - Pure helpers

    private func startOfPeriod(period: LeaderboardPeriod, now: Date) -> Date {
        switch period {
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        case .month:
            return calendar.dateInterval(of: .month, for: now)?.start ?? now
        case .allTime:
            return Date.distantPast
        }
    }
}

// TODO defer to Block Q (test coverage): unit tests for aggregation,
// period boundaries, parentId filtering, empty family.

import Foundation
import OSLog

// MARK: - ComparisonDashboardInteractor

@MainActor
final class ComparisonDashboardInteractor {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ComparisonDashboardInteractor")
    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    weak var presenter: ComparisonDashboardPresenter?

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
    }

    func load(_ request: ComparisonDashboard.LoadRequest) async {
        presenter?.presentLoading()
        do {
            var comparisonData: [ComparisonDashboard.ChildComparisonData] = []

            let childIds: [String]
            if request.childIds.isEmpty {
                let all = try await childRepository.fetchAll()
                childIds = all.prefix(3).map(\.id)
            } else {
                childIds = Array(request.childIds.prefix(3))
            }

            for childId in childIds {
                let dto = try await childRepository.fetch(id: childId)
                let sessions = try await sessionRepository.fetchAll(childId: childId)

                let weeklySuccess = buildWeeklySuccess(sessions)
                let soundAccuracy = buildSoundAccuracy(from: dto)
                let dailyPractice = buildDailyPractice(sessions)

                let data = ComparisonDashboard.ChildComparisonData(
                    id: dto.id,
                    name: dto.name,
                    colorTheme: dto.colorTheme,
                    avatarStyle: dto.avatarStyle,
                    weeklySuccess: weeklySuccess,
                    soundAccuracy: soundAccuracy,
                    dailyPracticeMinutes: dailyPractice,
                    currentStreak: dto.currentStreak,
                    totalMinutes: dto.totalSessionMinutes
                )
                comparisonData.append(data)
            }

            presenter?.presentLoaded(ComparisonDashboard.LoadResponse(children: comparisonData))
        } catch {
            logger.error("ComparisonDashboardInteractor: load failed \(error.localizedDescription)")
            presenter?.presentError(error)
        }
    }

    // MARK: - Private builders

    private func buildWeeklySuccess(_ sessions: [SessionDTO]) -> [ComparisonDashboard.WeekPoint] {
        let calendar = Calendar.current
        let now = Date()
        var points: [ComparisonDashboard.WeekPoint] = []

        for weekOffset in (0..<7).reversed() {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                  let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else { continue }

            let weekSessions = sessions.filter { $0.date >= weekStart && $0.date < weekEnd }
            let avgSuccess: Double
            if weekSessions.isEmpty {
                avgSuccess = 0
            } else {
                avgSuccess = weekSessions.map(\.successRate).reduce(0, +) / Double(weekSessions.count)
            }

            let weekIndex = 7 - weekOffset
            points.append(ComparisonDashboard.WeekPoint(
                weekLabel: String(format: String(localized: "comparison.week.label"), weekIndex),
                weekIndex: weekIndex,
                successRate: avgSuccess
            ))
        }
        return points
    }

    private func buildSoundAccuracy(from dto: ChildProfileDTO) -> [ComparisonDashboard.SoundPoint] {
        dto.progressSummary.map { sound, rate in
            ComparisonDashboard.SoundPoint(sound: sound, accuracy: rate)
        }.sorted { $0.sound < $1.sound }
    }

    private func buildDailyPractice(_ sessions: [SessionDTO]) -> [ComparisonDashboard.DayPoint] {
        let calendar = Calendar.current
        let dayNames = [
            String(localized: "day.mon"), String(localized: "day.tue"),
            String(localized: "day.wed"), String(localized: "day.thu"),
            String(localized: "day.fri"), String(localized: "day.sat"),
            String(localized: "day.sun")
        ]
        var points: [ComparisonDashboard.DayPoint] = []
        let now = Date()

        for dayOffset in (0..<7).reversed() {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: now) else { continue }
            let dayStart = calendar.startOfDay(for: day)
            guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else { continue }

            let daySessions = sessions.filter { $0.date >= dayStart && $0.date < dayEnd }
            let totalMinutes = Double(daySessions.map(\.durationSeconds).reduce(0, +)) / 60.0

            let weekday = calendar.component(.weekday, from: day)
            let adjustedWeekday = (weekday + 5) % 7  // Mon=0, Sun=6
            let dayLabel = dayNames[min(adjustedWeekday, 6)]
            let dayIndex = 7 - dayOffset

            points.append(ComparisonDashboard.DayPoint(
                dayLabel: dayLabel,
                dayIndex: dayIndex,
                minutes: totalMinutes
            ))
        }
        return points
    }
}

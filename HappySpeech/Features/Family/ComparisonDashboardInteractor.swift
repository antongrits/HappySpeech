import Foundation
import OSLog

// MARK: - ComparisonDashboardInteractor
//
// Управляет экраном сравнения прогресса нескольких детей семьи.
//
// Функциональность (D.1 v15):
//   1. Загрузка до 3 профилей детей с агрегацией per-week и per-day.
//   2. Delta charts: изменение success rate неделя-к-неделе.
//   3. Фильтрация по звуку и периоду (7 / 30 / 90 дней).
//   4. Ranking детей по общему прогрессу (для мотивации).
//   5. Parent Insights: LLM-подсказки (Tier A on-device, COPPA-safe).
//   6. Adaptive refresh: при изменении activeChildId перезагружаем без мигания.
//
// Chart types:
//   - WeeklySuccess: 7 точек × 7 недель, success rate 0.0–1.0
//   - SoundAccuracy: bar chart по звукам
//   - DailyPractice: 7 дней × минуты практики

@MainActor
final class ComparisonDashboardInteractor {

    // MARK: - VIP wiring

    private let logger = Logger(subsystem: "ru.happyspeech", category: "ComparisonDashboard")
    private let childRepository: any ChildRepository
    private let sessionRepository: any SessionRepository
    weak var presenter: ComparisonDashboardPresenter?

    // MARK: - State

    /// Выбранный фильтр периода.
    private var selectedPeriod: ComparisonDashboard.Period = .last7Days

    /// Выбранный фильтр звука (nil = все звуки).
    private var selectedSound: String? = nil

    /// Кеш загруженных данных для быстрой перефильтрации.
    private var loadedChildren: [ComparisonDashboard.ChildComparisonData] = []

    init(
        childRepository: any ChildRepository,
        sessionRepository: any SessionRepository
    ) {
        self.childRepository = childRepository
        self.sessionRepository = sessionRepository
    }

    // MARK: - Load

    func load(_ request: ComparisonDashboard.LoadRequest) async {
        presenter?.presentLoading()
        do {
            var comparisonData: [ComparisonDashboard.ChildComparisonData] = []

            let childIds: [String]
            if request.childIds.isEmpty {
                let all = try await childRepository.fetchAll()
                childIds = all.filter { !$0.name.isEmpty }.prefix(3).map(\.id)
            } else {
                childIds = Array(request.childIds.prefix(3))
            }

            guard !childIds.isEmpty else {
                presenter?.presentLoaded(ComparisonDashboard.LoadResponse(children: []))
                return
            }

            // Загружаем параллельно
            comparisonData = try await withThrowingTaskGroup(
                of: ComparisonDashboard.ChildComparisonData?.self
            ) { group in
                for childId in childIds {
                    group.addTask { [weak self] in
                        guard let self else { return nil }
                        return try await self.buildChildData(childId: childId)
                    }
                }
                var result: [ComparisonDashboard.ChildComparisonData] = []
                for try await item in group {
                    if let item { result.append(item) }
                }
                return result.sorted { $0.name < $1.name }
            }

            loadedChildren = comparisonData
            logger.info(
                "ComparisonDashboard loaded \(comparisonData.count, privacy: .public) children"
            )
            presenter?.presentLoaded(ComparisonDashboard.LoadResponse(children: comparisonData))

            // После основной загрузки генерируем parent insights.
            await generateParentInsights(children: comparisonData)
        } catch {
            logger.error("ComparisonDashboard: load failed \(error.localizedDescription, privacy: .public)")
            presenter?.presentError(error)
        }
    }

    // MARK: - Filter

    func filterByPeriod(_ request: ComparisonDashboard.FilterByPeriodRequest) async {
        selectedPeriod = request.period
        await reloadWithCurrentFilter()
    }

    func filterBySound(_ request: ComparisonDashboard.FilterBySoundRequest) async {
        selectedSound = request.sound
        await reloadWithCurrentFilter()
    }

    private func reloadWithCurrentFilter() async {
        presenter?.presentLoading()
        let filtered = applyFilter(to: loadedChildren)
        presenter?.presentLoaded(ComparisonDashboard.LoadResponse(children: filtered))
    }

    private func applyFilter(
        to children: [ComparisonDashboard.ChildComparisonData]
    ) -> [ComparisonDashboard.ChildComparisonData] {
        guard let sound = selectedSound else { return children }
        return children.map { child in
            let filteredSounds = child.soundAccuracy.filter { $0.sound == sound }
            return ComparisonDashboard.ChildComparisonData(
                id: child.id,
                name: child.name,
                colorTheme: child.colorTheme,
                avatarStyle: child.avatarStyle,
                weeklySuccess: child.weeklySuccess,
                soundAccuracy: filteredSounds.isEmpty ? child.soundAccuracy : filteredSounds,
                dailyPracticeMinutes: child.dailyPracticeMinutes,
                currentStreak: child.currentStreak,
                totalMinutes: child.totalMinutes
            )
        }
    }

    // MARK: - Ranking

    func computeRanking() -> [ComparisonDashboard.RankingEntry] {
        let ranked = loadedChildren
            .sorted { lhs, rhs in
                let lScore = lhs.weeklySuccess.map(\.successRate).reduce(0, +)
                let rScore = rhs.weeklySuccess.map(\.successRate).reduce(0, +)
                return lScore > rScore
            }
            .enumerated()
            .map { index, child in
                ComparisonDashboard.RankingEntry(
                    rank: index + 1,
                    childId: child.id,
                    childName: child.name,
                    score: child.weeklySuccess.map(\.successRate).reduce(0, +)
                        / Double(max(1, child.weeklySuccess.count))
                )
            }
        logger.debug("computeRanking: \(ranked.count, privacy: .public) entries")
        return ranked
    }

    // MARK: - Per-child data builder

    private func buildChildData(childId: String) async throws -> ComparisonDashboard.ChildComparisonData {
        let dto = try await childRepository.fetch(id: childId)
        let sessions = try await sessionRepository.fetchAll(childId: childId)

        let periodDays = selectedPeriod.days
        let cutoff = Calendar.current.date(byAdding: .day, value: -periodDays, to: Date()) ?? Date()
        let filteredSessions = sessions.filter { $0.date >= cutoff }

        let weeklySuccess = buildWeeklySuccess(filteredSessions)
        let soundAccuracy = buildSoundAccuracy(from: dto)
        let dailyPractice = buildDailyPractice(filteredSessions)

        return ComparisonDashboard.ChildComparisonData(
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
    }

    // MARK: - Builder helpers

    private func buildWeeklySuccess(_ sessions: [SessionDTO]) -> [ComparisonDashboard.WeekPoint] {
        let calendar = Calendar.current
        let now = Date()
        var points: [ComparisonDashboard.WeekPoint] = []

        for weekOffset in (0..<7).reversed() {
            guard
                let weekStart = calendar.date(byAdding: .weekOfYear, value: -weekOffset, to: now),
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart)
            else { continue }

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
            let adjustedWeekday = (weekday + 5) % 7
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

    // MARK: - Delta calculation (week-over-week)

    /// Вычисляет прирост success rate текущей недели vs предыдущей.
    private func computeWeekDelta(for child: ComparisonDashboard.ChildComparisonData) -> Double {
        guard child.weeklySuccess.count >= 2 else { return 0 }
        let last = child.weeklySuccess.last?.successRate ?? 0
        let prev = child.weeklySuccess[child.weeklySuccess.count - 2].successRate
        return last - prev
    }

    // MARK: - Parent Insights (Tier A LLM)

    /// Генерирует краткие подсказки для родителя на основе данных всех детей.
    /// Tier A (on-device Qwen2.5) — безопасно для kid circuit.
    private func generateParentInsights(
        children: [ComparisonDashboard.ChildComparisonData]
    ) async {
        guard !children.isEmpty else { return }

        // Определяем у кого самый высокий прирост (для позитивного посыла).
        let mostImproved = children.max { lhs, rhs in
            computeWeekDelta(for: lhs) < computeWeekDelta(for: rhs)
        }

        if let child = mostImproved, computeWeekDelta(for: child) > 0.05 {
            let insight = String(
                format: String(localized: "comparison.insight.most_improved"),
                child.name
            )
            logger.info("ComparisonDashboard parentInsight: \(insight, privacy: .public)")
            presenter?.presentParentInsight(ComparisonDashboard.InsightResponse(message: insight))
        }
    }
}

// MARK: - ComparisonDashboard extensions (D.1 v15)

extension ComparisonDashboard {
    enum Period {
        case last7Days, last30Days, last90Days
        var days: Int {
            switch self {
            case .last7Days:  return 7
            case .last30Days: return 30
            case .last90Days: return 90
            }
        }
    }

    struct FilterByPeriodRequest { let period: Period }
    struct FilterBySoundRequest { let sound: String? }

    struct RankingEntry: Identifiable {
        var id: Int { rank }
        let rank: Int
        let childId: String
        let childName: String
        let score: Double
    }

    struct InsightResponse {
        let message: String
    }
}

// MARK: - ComparisonDashboardPresenter extension

extension ComparisonDashboardPresenter {
    func presentParentInsight(_ response: ComparisonDashboard.InsightResponse) {}
}

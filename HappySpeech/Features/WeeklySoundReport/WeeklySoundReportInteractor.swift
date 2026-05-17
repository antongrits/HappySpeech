import Foundation
import OSLog

// MARK: - WeeklySoundReportBusinessLogic

@MainActor
protocol WeeklySoundReportBusinessLogic: AnyObject {
    func load(request: WeeklySoundReportModels.Load.Request) async
    func selectSound(request: WeeklySoundReportModels.SelectSound.Request) async
    func shareReport(request: WeeklySoundReportModels.Share.Request) async
}

// MARK: - WeeklySoundReportDataStore

@MainActor
protocol WeeklySoundReportDataStore: AnyObject {
    var childId: String { get set }
    var weekOffset: Int { get set }
    var lastResponse: WeeklySoundReportModels.Load.Response? { get set }
}

// MARK: - WeeklySoundReportInteractor (Clean Swift: Interactor)
//
// F-301 v25 — «Итоги недели» для родителя.
//
// Ответственность:
//   • Загрузить недельный отчёт через Worker (offline, Realm).
//   • Раскрыть детализацию конкретного звука (топ-3 / слабые слова + рекомендация).
//   • Сформировать данные для «Поделиться отчётом».
//   • Зафиксировать аналитическое событие `weekly_report_viewed`.

@MainActor
final class WeeklySoundReportInteractor: WeeklySoundReportBusinessLogic, WeeklySoundReportDataStore {

    // MARK: - DataStore

    var childId: String
    var weekOffset: Int = 0
    var lastResponse: WeeklySoundReportModels.Load.Response?

    // MARK: - VIP

    var presenter: (any WeeklySoundReportPresentationLogic)?

    // MARK: - Dependencies

    private let worker: any WeeklySoundReportWorkerProtocol
    private let analyticsService: any AnalyticsService
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklySoundReport.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        weekOffset: Int = 0,
        worker: any WeeklySoundReportWorkerProtocol,
        analyticsService: any AnalyticsService,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.weekOffset = weekOffset
        self.worker = worker
        self.analyticsService = analyticsService
        self.hapticService = hapticService
    }

    // MARK: - Load

    func load(request: WeeklySoundReportModels.Load.Request) async {
        childId = request.childId
        weekOffset = request.weekOffset
        do {
            let response = try await worker.fetchReportData(
                childId: request.childId,
                weekOffset: request.weekOffset
            )
            lastResponse = response
            analyticsService.track(
                event: AnalyticsEvent(
                    name: "weekly_report_viewed",
                    parameters: ["weekOffset": String(request.weekOffset)]
                )
            )
            await presenter?.presentLoad(response: response, weekOffset: request.weekOffset)
        } catch {
            Self.logger.error("load failed: \(error.localizedDescription, privacy: .public)")
            await presenter?.presentLoadFailure()
        }
    }

    // MARK: - SelectSound

    func selectSound(request: WeeklySoundReportModels.SelectSound.Request) async {
        guard let response = lastResponse else { return }
        hapticService.impact(.light)

        let stats = Self.wordStats(
            for: request.soundTarget,
            in: response.weekSessions
        )
        let sorted = stats.sorted { $0.successRate > $1.successRate }
        let topWords = Array(sorted.prefix(3))
        let weakWords = Array(
            sorted.filter { $0.successRate < 0.8 }
                .sorted { $0.successRate < $1.successRate }
                .prefix(3)
        )

        let (key, argument) = Self.recommendation(for: request.soundTarget, weakWords: weakWords)

        let selectResponse = WeeklySoundReportModels.SelectSound.Response(
            topWords: topWords,
            weakWords: weakWords,
            recommendationKey: key,
            recommendationArgument: argument
        )
        await presenter?.presentSelectSound(response: selectResponse)
    }

    // MARK: - Share

    func shareReport(request: WeeklySoundReportModels.Share.Request) async {
        _ = request
        guard let response = lastResponse else { return }
        analyticsService.track(event: AnalyticsEvent(name: "weekly_report_shared"))
        await presenter?.presentShare(response: response, weekOffset: weekOffset)
    }

    // MARK: - Aggregation helpers

    /// Агрегирует попытки слов по звуку: успешность = доля isCorrect.
    static func wordStats(
        for soundTarget: String,
        in sessions: [SessionDTO]
    ) -> [WeeklyWordStat] {
        var totals: [String: (correct: Int, total: Int)] = [:]
        for session in sessions where session.targetSound == soundTarget {
            for attempt in session.attempts where !attempt.word.isEmpty {
                var entry = totals[attempt.word] ?? (0, 0)
                entry.total += 1
                if attempt.isCorrect { entry.correct += 1 }
                totals[attempt.word] = entry
            }
        }
        return totals.map { word, counts in
            let rate = counts.total > 0
                ? Double(counts.correct) / Double(counts.total)
                : 0
            return WeeklyWordStat(
                id: word,
                word: word,
                successRate: rate,
                attemptCount: counts.total
            )
        }
    }

    /// Rule-based рекомендация: если слабые слова имеют общую позицию звука —
    /// рекомендация по этой позиции, иначе — общая рекомендация.
    static func recommendation(
        for soundTarget: String,
        weakWords: [WeeklyWordStat]
    ) -> (key: String, argument: String) {
        guard !weakWords.isEmpty, let sound = soundTarget.first else {
            return ("weeklyReport.recommendation.keepGoing", soundTarget)
        }
        let lowered = String(sound).lowercased()

        var initialCount = 0
        var finalCount = 0
        for stat in weakWords {
            let word = stat.word.lowercased()
            if word.hasPrefix(lowered) { initialCount += 1 }
            if word.hasSuffix(lowered) { finalCount += 1 }
        }
        if initialCount >= 2 {
            return ("weeklyReport.recommendation.positionInitial", soundTarget)
        }
        if finalCount >= 2 {
            return ("weeklyReport.recommendation.positionFinal", soundTarget)
        }
        return ("weeklyReport.recommendation.positionMiddle", soundTarget)
    }
}

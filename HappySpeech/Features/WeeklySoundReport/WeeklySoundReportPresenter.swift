import Foundation
import OSLog

// MARK: - WeeklySoundReportPresentationLogic

@MainActor
protocol WeeklySoundReportPresentationLogic: AnyObject {
    func presentLoad(response: WeeklySoundReportModels.Load.Response, weekOffset: Int) async
    func presentLoadFailure() async
    func presentSelectSound(response: WeeklySoundReportModels.SelectSound.Response) async
    func presentShare(response: WeeklySoundReportModels.Load.Response, weekOffset: Int) async
}

// MARK: - WeeklySoundReportDisplayLogic

@MainActor
protocol WeeklySoundReportDisplayLogic: AnyObject {
    func displayLoad(viewModel: WeeklySoundReportModels.Load.ViewModel) async
    func displayLoadFailure() async
    func displaySelectSound(viewModel: WeeklySoundReportModels.SelectSound.ViewModel) async
    func displayShare(viewModel: WeeklySoundReportModels.Share.ViewModel) async
}

// MARK: - WeeklySoundReportPresenter (Clean Swift: Presenter)
//
// F-301 v25 — мапит Response → ViewModel.
// Все строки — через `String(localized:)`.

@MainActor
final class WeeklySoundReportPresenter: WeeklySoundReportPresentationLogic {

    weak var displayLogic: (any WeeklySoundReportDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklySoundReport.Presenter"
    )

    init(displayLogic: (any WeeklySoundReportDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Trend

    /// Вычисляет направление недельной динамики из дельты успешности.
    static func trendArrow(current: Double, previous: Double) -> TrendArrow {
        let delta = current - previous
        if delta > 0.05 { return .up }
        if delta < -0.05 { return .down }
        return .stable
    }

    // MARK: - Load

    func presentLoad(
        response: WeeklySoundReportModels.Load.Response,
        weekOffset: Int
    ) async {
        let sounds = Self.buildSoundCards(from: response)
        let totalSessions = response.weekSessions.count
        let activeDays = Self.activeDays(in: response.weekSessions)

        let summaryLine = Self.summaryLine(
            childName: response.childName,
            totalSessions: totalSessions
        )
        let dateRangeLabel = Self.dateRangeLabel(start: response.weekStart, end: response.weekEnd)

        let viewModel = WeeklySoundReportModels.Load.ViewModel(
            summaryLine: summaryLine,
            dateRangeLabel: dateRangeLabel,
            totalSessions: totalSessions,
            activeDays: activeDays,
            activeDaysProgress: Double(activeDays) / 7.0,
            sounds: sounds,
            weekOffset: weekOffset,
            canGoNext: weekOffset < 0
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    func presentLoadFailure() async {
        await displayLogic?.displayLoadFailure()
    }

    // MARK: - SelectSound

    func presentSelectSound(response: WeeklySoundReportModels.SelectSound.Response) async {
        let topFormatted = response.topWords.map { Self.formatWord($0) }
        let weakFormatted = response.weakWords.map { Self.formatWord($0) }
        let tip = String(
            format: String(localized: String.LocalizationValue(response.recommendationKey)),
            response.recommendationArgument
        )
        let viewModel = WeeklySoundReportModels.SelectSound.ViewModel(
            soundTarget: response.recommendationArgument,
            topWordsFormatted: topFormatted,
            weakWordsFormatted: weakFormatted,
            tipText: tip,
            hasWords: !topFormatted.isEmpty || !weakFormatted.isEmpty
        )
        await displayLogic?.displaySelectSound(viewModel: viewModel)
    }

    // MARK: - Share

    func presentShare(
        response: WeeklySoundReportModels.Load.Response,
        weekOffset: Int
    ) async {
        let cards = Self.buildSoundCards(from: response)
        let totalSessions = response.weekSessions.count
        let summary = Self.summaryLine(
            childName: response.childName,
            totalSessions: totalSessions
        )
        let dateRange = Self.dateRangeLabel(start: response.weekStart, end: response.weekEnd)

        var lines: [String] = []
        lines.append(String(localized: "weeklyReport.share.header"))
        lines.append(dateRange)
        lines.append(summary)
        for card in cards {
            let percent = Int((card.successRate * 100).rounded())
            lines.append(
                String(
                    format: String(localized: "weeklyReport.share.soundLine"),
                    card.soundLabel,
                    percent
                )
            )
        }
        let shareText = lines.joined(separator: "\n")

        let viewModel = WeeklySoundReportModels.Share.ViewModel(shareText: shareText)
        await displayLogic?.displayShare(viewModel: viewModel)
    }

    // MARK: - Builders

    static func buildSoundCards(
        from response: WeeklySoundReportModels.Load.Response
    ) -> [SoundCardViewModel] {
        response.targetSounds.compactMap { sound -> SoundCardViewModel? in
            let weekForSound = response.weekSessions.filter { $0.targetSound == sound }
            let prevForSound = response.previousWeekSessions.filter { $0.targetSound == sound }
            guard !weekForSound.isEmpty else { return nil }

            let current = averageRate(of: weekForSound)
            let previous = averageRate(of: prevForSound)

            return SoundCardViewModel(
                id: sound,
                soundLabel: String(
                    format: String(localized: "weeklyReport.sound.label"),
                    sound
                ),
                successRate: current,
                previousRate: previous,
                trendArrow: trendArrow(current: current, previous: previous),
                sessionCount: weekForSound.count
            )
        }
    }

    /// Средняя успешность по сессиям (по суммарным попыткам).
    static func averageRate(of sessions: [SessionDTO]) -> Double {
        let totalAttempts = sessions.reduce(0) { $0 + $1.totalAttempts }
        guard totalAttempts > 0 else { return 0 }
        let correct = sessions.reduce(0) { $0 + $1.correctAttempts }
        return Double(correct) / Double(totalAttempts)
    }

    /// Количество уникальных календарных дней с сессиями.
    static func activeDays(in sessions: [SessionDTO]) -> Int {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let days = Set(sessions.map { calendar.startOfDay(for: $0.date) })
        return days.count
    }

    static func summaryLine(childName: String, totalSessions: Int) -> String {
        if totalSessions == 0 {
            return String(localized: "weeklyReport.summary.empty")
        }
        let name = childName.isEmpty
            ? String(localized: "weeklyReport.summary.defaultName")
            : childName
        let countsPhrase = String(
            format: String(localized: "weeklyReport.summary.sessionsCount"),
            totalSessions
        )
        if totalSessions >= 5 {
            return String(
                format: String(localized: "weeklyReport.summary.great"),
                name,
                countsPhrase
            )
        }
        return String(
            format: String(localized: "weeklyReport.summary.normal"),
            name,
            countsPhrase
        )
    }

    static func dateRangeLabel(start: Date, end: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        let lastDay = end.addingTimeInterval(-1)
        return formatter.string(from: start) + " – " + formatter.string(from: lastDay)
    }

    static func formatWord(_ stat: WeeklyWordStat) -> String {
        let percent = Int((stat.successRate * 100).rounded())
        return String(
            format: String(localized: "weeklyReport.word.formatted"),
            stat.word,
            percent
        )
    }
}

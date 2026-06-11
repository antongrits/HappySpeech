import Foundation

// MARK: - WeeklyVideoReport mapping (Response → ViewState)
//
// Чистая трансформация реального недельного агрегата в оверлей-данные.
// Никаких выдуманных чисел: пустой агрегат → ViewState.empty.

extension WeeklyVideoReportModels {

    static func makeState(from response: Load.Response) -> ViewState {
        let aggregate = response.aggregate
        guard !aggregate.isEmpty else { return .empty }

        let accuracyPercent = Int((aggregate.summary.overallAccuracy * 100).rounded())

        let metrics: [OverlayMetric] = [
            OverlayMetric(
                id: "accuracy",
                icon: "target",
                value: "\(accuracyPercent)%",
                caption: String(localized: "weeklyVideoReport.metric.accuracy")
            ),
            OverlayMetric(
                id: "streak",
                icon: "flame.fill",
                value: String(
                    format: String(localized: "weeklyVideoReport.metric.streakValue"),
                    aggregate.summary.streakDays
                ),
                caption: String(localized: "weeklyVideoReport.metric.streak")
            ),
            OverlayMetric(
                id: "minutes",
                icon: "clock.fill",
                value: "\(aggregate.summary.totalMinutes)",
                caption: String(localized: "weeklyVideoReport.metric.minutes")
            ),
            OverlayMetric(
                id: "stars",
                icon: "star.fill",
                value: "\(aggregate.summary.totalStars)",
                caption: String(localized: "weeklyVideoReport.metric.stars")
            )
        ]

        // До 6 звуков, отсортированы по точности (топ → низ), как в бар-сцене.
        let sounds = aggregate.sounds
            .sorted { $0.accuracy > $1.accuracy }
            .prefix(6)
            .map { progress in
                SoundRow(
                    id: progress.sound,
                    sound: progress.sound,
                    accuracyPercent: Int((progress.accuracy * 100).rounded()),
                    trend: progress.trend
                )
            }

        return ViewState(
            isEmpty: false,
            childName: response.childName,
            weekLabel: response.weekLabel,
            overlayMetrics: metrics,
            sounds: Array(sounds)
        )
    }

    /// Метка недели «d–d месяц» из текущей даты (последние 7 дней).
    static func currentWeekLabel(now: Date = Date(), calendar: Calendar = .current) -> String {
        let end = now
        guard let start = calendar.date(byAdding: .day, value: -6, to: end) else { return "" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d"
        let startDay = formatter.string(from: start)
        formatter.dateFormat = "d MMMM"
        let endPart = formatter.string(from: end)
        return "\(startDay)–\(endPart)"
    }
}

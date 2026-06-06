import Foundation

// MARK: - PhonemeReportPresentationLogic

@MainActor
protocol PhonemeReportPresentationLogic: AnyObject {
    func presentLoad(_ response: PhonemeReportModels.Load.Response)
}

// MARK: - PhonemeReportPresenter

/// Форматирует реальный ответ интерактора в локализованную ViewModel.
/// Никаких вычислений точности здесь — только форматирование уже
/// посчитанных `PhonemeReportAggregator`-ом значений.
@MainActor
final class PhonemeReportPresenter: PhonemeReportPresentationLogic {

    weak var display: (any PhonemeReportDisplayLogic)?

    func presentLoad(_ response: PhonemeReportModels.Load.Response) {
        let title = String(localized: "phonemeReport.title")

        if let error = response.error {
            display?.displayLoad(.init(
                titleText: title,
                childNameText: "",
                summaryText: "",
                groups: [],
                coverageText: "",
                isEmpty: true,
                errorText: error.localizedDescription
            ))
            return
        }

        let rows = PhonemeReportAggregator.buildRows(
            targetSounds: response.targetSounds,
            sessions: response.sessions
        )
        let grouped = PhonemeReportAggregator.groupByFamily(rows)
        let (withData, total) = PhonemeReportAggregator.coverage(rows)

        let isEmpty = response.sessions.isEmpty && rows.allSatisfy { !$0.hasData }

        let groupVMs = grouped.map { entry in
            Self.makeGroup(family: entry.family, rows: entry.rows)
        }

        let childName = response.childName.isEmpty
            ? String(localized: "phonemeReport.child.unknown")
            : response.childName

        let summary = Self.makeSummary(
            sessions: response.sessions,
            rows: rows
        )

        let coverage = String(
            format: String(localized: "phonemeReport.coverage %lld %lld"),
            withData, total
        )

        display?.displayLoad(.init(
            titleText: title,
            childNameText: childName,
            summaryText: summary,
            groups: groupVMs,
            coverageText: coverage,
            isEmpty: isEmpty,
            errorText: nil
        ))
    }

    // MARK: - Group

    private static func makeGroup(
        family: SoundFamily,
        rows: [PhonemeReportRow]
    ) -> PhonemeReportGroupViewModel {
        let withData = rows.filter(\.hasData).count
        let subtitle = String(
            format: String(localized: "phonemeReport.group.subtitle %lld %lld"),
            withData, rows.count
        )
        return PhonemeReportGroupViewModel(
            familyRaw: family.rawValue,
            title: family.displayName,
            subtitle: subtitle,
            rows: rows.map(Self.makeRow)
        )
    }

    // MARK: - Row

    private static func makeRow(_ row: PhonemeReportRow) -> PhonemeRowViewModelA09 {
        guard let accuracy = row.accuracy, row.hasData else {
            return PhonemeRowViewModelA09(
                sound: row.sound,
                accuracyText: String(localized: "phonemeReport.noData"),
                accuracyPercent: nil,
                tone: nil,
                detailText: String(localized: "phonemeReport.notPracticed"),
                trendText: nil,
                trendDirection: nil,
                stageText: nil,
                history: []
            )
        }

        let percent = Int((accuracy * 100).rounded())
        let accuracyText = String(
            format: String(localized: "phonemeReport.accuracy.percent %lld"),
            percent
        )
        let tone = AccuracyTone.make(from: percent)

        let detail = String(
            format: String(localized: "phonemeReport.row.detail %lld %lld"),
            row.attempts, row.sessionCount
        )

        let (trendText, trendDirection) = Self.makeTrend(row.trendDelta)
        let stageText = row.lastStageRaw.flatMap(Self.stageTitle)

        return PhonemeRowViewModelA09(
            sound: row.sound,
            accuracyText: accuracyText,
            accuracyPercent: percent,
            tone: tone,
            detailText: detail,
            trendText: trendText,
            trendDirection: trendDirection,
            stageText: stageText,
            history: row.history
        )
    }

    // MARK: - Trend

    /// Возвращает (подпись, направление). Порог стабильности ±3 п.п. —
    /// меньшие колебания считаем шумом, не трендом.
    private static func makeTrend(_ delta: Double?) -> (String?, Int?) {
        guard let delta else { return (nil, nil) }
        let points = Int((delta * 100).rounded())
        if points >= 3 {
            let text = String(
                format: String(localized: "phonemeReport.trend.up %lld"),
                points
            )
            return (text, 1)
        }
        if points <= -3 {
            let text = String(
                format: String(localized: "phonemeReport.trend.down %lld"),
                abs(points)
            )
            return (text, -1)
        }
        return (String(localized: "phonemeReport.trend.stable"), 0)
    }

    // MARK: - Summary

    private static func makeSummary(
        sessions: [SessionDTO],
        rows: [PhonemeReportRow]
    ) -> String {
        guard !sessions.isEmpty else {
            return String(localized: "phonemeReport.summary.empty")
        }
        let practiced = rows.filter(\.hasData).count
        let totalSessions = sessions.count
        return String(
            format: String(localized: "phonemeReport.summary %lld %lld"),
            practiced, totalSessions
        )
    }

    // MARK: - Stage title

    private static func stageTitle(_ raw: String) -> String? {
        guard let stage = CorrectionStage(rawValue: raw) else { return nil }
        return stage.displayName
    }
}

import Foundation
import OSLog

// MARK: - WeeklyParentTipInteractor

/// Бизнес-логика «Совет недели» (родитель).
///
/// Совет берётся из курируемого контента (`WeeklyParentTipContent`) и
/// выбирается по номеру календарной недели — поэтому он стабилен в течение
/// недели и реально меняется на следующей. Календарь инжектится для
/// тестируемости.
@MainActor
@Observable
final class WeeklyParentTipInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklyParentTip"
    )

    var state: WeeklyParentTipModels.ViewState

    init(calendar: Calendar = .current, now: Date = Date()) {
        let week = calendar.component(.weekOfYear, from: now)
        let tip = WeeklyParentTipContent.tip(forWeek: week)
        self.state = WeeklyParentTipModels.ViewState(
            tip: tip,
            weekLabel: String(format: String(localized: "weeklyTip.weekLabel %lld"), week)
        )
        Self.logger.info("loaded tip \(tip.id, privacy: .public) for week \(week, privacy: .public)")
    }

    func recordShare() {
        Self.logger.info("share tip \(self.state.tip.id, privacy: .public)")
    }

    /// Готовый текст для системного share-листа: заголовок, основной текст и
    /// пронумерованные упражнения. Используется `UIActivityViewController`.
    var shareText: String {
        let tip = state.tip
        var lines: [String] = [tip.title, ""]
        lines.append(contentsOf: tip.bodyParagraphs)
        if !tip.bulletPoints.isEmpty {
            lines.append("")
            for (index, bullet) in tip.bulletPoints.enumerated() {
                lines.append("\(index + 1). \(bullet)")
            }
        }
        lines.append("")
        lines.append("— \(tip.authorName), \(tip.authorRole)")
        lines.append(String(localized: "weeklyTip.share.footer"))
        return lines.joined(separator: "\n")
    }
}

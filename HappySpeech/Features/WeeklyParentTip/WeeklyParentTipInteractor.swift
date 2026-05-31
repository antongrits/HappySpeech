import Foundation
import OSLog

// MARK: - WeeklyParentTipInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class WeeklyParentTipInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WeeklyParentTip"
    )

    var state: WeeklyParentTipModels.ViewState

    init() {
        self.state = .initial
    }

    func recordShare() {
        Self.logger.info("share tip \(self.state.tip.id, privacy: .public)")
    }

    /// Готовый текст для системного share-листа: заголовок, основной текст
    /// и пронумерованные упражнения. Используется `UIActivityViewController`.
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

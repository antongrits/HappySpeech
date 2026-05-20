import Foundation

@MainActor
final class DailyTimeCapPresenter {

    weak var displayLogic: (any DailyTimeCapDisplayLogic)?

    /// Канонические опции слайдера. По ТЗ: 15 / 20 / 30 / 45 / 60 / 90 минут.
    static let minuteOptions: [Int] = [15, 20, 30, 45, 60, 90]

    init(displayLogic: any DailyTimeCapDisplayLogic) {
        self.displayLogic = displayLogic
    }

    func presentStatus(response: DailyTimeCapModels.Status.Response) async {
        let usedMinutes = Int(ceil(response.usedSeconds / 60.0))
        let capMinutes = max(1, response.capMinutes)
        let progress = response.usedSeconds / (Double(capMinutes) * 60.0)
        let tint: DailyTimeCapModels.Status.TintLevel
        switch progress {
        case ..<0.6:
            tint = .green
        case ..<1.0:
            tint = .yellow
        default:
            tint = .red
        }
        let isCapped = response.isEnabled && progress >= 1.0
        let usageLabel = String(localized: "dailyTimeCap.usage.format")
            .replacingOccurrences(of: "{used}", with: "\(usedMinutes)")
            .replacingOccurrences(of: "{cap}", with: "\(capMinutes)")
        let footnote: String
        if !response.isEnabled {
            footnote = String(localized: "dailyTimeCap.footnote.disabled")
        } else if isCapped {
            footnote = String(localized: "dailyTimeCap.footnote.capped")
        } else {
            let remaining = max(0, capMinutes - usedMinutes)
            footnote = String(localized: "dailyTimeCap.footnote.remaining.format")
                .replacingOccurrences(of: "{remaining}", with: "\(remaining)")
        }
        let viewModel = DailyTimeCapModels.Status.ViewModel(
            isEnabled: response.isEnabled,
            capMinutes: capMinutes,
            availableMinuteOptions: Self.minuteOptions,
            usedMinutes: usedMinutes,
            usageLabel: usageLabel,
            progress: progress,
            progressTint: tint,
            isCapped: isCapped,
            footnote: footnote
        )
        await displayLogic?.displayStatus(viewModel: viewModel)
    }
}

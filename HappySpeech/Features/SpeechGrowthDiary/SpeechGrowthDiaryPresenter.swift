import Foundation

@MainActor
final class SpeechGrowthDiaryPresenter {

    weak var displayLogic: (any SpeechGrowthDiaryDisplayLogic)?

    init(displayLogic: any SpeechGrowthDiaryDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - List

    func presentList(response: SpeechGrowthDiaryModels.List.Response) async {
        let now = Date()
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "ru_RU")
            return formatter
        }()
        let rows = response.clips.map { clip -> SpeechGrowthDiaryModels.List.ClipRow in
            let dateLabel = dateFormatter.string(from: clip.recordedAt)
            let duration = formatDuration(clip.durationSeconds)
            let isShared = clip.shareToken != nil
            let isExpired: Bool
            if let exp = clip.shareTokenExpiresAt {
                isExpired = exp < now
            } else {
                isExpired = false
            }
            return SpeechGrowthDiaryModels.List.ClipRow(
                id: clip.id,
                recordedAtLabel: dateLabel,
                durationLabel: duration,
                topicTag: clip.topicTag,
                targetSound: clip.targetSound,
                note: clip.note,
                isShared: isShared,
                isShareExpired: isExpired
            )
        }
        let viewModel = SpeechGrowthDiaryModels.List.ViewModel(
            clips: rows,
            isEmpty: rows.isEmpty
        )
        await displayLogic?.displayList(viewModel: viewModel)
    }

    // MARK: - Share

    func presentShare(response: SpeechGrowthDiaryModels.Share.Response) async {
        let formatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            formatter.locale = Locale(identifier: "ru_RU")
            return formatter
        }()
        let viewModel = SpeechGrowthDiaryModels.Share.ViewModel(
            token: response.token,
            expiresAtLabel: formatter.string(from: response.expiresAt),
            copyMessage: "Токен скопирован. Действует до \(formatter.string(from: response.expiresAt))."
        )
        await displayLogic?.displayShare(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        let mins = total / 60
        let secs = total % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

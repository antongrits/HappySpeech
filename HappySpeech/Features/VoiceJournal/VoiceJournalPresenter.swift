import Foundation

// MARK: - VoiceJournalPresenter

@MainActor
final class VoiceJournalPresenter {

    weak var displayLogic: (any VoiceJournalDisplayLogic)?

    init(displayLogic: any VoiceJournalDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load Entries

    func presentLoadEntries(response: VoiceJournalModels.LoadEntries.Response) async {
        let vm = makeViewModel(from: response.entries)
        await displayLogic?.displayLoadEntries(viewModel: vm)
    }

    // MARK: - Recording lifecycle

    func presentRecordingStarted() async {
        await displayLogic?.displayRecordingStarted()
    }

    func presentRecordingFailed(message: String) async {
        await displayLogic?.displayRecordingFailed(message: message)
    }

    func presentRecordingSaved(allEntries: [VoiceJournalEntry]) async {
        let vm = makeViewModel(from: allEntries)
        await displayLogic?.displayRecordingSaved(viewModel: vm)
    }

    // MARK: - Helpers

    private func makeViewModel(
        from entries: [VoiceJournalEntry]
    ) -> VoiceJournalModels.LoadEntries.ViewModel {
        let rows = entries.map { entry in
            VoiceJournalModels.LoadEntries.Row(
                id: entry.id,
                title: entry.title.isEmpty
                    ? Self.defaultTitle(for: entry.date)
                    : entry.title,
                dateText: Self.dayDateString(for: entry.date),
                durationText: Self.durationLabel(seconds: entry.durationSeconds),
                accessibilityLabel: Self.accessibilityLabel(for: entry),
                entry: entry
            )
        }
        return VoiceJournalModels.LoadEntries.ViewModel(
            rows: rows,
            isEmpty: rows.isEmpty,
            emptyTitle: String(localized: "voice.journal.empty.title"),
            emptyBody: String(localized: "voice.journal.empty.body"),
            emptyCtaTitle: String(localized: "voice.journal.empty.cta")
        )
    }

    private static let dayMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "d MMMM"
        return f
    }()

    private static func defaultTitle(for date: Date) -> String {
        String(
            format: String(localized: "voice.journal.default.title.format"),
            dayMonthFormatter.string(from: date)
        )
    }

    private static func dayDateString(for date: Date) -> String {
        dayMonthFormatter.string(from: date)
    }

    private static func durationLabel(seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }

    private static func accessibilityLabel(for entry: VoiceJournalEntry) -> String {
        let title = entry.title.isEmpty ? defaultTitle(for: entry.date) : entry.title
        return String(
            format: String(localized: "voice.journal.row.a11y.format"),
            title,
            durationLabel(seconds: entry.durationSeconds)
        )
    }
}

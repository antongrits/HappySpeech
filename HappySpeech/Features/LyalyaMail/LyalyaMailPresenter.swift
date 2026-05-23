import Foundation

// MARK: - LyalyaMailPresentationLogic

@MainActor
protocol LyalyaMailPresentationLogic: AnyObject {
    func presentLetters(response: LyalyaMailModels.LoadMail.Response) async
    func presentOpenedLetter(response: LyalyaMailModels.OpenLetter.Response) async
    func presentDeleted(response: LyalyaMailModels.Delete.Response) async
}

// MARK: - LyalyaMailPresenter

@MainActor
final class LyalyaMailPresenter: LyalyaMailPresentationLogic {

    weak var displayLogic: (any LyalyaMailDisplayLogic)?

    init(displayLogic: any LyalyaMailDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLetters(response: LyalyaMailModels.LoadMail.Response) async {
        let formatter = makeDateFormatter()
        let unreadCount = response.letters.filter { !$0.isRead }.count
        let sortedLetters = response.letters.sorted { lhs, rhs in
            // Сначала непрочитанные, потом по дате (новые сверху).
            if lhs.isRead != rhs.isRead { return !lhs.isRead }
            return lhs.date > rhs.date
        }
        let rows = sortedLetters.map { letter in
            LyalyaLetterRowViewModel(
                id: letter.id,
                title: letter.title,
                preview: makePreview(body: letter.body),
                dateLabel: formatter.string(from: letter.date),
                isRead: letter.isRead,
                mascotState: letter.kind.mascotState,
                accessibilityLabel: makeRowA11y(letter: letter, formatter: formatter)
            )
        }
        let summary = makeSummary(total: response.letters.count, unread: unreadCount)
        let viewModel = LyalyaMailModels.LoadMail.ViewModel(
            unreadCount: unreadCount,
            isEmpty: response.letters.isEmpty,
            rows: rows,
            accessibilitySummary: summary
        )
        await displayLogic?.displayLetters(viewModel: viewModel)
    }

    // MARK: - Open

    func presentOpenedLetter(response: LyalyaMailModels.OpenLetter.Response) async {
        let formatter = makeDateFormatter()
        let viewModel = LyalyaMailModels.OpenLetter.ViewModel(
            title: response.letter.title,
            body: response.letter.body,
            dateLabel: formatter.string(from: response.letter.date),
            mascotState: response.letter.kind.mascotState,
            hasAudio: response.letter.audioFileName != nil,
            audioFileName: response.letter.audioFileName
        )
        await displayLogic?.displayOpenedLetter(viewModel: viewModel)
    }

    // MARK: - Delete

    func presentDeleted(response: LyalyaMailModels.Delete.Response) async {
        await displayLogic?.displayDeleted(removedId: response.removedId)
    }

    // MARK: - Helpers

    private func makePreview(body: String) -> String {
        let trimmed = body
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
        if trimmed.count <= 80 { return trimmed }
        let prefix = trimmed.prefix(80)
        return String(prefix) + "…"
    }

    private func makeSummary(total: Int, unread: Int) -> String {
        if total == 0 { return "Ляля скоро напишет тебе!" }
        return "Писем: \(total), непрочитанных: \(unread)"
    }

    private func makeRowA11y(letter: LyalyaLetterDTO, formatter: DateFormatter) -> String {
        let readState = letter.isRead ? "прочитано" : "новое"
        return "\(letter.title), \(formatter.string(from: letter.date)), \(readState)"
    }

    private func makeDateFormatter() -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }
}

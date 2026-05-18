import Foundation
import OSLog

// MARK: - LexicalThemesPresentationLogic

@MainActor
protocol LexicalThemesPresentationLogic: AnyObject {
    func presentThemes(response: LexicalThemesModels.LoadThemes.Response) async
    func presentThemeStart(response: LexicalThemesModels.StartTheme.Response) async
    func presentAnswer(response: LexicalThemesModels.Answer.Response) async
}

// MARK: - LexicalThemesPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 7 «Мир слов».
//
// Строит ViewModel для хаба тем и мини-игр. Варианты ответа строятся
// детерминированно: индекс 0 — правильный (согласовано с
// `LexicalThemesInteractor.correctOptionIndex`), далее — дистракторы.
// Все строки — String(localized:).

@MainActor
final class LexicalThemesPresenter: LexicalThemesPresentationLogic {

    weak var displayLogic: (any LexicalThemesDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LexicalThemes.Presenter"
    )

    init(displayLogic: (any LexicalThemesDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Themes hub

    func presentThemes(response: LexicalThemesModels.LoadThemes.Response) async {
        let cards = response.themes.map { theme in
            LexicalThemesModels.LoadThemes.ThemeCardViewModel(
                id: theme.id,
                title: theme.title,
                symbolName: theme.symbolName,
                wordCountLabel: String(
                    format: String(localized: "lexicalThemes.theme.wordCount"),
                    theme.words.count
                ),
                isMastered: response.masteredThemeIds.contains(theme.id),
                accessibilityLabel: response.masteredThemeIds.contains(theme.id)
                    ? String(
                        format: String(localized: "lexicalThemes.theme.a11y.mastered"),
                        theme.title
                      )
                    : String(
                        format: String(localized: "lexicalThemes.theme.a11y"),
                        theme.title,
                        theme.words.count
                      )
            )
        }
        let viewModel = LexicalThemesModels.LoadThemes.ViewModel(
            title: String(localized: "lexicalThemes.title"),
            themes: cards,
            masteredCountLabel: String(
                format: String(localized: "lexicalThemes.masteredCount"),
                response.masteredThemeIds.count,
                response.themes.count
            )
        )
        await displayLogic?.displayThemes(viewModel: viewModel)
    }

    // MARK: - Theme start

    func presentThemeStart(response: LexicalThemesModels.StartTheme.Response) async {
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Theme start with empty rounds")
            return
        }
        let total = response.rounds.count
        let viewModel = LexicalThemesModels.StartTheme.ViewModel(
            themeTitle: response.theme.title,
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayThemeStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: LexicalThemesModels.Answer.Response) async {
        let feedback = response.wasCorrect
            ? String(localized: "lexicalThemes.feedback.correct")
            : String(localized: "lexicalThemes.feedback.tryAgain")

        let nextVM: LexicalThemesModels.StartTheme.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: LexicalThemesModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            let mastered = accuracy >= LexicalThemesInteractor.masteryThreshold
            summary = .init(
                title: mastered
                    ? String(localized: "lexicalThemes.summary.mastered")
                    : String(localized: "lexicalThemes.summary.title"),
                scoreText: String(
                    format: String(localized: "lexicalThemes.summary.score"),
                    response.correctCount,
                    response.totalRounds
                ),
                correctCount: response.correctCount,
                totalRounds: response.totalRounds,
                accuracyFraction: accuracy,
                isThemeMastered: mastered,
                encouragement: Self.encouragement(for: accuracy)
            )
        } else {
            summary = nil
        }

        let viewModel = LexicalThemesModels.Answer.ViewModel(
            wasCorrect: response.wasCorrect,
            feedbackText: feedback,
            isFinished: response.isFinished,
            nextRound: nextVM,
            summary: summary
        )
        await displayLogic?.displayAnswer(viewModel: viewModel)
    }

    // MARK: - Round building

    static func makeRoundVM(
        _ round: LexicalRound,
        index: Int,
        total: Int
    ) -> LexicalThemesModels.StartTheme.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "lexicalThemes.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        return .init(
            id: round.id,
            kind: round.kind,
            prompt: prompt(for: round),
            focusWord: round.word.text,
            options: options(for: round),
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "lexicalThemes.round.a11y"),
                prompt(for: round)
            )
        )
    }

    private static func prompt(for round: LexicalRound) -> String {
        switch round.kind {
        case .naming:
            return String(
                format: String(localized: "lexicalThemes.prompt.naming"),
                round.word.attribute
            )
        case .generalization:
            return String(localized: "lexicalThemes.prompt.generalization")
        case .oddOneOut:
            return String(localized: "lexicalThemes.prompt.oddOneOut")
        case .action:
            return String(
                format: String(localized: "lexicalThemes.prompt.action"),
                round.word.text
            )
        }
    }

    /// Строит варианты — индекс 0 всегда правильный.
    private static func options(
        for round: LexicalRound
    ) -> [LexicalThemesModels.StartTheme.OptionViewModel] {
        let labels: [String]
        switch round.kind {
        case .naming:
            // Угадать слово по признаку: правильное слово + слова других тем.
            labels = [round.word.text] + distractorWords(round)
        case .generalization:
            // Назвать одним словом: правильное обобщение + чужие обобщения.
            let theme = LexicalThemesCorpus.theme(id: round.themeId)
            let correct = theme?.generalization ?? round.themeId
            let others = LexicalThemesCorpus.allGeneralizations
                .filter { $0 != correct }
                .shuffled()
                .prefix(2)
            labels = [correct] + others
        case .oddOneOut:
            // Найти лишнее: лишнее слово (чужой темы) + два слова темы.
            let theme = LexicalThemesCorpus.theme(id: round.themeId)
            let own = (theme?.words ?? [])
                .filter { $0.id != round.word.id }
                .map(\.text)
                .shuffled()
                .prefix(2)
            let intruder = LexicalThemesCorpus
                .words(excludingTheme: round.themeId)
                .map(\.text)
                .shuffled()
                .first ?? round.word.text
            labels = [intruder] + own
        case .action:
            // Что делает: правильное действие + чужие действия.
            let correct = round.word.action
            let others = LexicalThemesCorpus.allWords
                .map(\.action)
                .filter { $0 != correct }
                .shuffled()
                .prefix(2)
            labels = [correct] + others
        }
        return labels.enumerated().map { index, label in
            .init(id: index, label: label)
        }
    }

    private static func distractorWords(_ round: LexicalRound) -> [String] {
        LexicalThemesCorpus
            .words(excludingTheme: round.themeId)
            .map(\.text)
            .shuffled()
            .prefix(2)
            .map { $0 }
    }

    // MARK: - Helpers

    private static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "lexicalThemes.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "lexicalThemes.encourage.good")
        } else {
            return String(localized: "lexicalThemes.encourage.keepGoing")
        }
    }
}

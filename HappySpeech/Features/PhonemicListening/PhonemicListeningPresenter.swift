import Foundation
import OSLog

// MARK: - PhonemicListeningPresentationLogic

@MainActor
protocol PhonemicListeningPresentationLogic: AnyObject {
    func presentStart(response: PhonemicListeningModels.Start.Response) async
    func presentAnswer(response: PhonemicListeningModels.Answer.Response) async
}

// MARK: - PhonemicListeningPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 12 «Слушай внимательно».
//
// Строит игровые ViewModel: вопрос-инструкцию, варианты ответа, прогресс,
// тёплую обратную связь и сводку. Варианты строятся детерминированно —
// тот же порядок, что использует `PhonemicListeningInteractor` для проверки
// (`correctOptionIndex`). Все строки — String(localized:).

@MainActor
final class PhonemicListeningPresenter: PhonemicListeningPresentationLogic {

    weak var displayLogic: (any PhonemicListeningDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemicListening.Presenter"
    )

    init(displayLogic: (any PhonemicListeningDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: PhonemicListeningModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = PhonemicListeningModels.Start.ViewModel(
            title: String(localized: "phonemicListening.title"),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: PhonemicListeningModels.Answer.Response) async {
        let feedback = response.wasCorrect
            ? String(localized: "phonemicListening.feedback.correct")
            : String(localized: "phonemicListening.feedback.tryAgain")

        let nextVM: PhonemicListeningModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: PhonemicListeningModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "phonemicListening.summary.title"),
                scoreText: String(
                    format: String(localized: "phonemicListening.summary.score"),
                    response.correctCount,
                    response.totalRounds
                ),
                correctCount: response.correctCount,
                totalRounds: response.totalRounds,
                accuracyFraction: accuracy,
                encouragement: Self.encouragement(for: accuracy)
            )
        } else {
            summary = nil
        }

        let viewModel = PhonemicListeningModels.Answer.ViewModel(
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
        _ round: PhonemicRound,
        index: Int,
        total: Int
    ) -> PhonemicListeningModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "phonemicListening.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0

        return .init(
            id: round.id,
            operation: round.operation,
            word: round.word.text,
            prompt: prompt(for: round),
            options: options(for: round),
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "phonemicListening.round.a11y"),
                prompt(for: round),
                round.word.text
            )
        )
    }

    private static func prompt(for round: PhonemicRound) -> String {
        switch round.operation {
        case .position:
            return String(
                format: String(localized: "phonemicListening.prompt.position"),
                round.word.targetSound
            )
        case .count:
            return String(localized: "phonemicListening.prompt.count")
        case .synthesis:
            return String(localized: "phonemicListening.prompt.synthesis")
        }
    }

    /// Строит варианты детерминированно — порядок согласован с
    /// `PhonemicListeningInteractor.correctOptionIndex`.
    private static func options(
        for round: PhonemicRound
    ) -> [PhonemicListeningModels.Start.OptionViewModel] {
        switch round.operation {
        case .position:
            // Порядок: начало / середина / конец — индекс из `PhonemePosition.allCases`.
            return PhonemePosition.allCases.enumerated().map { index, pos in
                .init(id: index, label: positionLabel(pos))
            }
        case .count:
            // Индекс 1 — правильный (soundCount). Варианты: -1, 0, +1.
            let count = round.word.soundCount
            return [count - 1, count, count + 1].enumerated().map { index, value in
                .init(id: index, label: "\(max(1, value))")
            }
        case .synthesis:
            // Индекс 0 — правильное слово; 1–2 — фонетически близкие отвлекающие.
            let labels = [round.word.text] + synthesisDistractors(for: round.word)
            return labels.enumerated().map { index, label in
                .init(id: index, label: label)
            }
        }
    }

    private static func positionLabel(_ position: PhonemePosition) -> String {
        switch position {
        case .start:  return String(localized: "phonemicListening.position.start")
        case .middle: return String(localized: "phonemicListening.position.middle")
        case .end:    return String(localized: "phonemicListening.position.end")
        }
    }

    /// Возвращает два слова-дистрактора для операции синтеза.
    private static func synthesisDistractors(for word: PhonemicWord) -> [String] {
        let pool = PhonemicListeningCorpus.synthesisWords
            .map(\.text)
            .filter { $0 != word.text }
        return Array(pool.prefix(2))
    }

    // MARK: - Helpers

    private static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "phonemicListening.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "phonemicListening.encourage.good")
        } else {
            return String(localized: "phonemicListening.encourage.keepGoing")
        }
    }
}

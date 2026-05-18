import Foundation
import OSLog

// MARK: - ProsodyPresentationLogic

@MainActor
protocol ProsodyPresentationLogic: AnyObject {
    func presentStart(response: ProsodyModels.Start.Response) async
    func presentAnswer(response: ProsodyModels.Answer.Response) async
}

// MARK: - ProsodyPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 1 «Голосовые краски».
//
// Строит игровые ViewModel: инструкцию-вопрос, варианты ответа (для этапа
// различения), символ целевой интонации, обратную связь и сводку.
// Варианты строятся детерминированно — порядок согласован с
// `ProsodyInteractor.correctOptionIndex`. Все строки — String(localized:).

@MainActor
final class ProsodyPresenter: ProsodyPresentationLogic {

    weak var displayLogic: (any ProsodyDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Prosody.Presenter"
    )

    init(displayLogic: (any ProsodyDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: ProsodyModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let viewModel = ProsodyModels.Start.ViewModel(
            title: String(localized: "prosody.title"),
            totalRounds: total,
            firstRound: Self.makeRoundVM(firstRound, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Answer

    func presentAnswer(response: ProsodyModels.Answer.Response) async {
        let feedback = response.wasCorrect
            ? String(localized: "prosody.feedback.correct")
            : String(localized: "prosody.feedback.tryAgain")

        let nextVM: ProsodyModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = Self.makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: ProsodyModels.Answer.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "prosody.summary.title"),
                scoreText: String(
                    format: String(localized: "prosody.summary.score"),
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

        let viewModel = ProsodyModels.Answer.ViewModel(
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
        _ round: ProsodyRound,
        index: Int,
        total: Int
    ) -> ProsodyModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "prosody.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0
        let needsVoice = round.stage != .discriminate

        return .init(
            id: round.id,
            stage: round.stage,
            phraseText: round.phrase.text,
            prompt: prompt(for: round),
            intonationSymbol: round.phrase.intonation.symbolName,
            options: options(for: round),
            needsVoice: needsVoice,
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "prosody.round.a11y"),
                prompt(for: round),
                round.phrase.text
            )
        )
    }

    private static func prompt(for round: ProsodyRound) -> String {
        switch round.stage {
        case .discriminate:
            return String(localized: "prosody.prompt.discriminate")
        case .imitate:
            return String(localized: "prosody.prompt.imitate")
        case .produce:
            return String(
                format: String(localized: "prosody.prompt.produce"),
                intonationName(round.phrase.intonation)
            )
        }
    }

    /// Строит варианты для этапа различения; порядок — `IntonationType.allCases`.
    private static func options(
        for round: ProsodyRound
    ) -> [ProsodyModels.Start.OptionViewModel] {
        guard round.stage == .discriminate else { return [] }
        return IntonationType.allCases.enumerated().map { index, type in
            .init(id: index, label: intonationName(type), symbol: type.symbolName)
        }
    }

    static func intonationName(_ type: IntonationType) -> String {
        switch type {
        case .declarative:   return String(localized: "prosody.intonation.declarative")
        case .interrogative: return String(localized: "prosody.intonation.interrogative")
        case .exclamatory:   return String(localized: "prosody.intonation.exclamatory")
        }
    }

    // MARK: - Helpers

    private static func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "prosody.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "prosody.encourage.good")
        } else {
            return String(localized: "prosody.encourage.keepGoing")
        }
    }
}

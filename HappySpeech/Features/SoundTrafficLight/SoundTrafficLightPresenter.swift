import Foundation
import OSLog

// MARK: - SoundTrafficLightPresentationLogic

@MainActor
protocol SoundTrafficLightPresentationLogic: AnyObject {
    func presentStart(response: SoundTrafficLightModels.Start.Response) async
    func presentSort(response: SoundTrafficLightModels.Sort.Response) async
}

// MARK: - SoundTrafficLightPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Собирает игровые ViewModel: инструкции, подписи гаражей, прогресс,
// дружелюбную обратную связь и итоговую сводку. Все строки — String(localized:).
// Тон — тёплый, поддерживающий (детский контур).

@MainActor
final class SoundTrafficLightPresenter: SoundTrafficLightPresentationLogic {

    weak var displayLogic: (any SoundTrafficLightDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.Presenter"
    )

    init(displayLogic: (any SoundTrafficLightDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: SoundTrafficLightModels.Start.Response) async {
        let total = response.rounds.count
        guard let firstRound = response.rounds.first else {
            Self.logger.error("Start with empty rounds")
            return
        }
        let firstVM = makeRoundVM(firstRound, index: 0, total: total)

        let viewModel = SoundTrafficLightModels.Start.ViewModel(
            title: String(localized: "soundTrafficLight.title"),
            instruction: String(localized: "soundTrafficLight.instruction"),
            garageALabel: String(
                format: String(localized: "soundTrafficLight.garage.label"),
                response.pair.soundA
            ),
            garageBLabel: String(
                format: String(localized: "soundTrafficLight.garage.label"),
                response.pair.soundB
            ),
            totalRounds: total,
            firstRound: firstVM
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Sort

    func presentSort(response: SoundTrafficLightModels.Sort.Response) async {
        let feedback = response.wasCorrect
            ? String(localized: "soundTrafficLight.feedback.correct")
            : String(localized: "soundTrafficLight.feedback.tryAgain")

        let nextVM: SoundTrafficLightModels.Start.RoundViewModel?
        if let nextRound = response.nextRound, let nextIndex = response.nextRoundIndex {
            nextVM = makeRoundVM(nextRound, index: nextIndex, total: response.totalRounds)
        } else {
            nextVM = nil
        }

        let summary: SoundTrafficLightModels.Sort.SummaryViewModel?
        if response.isFinished {
            let accuracy = response.totalRounds > 0
                ? Double(response.correctCount) / Double(response.totalRounds)
                : 0
            summary = .init(
                title: String(localized: "soundTrafficLight.summary.title"),
                scoreText: String(
                    format: String(localized: "soundTrafficLight.summary.score"),
                    response.correctCount,
                    response.totalRounds
                ),
                correctCount: response.correctCount,
                totalRounds: response.totalRounds,
                accuracyFraction: accuracy,
                encouragement: encouragement(for: accuracy)
            )
        } else {
            summary = nil
        }

        let viewModel = SoundTrafficLightModels.Sort.ViewModel(
            wasCorrect: response.wasCorrect,
            feedbackText: feedback,
            isFinished: response.isFinished,
            nextRound: nextVM,
            summary: summary
        )
        await displayLogic?.displaySort(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func makeRoundVM(
        _ round: TrafficLightRound,
        index: Int,
        total: Int
    ) -> SoundTrafficLightModels.Start.RoundViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "soundTrafficLight.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0
        return .init(
            id: round.id,
            word: round.word,
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "soundTrafficLight.round.a11y"),
                round.word,
                progressLabel
            )
        )
    }

    private func encouragement(for accuracy: Double) -> String {
        if accuracy >= 0.8 {
            return String(localized: "soundTrafficLight.encourage.great")
        } else if accuracy >= 0.5 {
            return String(localized: "soundTrafficLight.encourage.good")
        } else {
            return String(localized: "soundTrafficLight.encourage.keepGoing")
        }
    }
}

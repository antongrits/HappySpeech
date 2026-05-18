import Foundation
import OSLog

// MARK: - SpeechTempoPresentationLogic

@MainActor
protocol SpeechTempoPresentationLogic: AnyObject {
    func presentStart(response: SpeechTempoModels.Start.Response) async
    func presentFinish(response: SpeechTempoModels.Finish.Response) async
}

// MARK: - SpeechTempoPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Строит игровые ViewModel: инструкцию, прогресс, качественную оценку темпа
// (без чисел для ребёнка) и тёплую сводку. Все строки — String(localized:).

@MainActor
final class SpeechTempoPresenter: SpeechTempoPresentationLogic {

    weak var displayLogic: (any SpeechTempoDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechTempo.Presenter"
    )

    init(displayLogic: (any SpeechTempoDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: SpeechTempoModels.Start.Response) async {
        let total = response.rhymes.count
        guard let firstRhyme = response.rhymes.first else {
            Self.logger.error("Start with empty rhymes")
            return
        }
        let viewModel = SpeechTempoModels.Start.ViewModel(
            title: String(localized: "speechTempo.title"),
            instruction: String(localized: "speechTempo.instruction"),
            totalRhymes: total,
            firstRhyme: Self.makeRhymeVM(firstRhyme, index: 0, total: total)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Finish

    func presentFinish(response: SpeechTempoModels.Finish.Response) async {
        let nextVM: SpeechTempoModels.Start.RhymeViewModel?
        if let nextRhyme = response.nextRhyme, let nextIndex = response.nextRhymeIndex {
            nextVM = Self.makeRhymeVM(nextRhyme, index: nextIndex, total: response.totalRhymes)
        } else {
            nextVM = nil
        }

        let summary: SpeechTempoModels.Finish.SummaryViewModel?
        if response.isFinished {
            summary = .init(
                title: String(localized: "speechTempo.summary.title"),
                scoreText: String(
                    format: String(localized: "speechTempo.summary.score"),
                    response.smoothCount,
                    response.totalRhymes
                ),
                smoothCount: response.smoothCount,
                totalRhymes: response.totalRhymes,
                encouragement: Self.encouragement(
                    smooth: response.smoothCount,
                    total: response.totalRhymes
                )
            )
        } else {
            summary = nil
        }

        let viewModel = SpeechTempoModels.Finish.ViewModel(
            rating: response.rating,
            ratingText: Self.ratingText(for: response.rating),
            isFinished: response.isFinished,
            nextRhyme: nextVM,
            summary: summary
        )
        await displayLogic?.displayFinish(viewModel: viewModel)
    }

    // MARK: - Helpers

    static func makeRhymeVM(
        _ rhyme: TempoRhyme,
        index: Int,
        total: Int
    ) -> SpeechTempoModels.Start.RhymeViewModel {
        let humanIndex = index + 1
        let progressLabel = String(
            format: String(localized: "speechTempo.progress"),
            humanIndex,
            total
        )
        let fraction = total > 0 ? Double(humanIndex) / Double(total) : 0
        return .init(
            id: rhyme.id,
            text: rhyme.text,
            syllables: rhyme.syllables,
            progressLabel: progressLabel,
            progressFraction: fraction,
            accessibilityLabel: String(
                format: String(localized: "speechTempo.rhyme.a11y"),
                rhyme.text
            )
        )
    }

    static func ratingText(for rating: TempoRating) -> String {
        switch rating {
        case .smooth:
            return String(localized: "speechTempo.rating.smooth")
        case .slightlyUneven:
            return String(localized: "speechTempo.rating.slightlyUneven")
        case .uneven:
            return String(localized: "speechTempo.rating.uneven")
        }
    }

    private static func encouragement(smooth: Int, total: Int) -> String {
        let fraction = total > 0 ? Double(smooth) / Double(total) : 0
        if fraction >= 0.7 {
            return String(localized: "speechTempo.encourage.great")
        } else if fraction >= 0.3 {
            return String(localized: "speechTempo.encourage.good")
        } else {
            return String(localized: "speechTempo.encourage.keepGoing")
        }
    }
}

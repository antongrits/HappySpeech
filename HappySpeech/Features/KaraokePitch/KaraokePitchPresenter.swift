import Foundation

// MARK: - KaraokePitchPresenter
//
// Формирует ViewModel из Response — без бизнес-логики. Все строки русские
// (kid-friendly, дружелюбный тон), Dynamic Type через TypographyTokens во view.

@MainActor
final class KaraokePitchPresenter {

    weak var displayLogic: (any KaraokePitchDisplayLogic)?

    init(displayLogic: any KaraokePitchDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: KaraokePitchModels.Start.Response) async {
        let viewModel = KaraokePitchModels.Start.ViewModel(
            phraseText: response.phrase.text,
            intonationSymbol: response.phrase.intonationSymbol,
            modelContour: response.modelContour,
            totalPhrases: response.totalPhrases,
            currentIndex: 0,
            accessibilityLabel: accessibilityLabelForPhrase(response.phrase)
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - LiveSample

    func presentLiveSample(response: KaraokePitchModels.LiveSample.Response) async {
        let amp = CGFloat(min(1.0, max(0.0, response.amplitude)))
        let viewModel = KaraokePitchModels.LiveSample.ViewModel(
            liveContour: response.liveContour,
            amplitudeNormalised: amp
        )
        await displayLogic?.displayLiveSample(viewModel: viewModel)
    }

    // MARK: - Score

    func presentScore(response: KaraokePitchModels.Score.Response) async {
        let percent = Int((response.similarity * 100).rounded())
        let stars = response.starsEarned
        let feedback = feedbackMessage(stars: stars)
        let accessibility = "Похоже на \(percent) процентов. Звёзд: \(stars)."
        let viewModel = KaraokePitchModels.Score.ViewModel(
            phraseText: response.phrase.text,
            similarityPercent: percent,
            starsEarned: stars,
            feedbackMessage: feedback,
            modelContour: response.modelContour,
            liveContour: response.liveContour,
            accessibilityLabel: accessibility
        )
        await displayLogic?.displayScore(viewModel: viewModel)
    }

    // MARK: - Private

    private func accessibilityLabelForPhrase(_ phrase: KaraokePhrase) -> String {
        // Делаем явное «вопрос/восклицание/повествование» для скринридера.
        let intonationName: String
        switch phrase.intonation.lowercased() {
        case "question":     intonationName = "вопрос"
        case "exclamation":  intonationName = "восклицание"
        default:             intonationName = "повествование"
        }
        return "Фраза: \(phrase.text). Интонация: \(intonationName)."
    }

    private func feedbackMessage(stars: Int) -> String {
        switch stars {
        case 3: return String(localized: "karaoke.feedback.three",
                              defaultValue: "Великолепно! Мелодика точная.")
        case 2: return String(localized: "karaoke.feedback.two",
                              defaultValue: "Здорово! Очень похоже.")
        case 1: return String(localized: "karaoke.feedback.one",
                              defaultValue: "Старайся! Попробуй ещё раз.")
        default: return String(localized: "karaoke.feedback.zero",
                               defaultValue: "Попробуй ещё раз — у тебя получится.")
        }
    }
}

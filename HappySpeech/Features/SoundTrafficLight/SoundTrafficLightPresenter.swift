import Foundation
import OSLog

// MARK: - SoundTrafficLightPresentationLogic

@MainActor
protocol SoundTrafficLightPresentationLogic: AnyObject {
    func presentStart(response: SoundTrafficLightModels.Start.Response) async
    func presentSort(response: SoundTrafficLightModels.Sort.Response) async
    func presentChoosePhrase(response: SoundTrafficLightModels.ChoosePhrase.Response) async
    func presentCountText(response: SoundTrafficLightModels.CountText.Response) async
}

// MARK: - SoundTrafficLightPresenter (Clean Swift: Presenter)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Собирает игровые ViewModel для всех уровней лестницы (слог/слово/фраза/
// текст): инструкции, подписи гаражей, прогресс, разметку слов фразы,
// эталоны счёта текста, дружелюбную обратную связь и итоговую сводку.
// Все строки — String(localized:). Тон — тёплый, поддерживающий.

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
        let pair = response.pair
        let viewModel = SoundTrafficLightModels.Start.ViewModel(
            title: String(localized: "soundTrafficLight.title"),
            instruction: instruction(for: response.level),
            levelLabel: levelLabel(for: response.level),
            level: response.level,
            garageALabel: garageLabel(pair.soundA),
            garageBLabel: garageLabel(pair.soundB),
            totalRounds: totalItems(in: response),
            firstRound: response.rounds.first.map {
                makeRoundVM($0, index: 0, total: response.rounds.count)
            },
            firstPhrase: response.phrases.first.map {
                makePhraseVM($0, index: 0, total: response.phrases.count)
            },
            firstText: response.texts.first.map {
                makeTextVM($0, index: 0, total: response.texts.count)
            }
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Sort (слог / слово)

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

        let viewModel = SoundTrafficLightModels.Sort.ViewModel(
            wasCorrect: response.wasCorrect,
            feedbackText: feedback,
            isFinished: response.isFinished,
            nextRound: nextVM,
            summary: response.isFinished
                ? makeSummary(
                    correct: response.correctCount,
                    total: response.totalRounds,
                    nextLevel: response.nextLevel
                )
                : nil
        )
        await displayLogic?.displaySort(viewModel: viewModel)
    }

    // MARK: - ChoosePhrase (фраза)

    func presentChoosePhrase(response: SoundTrafficLightModels.ChoosePhrase.Response) async {
        let feedback = response.wasCorrect
            ? String(localized: "soundTrafficLight.feedback.correct")
            : String(localized: "soundTrafficLight.feedback.tryAgain")

        let nextVM: SoundTrafficLightModels.Start.PhraseViewModel?
        if let nextPhrase = response.nextPhrase, let nextIndex = response.nextPhraseIndex {
            nextVM = makePhraseVM(nextPhrase, index: nextIndex, total: response.totalPhrases)
        } else {
            nextVM = nil
        }

        let viewModel = SoundTrafficLightModels.ChoosePhrase.ViewModel(
            wasCorrect: response.wasCorrect,
            feedbackText: feedback,
            isFinished: response.isFinished,
            nextPhrase: nextVM,
            summary: response.isFinished
                ? makeSummary(
                    correct: response.correctCount,
                    total: response.totalPhrases,
                    nextLevel: response.nextLevel
                )
                : nil
        )
        await displayLogic?.displayChoosePhrase(viewModel: viewModel)
    }

    // MARK: - CountText (текст)

    func presentCountText(response: SoundTrafficLightModels.CountText.Response) async {
        let feedback: String
        if response.textPassed {
            feedback = String(localized: "soundTrafficLight.text.feedback.correct")
        } else {
            feedback = String(localized: "soundTrafficLight.text.feedback.tryAgain")
        }

        let nextVM: SoundTrafficLightModels.Start.TextViewModel?
        if let nextText = response.nextText, let nextIndex = response.nextTextIndex {
            nextVM = makeTextVM(nextText, index: nextIndex, total: response.totalTexts)
        } else {
            nextVM = nil
        }

        let summary: SoundTrafficLightModels.Sort.SummaryViewModel?
        if response.isFinished {
            let nextLabel = response.pairCompleted
                ? String(localized: "soundTrafficLight.pair.completed")
                : nil
            summary = makeSummary(
                correct: response.passedCount,
                total: response.totalTexts,
                explicitNextLabel: nextLabel
            )
        } else {
            summary = nil
        }

        let viewModel = SoundTrafficLightModels.CountText.ViewModel(
            feedbackText: feedback,
            correctA: response.correctA,
            correctB: response.correctB,
            isFinished: response.isFinished,
            nextText: nextVM,
            summary: summary
        )
        await displayLogic?.displayCountText(viewModel: viewModel)
    }

    // MARK: - Builders

    private func makeRoundVM(
        _ round: TrafficLightRound,
        index: Int,
        total: Int
    ) -> SoundTrafficLightModels.Start.RoundViewModel {
        let progressLabel = progressLabel(humanIndex: index + 1, total: total)
        return .init(
            id: round.id,
            word: round.word,
            progressLabel: progressLabel,
            progressFraction: fraction(humanIndex: index + 1, total: total),
            accessibilityLabel: String(
                format: String(localized: "soundTrafficLight.round.a11y"),
                round.word,
                progressLabel
            )
        )
    }

    private func makePhraseVM(
        _ phrase: TrafficLightPhrase,
        index: Int,
        total: Int
    ) -> SoundTrafficLightModels.Start.PhraseViewModel {
        let setA = Set(phrase.wordsA.map { $0.lowercased() })
        let setB = Set(phrase.wordsB.map { $0.lowercased() })
        let words = phrase.text.split(separator: " ").map(String.init)
        let tokens = words.enumerated().map { offset, raw -> SoundTrafficLightModels.Start.PhraseTokenViewModel in
            let normalized = raw
                .trimmingCharacters(in: .punctuationCharacters)
                .lowercased()
            return .init(
                id: "\(phrase.id)-token-\(offset)",
                text: raw,
                containsA: setA.contains(normalized),
                containsB: setB.contains(normalized)
            )
        }
        return .init(
            id: phrase.id,
            text: phrase.text,
            tokens: tokens,
            progressLabel: progressLabel(humanIndex: index + 1, total: total),
            progressFraction: fraction(humanIndex: index + 1, total: total),
            correctSide: phrase.dominant,
            accessibilityLabel: String(
                format: String(localized: "soundTrafficLight.phrase.a11y"),
                phrase.text
            )
        )
    }

    private func makeTextVM(
        _ text: TrafficLightText,
        index: Int,
        total: Int
    ) -> SoundTrafficLightModels.Start.TextViewModel {
        let maxCount = max(text.countA, text.countB) + 4
        return .init(
            id: text.id,
            title: text.title,
            lines: text.lines,
            progressLabel: progressLabel(humanIndex: index + 1, total: total),
            progressFraction: fraction(humanIndex: index + 1, total: total),
            answerA: text.countA,
            answerB: text.countB,
            maxCount: maxCount,
            accessibilityLabel: String(
                format: String(localized: "soundTrafficLight.text.a11y"),
                text.title
            )
        )
    }

    private func makeSummary(
        correct: Int,
        total: Int,
        nextLevel: DifferentiationLevel? = nil,
        explicitNextLabel: String? = nil
    ) -> SoundTrafficLightModels.Sort.SummaryViewModel {
        let accuracy = total > 0 ? Double(correct) / Double(total) : 0
        let nextLabel: String?
        if let explicitNextLabel {
            nextLabel = explicitNextLabel
        } else if let nextLevel {
            nextLabel = String(
                format: String(localized: "soundTrafficLight.level.unlocked"),
                levelLabel(for: nextLevel)
            )
        } else {
            nextLabel = nil
        }
        return .init(
            title: String(localized: "soundTrafficLight.summary.title"),
            scoreText: String(
                format: String(localized: "soundTrafficLight.summary.score"),
                correct,
                total
            ),
            correctCount: correct,
            totalRounds: total,
            accuracyFraction: accuracy,
            encouragement: encouragement(for: accuracy),
            nextLevelLabel: nextLabel
        )
    }

    // MARK: - Localized text

    private func garageLabel(_ sound: String) -> String {
        String(format: String(localized: "soundTrafficLight.garage.label"), sound)
    }

    private func instruction(for level: DifferentiationLevel) -> String {
        switch level {
        case .syllable: return String(localized: "soundTrafficLight.instruction.syllable")
        case .word:     return String(localized: "soundTrafficLight.instruction")
        case .phrase:   return String(localized: "soundTrafficLight.instruction.phrase")
        case .text:     return String(localized: "soundTrafficLight.instruction.text")
        }
    }

    private func levelLabel(for level: DifferentiationLevel) -> String {
        switch level {
        case .syllable: return String(localized: "soundTrafficLight.level.syllable")
        case .word:     return String(localized: "soundTrafficLight.level.word")
        case .phrase:   return String(localized: "soundTrafficLight.level.phrase")
        case .text:     return String(localized: "soundTrafficLight.level.text")
        }
    }

    private func progressLabel(humanIndex: Int, total: Int) -> String {
        String(format: String(localized: "soundTrafficLight.progress"), humanIndex, total)
    }

    private func fraction(humanIndex: Int, total: Int) -> Double {
        total > 0 ? Double(humanIndex) / Double(total) : 0
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

    private func totalItems(in response: SoundTrafficLightModels.Start.Response) -> Int {
        switch response.level {
        case .syllable, .word: return response.rounds.count
        case .phrase:          return response.phrases.count
        case .text:            return response.texts.count
        }
    }
}

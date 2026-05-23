import Foundation

// MARK: - ListenAndChoosePresentationLogic

@MainActor
protocol ListenAndChoosePresentationLogic: AnyObject {
    func presentLoadRound(_ response: ListenAndChooseModels.LoadRound.Response)
    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response)
}

// MARK: - ListenAndChoosePresenter

@MainActor
final class ListenAndChoosePresenter: ListenAndChoosePresentationLogic {

    weak var display: (any ListenAndChooseDisplayLogic)?

    func presentLoadRound(_ response: ListenAndChooseModels.LoadRound.Response) {
        let options = response.options.map { item in
            ListenAndChooseModels.LoadRound.OptionViewModel(
                id: item.id,
                word: item.word,
                imageSystemName: Self.imageSymbol(for: item.word)
            )
        }
        let instruction: String = response.isRetry
            ? String(localized: "Давай попробуем ещё раз!")
            : String(localized: "Слушай внимательно и выбери картинку")

        let progressText: String?
        if response.totalQuestions > 1 {
            progressText = String(
                localized: "Вопрос \(response.questionNumber) из \(response.totalQuestions)"
            )
        } else {
            progressText = nil
        }

        // Q3.6 — локализованный заголовок бейджа сложности.
        let difficultyTitle = String(
            localized: String.LocalizationValue(response.difficulty.titleKey)
        )

        let vm = ListenAndChooseModels.LoadRound.ViewModel(
            targetWord: response.targetWord,
            options: options,
            correctIndex: response.correctIndex,
            instructionText: instruction,
            hintText: response.hint,
            progressText: progressText,
            isRetry: response.isRetry,
            difficulty: response.difficulty,
            difficultyTitle: difficultyTitle
        )
        display?.displayLoadRound(vm)
    }

    func presentSubmitAttempt(_ response: ListenAndChooseModels.SubmitAttempt.Response) {
        let feedback: String = {
            if response.isCorrect {
                if response.currentStreak >= 3 {
                    return String(localized: "Отлично! \(response.currentStreak) подряд!")
                }
                return String(localized: "Правильно!")
            }
            if response.shouldRevealAnswer {
                return String(localized: "Вот правильный ответ")
            }
            return String(localized: "Попробуй ещё раз")
        }()

        let streakText: String? = response.isCorrect && response.currentStreak >= 3
            ? String(localized: "Серия: \(response.currentStreak)")
            : nil

        let vm = ListenAndChooseModels.SubmitAttempt.ViewModel(
            isCorrect: response.isCorrect,
            feedbackText: feedback,
            shouldRevealAnswer: response.shouldRevealAnswer,
            correctIndex: response.correctIndex,
            finalScore: (response.isCorrect || response.shouldRevealAnswer) ? response.score : nil,
            streakText: streakText,
            hintText: response.hint
        )
        display?.displaySubmitAttempt(vm)
    }

    // MARK: Private

    /// Picks an Asset name (Illustration) for the given Russian word if available,
    /// otherwise falls back to a generic SF Symbol. HSContentSymbol auto-routes
    /// between Asset / SF Symbol rendering based on the name.
    ///
    /// Manifest source: `HappySpeech/Content/word_manifest.json`, surfaced
    /// through `LessonContentMap.asset(for:)`. The local legacy dict was
    /// removed in Task #69 (Diploma Step 9) — every word that used to live
    /// there is now in the manifest.
    static func imageSymbol(for word: String) -> String {
        let normalized = word.lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: ".,!?;:"))
        // Primary: shared LessonContentMap (manifest-backed).
        if let asset = LessonContentMap.asset(for: normalized) { return asset }
        // Try first token (in case word is "одна машина") against the manifest.
        if let firstToken = normalized.components(separatedBy: .whitespaces).first,
           let asset = LessonContentMap.asset(for: firstToken) {
            return asset
        }
        // SF Symbol fallback by first letter (acoustic group).
        let first = normalized.first
        switch first {
        case "р", "r": return "circle.grid.2x2"
        case "с", "s": return "sun.max"
        case "ш", "w": return "leaf"
        case "л", "l": return "moon"
        case "к", "k": return "key"
        case "з", "z": return "umbrella"
        case "ц", "c": return "flower"
        case "ж", "j": return "bolt"
        case "ч":      return "clock"
        case "щ":      return "bubbles.and.sparkles"
        case "г", "g": return "mountain.2"
        case "х", "h": return "house"
        default:       return "star"
        }
    }
}

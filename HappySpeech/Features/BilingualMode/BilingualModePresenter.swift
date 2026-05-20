import Foundation

// MARK: - BilingualModePresenter

@MainActor
final class BilingualModePresenter {

    weak var displayLogic: (any BilingualModeDisplayLogic)?

    init(displayLogic: any BilingualModeDisplayLogic) {
        self.displayLogic = displayLogic
    }

    // MARK: - Load

    func presentLoadVocabulary(response: BilingualModeModels.LoadVocabulary.Response) async {
        var grouped: [String: [BilingualWord]] = [:]
        for word in response.words {
            grouped[word.category, default: []].append(word)
        }
        let categories = BilingualVocabularyCorpus.categoriesInOrder.filter {
            grouped[$0]?.isEmpty == false
        }
        let viewModel = BilingualModeModels.LoadVocabulary.ViewModel(
            secondLanguage: response.secondLanguage,
            grouped: grouped,
            categoriesInOrder: categories,
            categoryTitles: BilingualVocabularyCorpus.categoryTitles,
            secondLanguageDisplayName: response.secondLanguage.displayName
        )
        await displayLogic?.displayLoadVocabulary(viewModel: viewModel)
    }

    // MARK: - StartPractice

    func presentStartPractice(response: BilingualModeModels.StartPractice.Response) async {
        let viewModel = BilingualModeModels.StartPractice.ViewModel(
            secondLanguage: response.secondLanguage,
            totalRounds: response.rounds.count,
            rounds: response.rounds
        )
        await displayLogic?.displayStartPractice(viewModel: viewModel)
    }

    // MARK: - SubmitAnswer

    func presentSubmitAnswer(response: BilingualModeModels.SubmitAnswer.Response) async {
        let viewModel = BilingualModeModels.SubmitAnswer.ViewModel(
            roundIndex: response.roundIndex,
            isCorrect: response.isCorrect,
            correctTranslation: response.correctTranslation
        )
        await displayLogic?.displaySubmitAnswer(viewModel: viewModel)
    }

    // MARK: - FinishPractice

    func presentFinishPractice(response: BilingualModeModels.FinishPractice.Response) async {
        let stars = BilingualPracticeGenerator.stars(
            correctCount: response.correctCount,
            totalRounds: response.totalRounds
        )
        let (title, body) = makeFeedback(
            stars: stars,
            correct: response.correctCount,
            total: response.totalRounds,
            language: response.secondLanguage
        )
        let viewModel = BilingualModeModels.FinishPractice.ViewModel(
            correctCount: response.correctCount,
            totalRounds: response.totalRounds,
            stars: stars,
            title: title,
            body: body,
            accessibilityLabel: makeAccessibilityLabel(
                stars: stars,
                correct: response.correctCount,
                total: response.totalRounds
            )
        )
        await displayLogic?.displayFinishPractice(viewModel: viewModel)
    }

    // MARK: - Helpers

    private func makeFeedback(
        stars: Int,
        correct: Int,
        total: Int,
        language: BilingualSecondLanguage
    ) -> (title: String, body: String) {
        let langName = language.displayName
        switch stars {
        case 3:
            return ("Отлично!",
                    "Ты ответил правильно \(correct) из \(total). Молодец — словарь \(langName) растёт!")
        case 2:
            return ("Хорошо получилось!",
                    "Правильных ответов: \(correct) из \(total). Чуть-чуть — и будет супер.")
        case 1:
            return ("Хороший старт!",
                    "Правильных: \(correct) из \(total). Послушай слова и попробуй ещё раз.")
        default:
            return ("Попробуем ещё раз!",
                    "Послушай, как звучат слова на втором языке, и попробуй снова.")
        }
    }

    private func makeAccessibilityLabel(stars: Int, correct: Int, total: Int) -> String {
        "Тренировка завершена: \(stars) из 3 звёзд. Правильных ответов \(correct) из \(total)."
    }
}

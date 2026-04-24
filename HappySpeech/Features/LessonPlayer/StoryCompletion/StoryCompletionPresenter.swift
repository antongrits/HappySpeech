import Foundation
import OSLog

// MARK: - StoryCompletionPresentationLogic

@MainActor
protocol StoryCompletionPresentationLogic: AnyObject {
    func presentLoadStory(_ response: StoryCompletionModels.LoadStory.Response)
    func presentChooseWord(_ response: StoryCompletionModels.ChooseWord.Response)
    func presentNextScene(_ response: StoryCompletionModels.NextScene.Response)
    func presentComplete(_ response: StoryCompletionModels.Complete.Response)
}

// MARK: - StoryCompletionPresenter
//
// Конвертирует Response → ViewModel и передаёт в `StoryCompletionDisplayLogic`.
// Вся бизнес-логика (каталог историй, проверка ответа, счёт) — в Interactor.
// Здесь — только форматирование строк, локализация и шкала звёзд.

@MainActor
final class StoryCompletionPresenter: StoryCompletionPresentationLogic {

    weak var display: (any StoryCompletionDisplayLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryCompletionPresenter")

    // MARK: - LoadStory

    func presentLoadStory(_ response: StoryCompletionModels.LoadStory.Response) {
        let scene = response.scene
        let progress = Self.progressFraction(
            sceneIndex: response.sceneIndex,
            totalScenes: response.totalScenes
        )
        // До выбора: заменяем "___" визуальным blank, чтобы было очевидно
        // место пропуска и при этом оно не совпадало с исходным текстом.
        let displayText = scene.storyText.replacingOccurrences(
            of: StoryPlaceholder.marker,
            with: StoryPlaceholder.blank
        )
        let vm = StoryCompletionModels.LoadStory.ViewModel(
            storyText: scene.storyText,
            displayText: displayText,
            choices: scene.choices,
            emoji: scene.emoji,
            sceneIndex: response.sceneIndex,
            totalScenes: response.totalScenes,
            progressFraction: progress,
            isReading: true
        )
        logger.info(
            "presentLoadStory scene=\(response.sceneIndex, privacy: .public)/\(response.totalScenes, privacy: .public) group=\(scene.soundGroup, privacy: .public)"
        )
        display?.displayLoadStory(vm)
    }

    // MARK: - ChooseWord

    func presentChooseWord(_ response: StoryCompletionModels.ChooseWord.Response) {
        // Состояния вариантов: правильный зелёный, неправильный красный,
        // если ребёнок ошибся — правильный дополнительно подсвечиваем золотом.
        var states: [ChoiceState] = Array(repeating: .idle, count: 3)
        if response.isCorrect {
            states[response.choiceIndex] = .correct
        } else {
            if response.choiceIndex >= 0 && response.choiceIndex < states.count {
                states[response.choiceIndex] = .wrong
            }
            if response.correctIndex >= 0 && response.correctIndex < states.count {
                states[response.correctIndex] = .revealed
            }
        }

        let feedback = response.isCorrect
            ? String(localized: "Правильно!")
            : String(localized: "Правильный ответ: \(response.correctWord)")

        let vm = StoryCompletionModels.ChooseWord.ViewModel(
            choiceStates: states,
            filledStoryText: response.filledStoryText,
            feedbackCorrect: response.isCorrect,
            feedbackMessage: feedback
        )
        logger.info(
            "presentChooseWord correct=\(response.isCorrect, privacy: .public) chosen=\(response.chosenWord, privacy: .public)"
        )
        display?.displayChooseWord(vm)
    }

    // MARK: - NextScene

    func presentNextScene(_ response: StoryCompletionModels.NextScene.Response) {
        let vm = StoryCompletionModels.NextScene.ViewModel(
            hasNextScene: response.hasNextScene,
            nextSceneIndex: response.nextSceneIndex
        )
        display?.displayNextScene(vm)
    }

    // MARK: - Complete

    func presentComplete(_ response: StoryCompletionModels.Complete.Response) {
        let stars = StoryCompletionScoring.stars(for: response.score)
        let pct = Int((response.score * 100).rounded())
        let scoreLabel = String(localized: "Результат: \(pct)%")

        let message: String
        switch stars {
        case 3: message = String(localized: "Превосходно! Все истории правильно.")
        case 2: message = String(localized: "Отличная работа!")
        case 1: message = String(localized: "Хорошо, но можно ещё лучше.")
        default: message = String(localized: "Попробуем ещё раз?")
        }

        logger.info(
            "presentComplete score=\(response.score, privacy: .public) stars=\(stars, privacy: .public) correct=\(response.correctCount, privacy: .public)/\(response.totalScenes, privacy: .public)"
        )

        let vm = StoryCompletionModels.Complete.ViewModel(
            scoreLabel: scoreLabel,
            starsEarned: stars,
            completionMessage: message,
            finalScore: response.score
        )
        display?.displayComplete(vm)
    }

    // MARK: - Helpers

    /// Прогресс = sceneIndex / totalScenes.
    /// До первой сцены — 0, после 5-й — 1.
    private static func progressFraction(sceneIndex: Int, totalScenes: Int) -> Double {
        guard totalScenes > 0 else { return 0 }
        return min(max(Double(sceneIndex) / Double(totalScenes), 0), 1)
    }
}

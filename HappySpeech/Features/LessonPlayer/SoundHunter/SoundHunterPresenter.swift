import Foundation

// MARK: - SoundHunterPresentationLogic

@MainActor
protocol SoundHunterPresentationLogic: AnyObject {
    func presentLoadScene(_ response: SoundHunterModels.LoadScene.Response)
    func presentTapItem(_ response: SoundHunterModels.TapItem.Response)
    func presentCompleteScene(_ response: SoundHunterModels.CompleteScene.Response)
    func presentNextScene(_ response: SoundHunterModels.NextScene.Response)
}

// MARK: - SoundHunterPresenter
//
// Готовит локализованные строки и прогресс для наблюдаемого display-стора.

@MainActor
final class SoundHunterPresenter: SoundHunterPresentationLogic {

    weak var viewModel: (any SoundHunterDisplayLogic)?

    // MARK: - LoadScene

    func presentLoadScene(_ response: SoundHunterModels.LoadScene.Response) {
        let progress = sceneProgress(
            sceneIndex: response.sceneIndex,
            totalScenes: response.totalScenes,
            correctCount: 0,
            totalCorrectNeeded: response.totalCorrectNeeded
        )
        let hint = hintText(for: response.targetSound)
        let vm = SoundHunterModels.LoadScene.ViewModel(
            items: response.items,
            targetSound: response.targetSound,
            targetSoundGroup: response.targetSoundGroup,
            sceneIndex: response.sceneIndex,
            totalScenes: response.totalScenes,
            totalCorrectNeeded: response.totalCorrectNeeded,
            progressFraction: progress,
            hintText: hint
        )
        viewModel?.displayLoadScene(vm)
    }

    // MARK: - TapItem

    func presentTapItem(_ response: SoundHunterModels.TapItem.Response) {
        let progress: Double = response.totalCorrectNeeded > 0
            ? Double(response.correctCount) / Double(response.totalCorrectNeeded)
            : 0
        let shakeId: UUID? = response.newState == .wrong ? response.itemId : nil
        let vm = SoundHunterModels.TapItem.ViewModel(
            itemId: response.itemId,
            newState: response.newState,
            correctCount: response.correctCount,
            totalCorrectNeeded: response.totalCorrectNeeded,
            progressFraction: progress,
            shakeItemId: shakeId,
            isSceneComplete: response.isSceneComplete
        )
        viewModel?.displayTapItem(vm)
    }

    // MARK: - CompleteScene

    func presentCompleteScene(_ response: SoundHunterModels.CompleteScene.Response) {
        let percentage = Int((response.totalScore * 100).rounded())
        let scoreLabel = String(localized: "Результат: \(percentage)%")
        let message = completionMessage(
            stars: response.starsEarned
        )
        let vm = SoundHunterModels.CompleteScene.ViewModel(
            totalScore: response.totalScore,
            starsEarned: response.starsEarned,
            scoreLabel: scoreLabel,
            completionMessage: message,
            isFinalScene: response.isFinalScene
        )
        viewModel?.displayCompleteScene(vm)
    }

    // MARK: - NextScene

    func presentNextScene(_ response: SoundHunterModels.NextScene.Response) {
        let progress = sceneProgress(
            sceneIndex: response.nextSceneIndex,
            totalScenes: 3,
            correctCount: 0,
            totalCorrectNeeded: response.totalCorrectNeeded
        )
        let hint = hintText(for: response.targetSound)
        let vm = SoundHunterModels.NextScene.ViewModel(
            nextSceneIndex: response.nextSceneIndex,
            items: response.items,
            targetSound: response.targetSound,
            totalCorrectNeeded: response.totalCorrectNeeded,
            progressFraction: progress,
            hintText: hint
        )
        viewModel?.displayNextScene(vm)
    }

    // MARK: - Helpers

    /// Прогресс: ((завершённые_сцены + доля_текущей) / всего_сцен).
    private func sceneProgress(
        sceneIndex: Int,
        totalScenes: Int,
        correctCount: Int,
        totalCorrectNeeded: Int
    ) -> Double {
        guard totalScenes > 0 else { return 0 }
        let currentFraction: Double = totalCorrectNeeded > 0
            ? Double(correctCount) / Double(totalCorrectNeeded)
            : 0
        return (Double(sceneIndex) + currentFraction) / Double(totalScenes)
    }

    private func hintText(for targetSound: String) -> String {
        String(localized: "Найди слова со звуком «\(targetSound)»")
    }

    private func completionMessage(stars: Int) -> String {
        switch stars {
        case 3: return String(localized: "Превосходно! Ты нашёл все слова.")
        case 2: return String(localized: "Отличная работа!")
        case 1: return String(localized: "Хорошо, но можно ещё лучше.")
        default: return String(localized: "Попробуй ещё раз.")
        }
    }
}

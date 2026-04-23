import Foundation

// MARK: - BreathingPresentationLogic

@MainActor
protocol BreathingPresentationLogic: AnyObject {
    func presentLoadSession(_ response: BreathingModels.LoadSession.Response)
    func presentSubmitAttempt(_ response: BreathingModels.SubmitAttempt.Response)
    func presentUpdateSignal(_ response: BreathingModels.UpdateSignal.Response)
    func presentFinish(_ response: BreathingModels.Finish.Response)
}

// MARK: - BreathingPresenter
//
// Turns Interactor responses into Russian UI strings and view-ready numbers.
// No business logic lives here — the Presenter is essentially a renderer.

@MainActor
final class BreathingPresenter: BreathingPresentationLogic {

    weak var viewModel: (any BreathingDisplayLogic)?

    // MARK: - loadSession

    func presentLoadSession(_ response: BreathingModels.LoadSession.Response) {
        let title: String = {
            switch response.scene {
            case .dandelion: return String(localized: "Одуванчик")
            case .candle:    return String(localized: "Задуй свечу")
            case .balloon:   return String(localized: "Надуй шарик")
            }
        }()
        let instruction: String = {
            switch response.scene {
            case .dandelion: return String(localized: "Подуй на одуванчик, чтобы лепестки разлетелись!")
            case .candle:    return String(localized: "Сделай глубокий вдох и задуй свечу.")
            case .balloon:   return String(localized: "Дуй ровно, чтобы шарик надулся до конца.")
            }
        }()
        let vm = BreathingModels.LoadSession.ViewModel(
            displayItems: response.items,
            titleText: title,
            instructionText: instruction,
            scene: response.scene
        )
        viewModel?.displayLoadSession(vm)
    }

    // MARK: - submitAttempt

    func presentSubmitAttempt(_ response: BreathingModels.SubmitAttempt.Response) {
        let feedback = response.isCorrect
            ? String(localized: "Отлично!")
            : String(localized: "Попробуй ещё раз")
        let vm = BreathingModels.SubmitAttempt.ViewModel(
            feedbackText: feedback,
            isCorrect: response.isCorrect
        )
        viewModel?.displaySubmitAttempt(vm)
    }

    // MARK: - updateSignal

    func presentUpdateSignal(_ response: BreathingModels.UpdateSignal.Response) {
        let title = Self.title(for: response.state)
        let subtitle = Self.subtitle(for: response.state)
        let mood = Self.mood(for: response.state)
        let tutorialStep = Self.tutorialStep(for: response.state)

        let showWarmUp: Bool = {
            if case .warmUp = response.state { return true } else { return false }
        }()
        let showTutorial: Bool = {
            if case .tutorial = response.state { return true } else { return false }
        }()
        let isFinished: Bool = {
            if case .summary = response.state { return true } else { return false }
        }()

        let failureMessage: String? = {
            guard case .failure(let reason) = response.state else { return nil }
            return Self.failureMessage(for: reason)
        }()

        let vm = BreathingModels.UpdateSignal.ViewModel(
            title: title,
            subtitle: subtitle,
            amplitude: response.amplitude,
            objectScale: CGFloat(response.objectScale),
            petalsRemaining: response.petalsRemaining,
            progress: Double(response.progress),
            mascotMood: mood,
            showWarmUpOverlay: showWarmUp,
            showTutorialOverlay: showTutorial,
            tutorialStep: tutorialStep,
            isFinished: isFinished,
            failureMessage: failureMessage,
            finalScore: nil
        )
        viewModel?.displayUpdateSignal(vm)
    }

    // MARK: - finish

    func presentFinish(_ response: BreathingModels.Finish.Response) {
        let result = response.result
        let title: String
        let subtitle: String
        if result.didSucceed {
            title = String(localized: "Отлично!")
            switch result.stars {
            case 3: subtitle = String(localized: "Чистый и долгий выдох!")
            case 2: subtitle = String(localized: "Здорово, выдох становится длиннее!")
            default: subtitle = String(localized: "Получилось!")
            }
        } else {
            title = String(localized: "Давай ещё раз")
            subtitle = String(localized: "Сделай глубокий вдох и подуй ровно.")
        }
        let vm = BreathingModels.Finish.ViewModel(
            title: title,
            subtitle: subtitle,
            finalScore: result.score,
            stars: result.stars
        )
        viewModel?.displayFinish(vm)
    }

    // MARK: - Copy helpers

    private static func title(for state: BreathingGameState) -> String {
        switch state {
        case .idle, .tutorial:
            return String(localized: "Подуй на одуванчик!")
        case .warmUp:
            return String(localized: "Тише на секунду…")
        case .playing:
            return String(localized: "Дуй!")
        case .success:
            return String(localized: "Отлично!")
        case .failure:
            return String(localized: "Давай ещё раз")
        case .summary(let result):
            return result.didSucceed
                ? String(localized: "Отлично!")
                : String(localized: "Давай ещё раз")
        }
    }

    private static func subtitle(for state: BreathingGameState) -> String {
        switch state {
        case .idle, .tutorial:
            return String(localized: "Глубокий вдох носом")
        case .warmUp:
            return String(localized: "Калибруем микрофон")
        case .playing:
            return String(localized: "Держи ровный выдох")
        case .success:
            return String(localized: "Хороший длинный выдох!")
        case .failure(let reason):
            return Self.failureMessage(for: reason)
        case .summary:
            return ""
        }
    }

    private static func mood(for state: BreathingGameState) -> MascotMoodVM {
        switch state {
        case .idle, .tutorial: return .thinking
        case .warmUp:          return .idle
        case .playing:         return .encouraging
        case .success:         return .celebrating
        case .failure:         return .sad
        case .summary(let r):  return r.didSucceed ? .celebrating : .sad
        }
    }

    private static func tutorialStep(for state: BreathingGameState) -> Int {
        if case .tutorial(let step) = state { return step }
        return 0
    }

    static func failureMessage(for reason: BreathingFailureReason) -> String {
        switch reason {
        case .tooQuiet:       return String(localized: "Подуй посильнее.")
        case .tooShort:       return String(localized: "Выдох стал слишком коротким.")
        case .noMicrophone:   return String(localized: "Нужен доступ к микрофону.")
        case .interrupted:    return String(localized: "Нас отвлёк звонок. Попробуем снова?")
        }
    }
}

import Foundation

// MARK: - ObjectHuntViewDisplay

/// Observable ViewModel — читается View через @State.
@Observable
@MainActor
final class ObjectHuntViewDisplay {
    var phase: ObjectHuntModels.GamePhase = .loading
    var items: [SceneItem] = []
    var targetSoundLabel: String = ""
    var sceneName: String = ""
    var sceneBackground: String = ""
    var roundBadge: String = ""
    var promptText: String = ""
    var targetCount: Int = 0
    var correctCount: Int = 0
    var streakCount: Int = 0
    var scoreLabel: String = ""
    var timerLabel: String = "1:00"
    var isTimerWarning: Bool = false
    var sceneResultText: String = ""
    var sceneTimeText: String = ""
    var sceneStreakBonusText: String = ""
    var starsEarned: Int = 0
    var accuracyLabel: String = ""
    var finalScoreLabel: String = ""
    var summaryText: String = ""
    var hintsRemaining: Int = 2
    var isHintAvailable: Bool = true
    var lastScore: Float = 0
}

// MARK: - ObjectHuntPresenter

@MainActor
final class ObjectHuntPresenter: ObjectHuntPresentationLogic {

    // MARK: - Output

    weak var display: (any ObjectHuntDisplayLogic)?

    // MARK: - presentLoadScene

    func presentLoadScene(_ response: ObjectHuntModels.LoadScene.Response) {
        let badge = String(
            localized: "object_hunt.round_badge \(response.sceneIndex + 1) \(response.totalScenes)"
        )
        let prompt = String(
            localized: "object_hunt.find_sound \(response.targetSound)"
        )
        let vm = ObjectHuntModels.LoadScene.ViewModel(
            items: response.items,
            targetSoundLabel: response.targetSound.uppercased(),
            sceneName: response.scene.name,
            sceneBackground: response.scene.systemBackground,
            roundBadge: badge,
            promptText: prompt,
            targetCount: response.targetCount,
            timeLimitSec: response.timeLimitSec
        )
        display?.displayLoadScene(vm)
    }

    // MARK: - presentTapObject

    func presentTapObject(_ response: ObjectHuntModels.TapObject.Response) {
        let scoreLabel: String
        if response.isCorrect {
            if response.streakCount >= 3 {
                scoreLabel = String(localized: "object_hunt.score_streak \(response.streakCount)")
            } else {
                scoreLabel = String(localized: "object_hunt.score_correct")
            }
        } else {
            scoreLabel = ""
        }

        let vm = ObjectHuntModels.TapObject.ViewModel(
            itemId: response.itemId,
            newState: response.newState,
            isCorrect: response.isCorrect,
            word: response.word,
            correctCount: response.correctCount,
            targetCount: response.targetCount,
            streakCount: response.streakCount,
            scoreLabel: scoreLabel,
            isSceneComplete: response.isSceneComplete
        )
        display?.displayTapObject(vm)
    }

    // MARK: - presentUseHint

    func presentUseHint(_ response: ObjectHuntModels.UseHint.Response) {
        let vm = ObjectHuntModels.UseHint.ViewModel(
            hintedItemId: response.hintedItemId,
            hintsRemaining: response.hintsRemaining,
            hintLevel: response.hintLevel,
            isHintAvailable: response.hintsRemaining > 0
        )
        display?.displayUseHint(vm)
    }

    // MARK: - presentTimerTick

    func presentTimerTick(_ response: ObjectHuntModels.TimerTick.Response) {
        let minutes = response.secondsRemaining / 60
        let seconds = response.secondsRemaining % 60
        let label = String(format: "%d:%02d", minutes, seconds)
        let vm = ObjectHuntModels.TimerTick.ViewModel(
            timerLabel: label,
            isExpired: response.isExpired,
            isWarning: response.secondsRemaining < 15
        )
        display?.displayTimerTick(vm)
    }

    // MARK: - presentCompleteScene

    func presentCompleteScene(_ response: ObjectHuntModels.CompleteScene.Response) {
        let summary = String(
            localized: "object_hunt.found_count \(response.foundCount) \(response.targetCount)"
        )
        let timeText = String(
            localized: "object_hunt.time_used \(response.timeUsedSec)"
        )
        let streakBonusText: String = response.streakBonus > 0
            ? String(localized: "object_hunt.streak_bonus \(response.streakBonus)")
            : ""

        let vm = ObjectHuntModels.CompleteScene.ViewModel(
            sceneIndex: response.sceneIndex,
            summaryText: summary,
            timeText: timeText,
            streakBonusText: streakBonusText,
            isLastScene: response.isLastScene
        )
        display?.displayCompleteScene(vm)
    }

    // MARK: - presentCompleteGame

    func presentCompleteGame(_ response: ObjectHuntModels.CompleteGame.Response) {
        let accuracy = Int(response.accuracy * 100)
        let accuracyLabel = String(localized: "object_hunt.accuracy_label \(accuracy)")
        let scoreLabel = String(localized: "object_hunt.total_score \(response.totalScore)")
        let summaryText: String
        switch response.starsEarned {
        case 3:  summaryText = String(localized: "object_hunt.summary.excellent")
        case 2:  summaryText = String(localized: "object_hunt.summary.good")
        default: summaryText = String(localized: "object_hunt.summary.ok")
        }
        let vm = ObjectHuntModels.CompleteGame.ViewModel(
            starsEarned: response.starsEarned,
            scoreLabel: scoreLabel,
            accuracyLabel: accuracyLabel,
            summaryText: summaryText
        )
        display?.displayCompleteGame(vm)
    }
}

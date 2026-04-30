import Foundation

// MARK: - ObjectHuntViewDisplay

/// Observable ViewModel — читается View через @State.
@Observable
@MainActor
final class ObjectHuntViewDisplay {
    var phase: ObjectHuntModels.GamePhase = .loading
    var promptText: String = ""
    var targetSoundLabel: String = ""
    var roundBadge: String = ""
    var matchedLabel: String?
    var celebrationText: String?
    var completionMessage: String = ""
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var summaryText: String = ""
    var lastScore: Float = 0
    var lastMatchedObject: DetectedObject?
    var currentRoundIndex: Int = 0
}

// MARK: - ObjectHuntPresenter

@MainActor
final class ObjectHuntPresenter: ObjectHuntPresentationLogic {

    // MARK: - Output

    weak var display: (any ObjectHuntDisplayLogic)?

    // MARK: - presentLoadRound

    func presentLoadRound(_ response: ObjectHuntModels.LoadRound.Response) {
        let badge = String(
            localized: "object_hunt.round_badge \(response.roundIndex + 1) \(response.totalRounds)"
        )
        let vm = ObjectHuntModels.LoadRound.ViewModel(
            targetSoundLabel: response.targetSound.uppercased(),
            promptText: response.promptText,
            roundBadge: badge
        )
        display?.displayLoadRound(vm)
    }

    // MARK: - presentFrameAnalyzed

    func presentFrameAnalyzed(_ response: ObjectHuntModels.FrameAnalyzed.Response) {
        let vm: ObjectHuntModels.FrameAnalyzed.ViewModel

        if let obj = response.matchedObject {
            let soundUp = obj.sounds.first?.uppercased() ?? ""
            let celebration = String(
                localized: "object_hunt.found \(obj.russianLabel) \(soundUp)"
            )
            vm = ObjectHuntModels.FrameAnalyzed.ViewModel(
                matchedLabel: obj.russianLabel,
                celebrationText: celebration,
                isMatch: true,
                matchedObject: obj
            )
        } else {
            vm = ObjectHuntModels.FrameAnalyzed.ViewModel(
                matchedLabel: nil,
                celebrationText: nil,
                isMatch: false,
                matchedObject: nil
            )
        }
        display?.displayFrameAnalyzed(vm)
    }

    // MARK: - presentCompleteRound

    func presentCompleteRound(_ response: ObjectHuntModels.CompleteRound.Response) {
        let vm = ObjectHuntModels.CompleteRound.ViewModel(
            celebrationMessage: response.celebrationMessage,
            shouldAdvance: !response.isLastRound
        )
        display?.displayCompleteRound(vm)
    }

    // MARK: - presentCompleteGame

    func presentCompleteGame(_ response: ObjectHuntModels.CompleteGame.Response) {
        let scorePercent = Int(response.score * 100)
        let scoreLabel = String(localized: "object_hunt.score_label \(scorePercent)")
        let vm = ObjectHuntModels.CompleteGame.ViewModel(
            starsEarned: response.starsEarned,
            scoreLabel: scoreLabel,
            summaryText: response.summaryText
        )
        display?.displayCompleteGame(vm)
    }
}

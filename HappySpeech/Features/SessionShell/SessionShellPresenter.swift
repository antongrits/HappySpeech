import Foundation

// MARK: - SessionShellPresentationLogic

@MainActor
protocol SessionShellPresentationLogic: AnyObject {
    func presentStartSession(_ response: SessionShellModels.StartSession.Response) async
    func presentCompleteActivity(_ response: SessionShellModels.CompleteActivity.Response) async
    func presentPauseSession(_ response: SessionShellModels.PauseSession.Response)
}

// MARK: - SessionShellPresenter

@MainActor
final class SessionShellPresenter: SessionShellPresentationLogic {

    weak var display: (any SessionShellDisplayLogic)?

    func presentStartSession(_ response: SessionShellModels.StartSession.Response) async {
        let title = String(localized: "Занятие началось!")
        let vm = SessionShellModels.StartSession.ViewModel(
            activities: response.activities,
            totalSteps: response.totalSteps,
            progressTitle: title
        )
        display?.displayStartSession(vm)
    }

    func presentCompleteActivity(_ response: SessionShellModels.CompleteActivity.Response) async {
        let rewardVM: RewardViewModel? = response.earnedReward.map { _ in
            RewardViewModel(
                emoji: "⭐️",
                title: String(localized: "Молодец!"),
                subtitle: String(localized: "Ты справился!")
            )
        }
        let vm = SessionShellModels.CompleteActivity.ViewModel(
            shouldAdvance: !response.isSessionComplete,
            shouldShowFatigueAlert: response.fatigueDetected,
            shouldShowReward: rewardVM != nil,
            reward: rewardVM
        )
        display?.displayCompleteActivity(vm)
    }

    func presentPauseSession(_ response: SessionShellModels.PauseSession.Response) {
        let percentage = response.currentProgress
        let vm = SessionShellModels.PauseSession.ViewModel(
            progressPercentage: percentage,
            timeSpentFormatted: String(localized: "Пауза")
        )
        display?.displayPauseSession(vm)
    }
}

import Foundation

// MARK: - SessionShellPresentationLogic

@MainActor
protocol SessionShellPresentationLogic: AnyObject {
    func presentStartSession(_ response: SessionShellModels.StartSession.Response) async
    func presentCompleteActivity(_ response: SessionShellModels.CompleteActivity.Response) async
    func presentPauseSession(_ response: SessionShellModels.PauseSession.Response)
}

// MARK: - SessionShellPresenter

/// Maps Interactor `Response`s into UI-shaped `ViewModel`s.
///
/// Responsibilities:
///   * choose Lyalya's `MascotState` for the current shell phase;
///   * format pause time / motivational phrases (rotating pool — 5 messages);
///   * map `ActivityFeedback` → `FeedbackState` for the overlay;
///   * compose reward emoji / title / subtitle.
@MainActor
final class SessionShellPresenter: SessionShellPresentationLogic {

    weak var display: (any SessionShellDisplayLogic)?

    // MARK: - Pools

    /// Rotating pool of motivational phrases shown on the pause sheet.
    /// View seeds an index by `Date().timeIntervalSinceReferenceDate.truncatingRemainder`
    /// so the message stays stable while the sheet is open.
    private static let motivationalPhrases: [String] = [
        String(localized: "session.pause.motivational.1"),
        String(localized: "session.pause.motivational.2"),
        String(localized: "session.pause.motivational.3"),
        String(localized: "session.pause.motivational.4"),
        String(localized: "session.pause.motivational.5")
    ]

    // MARK: - StartSession

    func presentStartSession(_ response: SessionShellModels.StartSession.Response) async {
        let title = String(localized: "session.start.title")
        let vm = SessionShellModels.StartSession.ViewModel(
            activities: response.activities,
            totalSteps: response.totalSteps,
            progressTitle: title,
            sessionStartTime: response.sessionStartTime
        )
        display?.displayStartSession(vm)
    }

    // MARK: - CompleteActivity

    func presentCompleteActivity(_ response: SessionShellModels.CompleteActivity.Response) async {
        let rewardVM: RewardViewModel? = response.earnedReward.map { _ in
            RewardViewModel(
                emoji: "⭐️",
                title: String(localized: "session.reward.title"),
                subtitle: String(localized: "session.reward.subtitle")
            )
        }
        let feedbackState: SessionShellModels.FeedbackState = {
            switch response.feedback {
            case .correct:   return .correct
            case .incorrect: return .incorrect
            }
        }()
        let mascotState: SessionShellModels.MascotState = {
            if response.fatigueDetected { return .thinking }
            switch response.feedback {
            case .correct:   return response.earnedReward != nil ? .celebrating : .encouraging
            case .incorrect: return .thinking
            }
        }()

        let vm = SessionShellModels.CompleteActivity.ViewModel(
            shouldAdvance: !response.isSessionComplete,
            shouldShowFatigueAlert: response.fatigueDetected,
            shouldShowReward: rewardVM != nil,
            reward: rewardVM,
            feedbackState: feedbackState,
            fatigueHearts: response.fatigueHearts,
            mascotState: mascotState
        )
        display?.displayCompleteActivity(vm)
    }

    // MARK: - PauseSession

    func presentPauseSession(_ response: SessionShellModels.PauseSession.Response) {
        let percentage = response.currentProgress
        let phrase = Self.pickMotivationalPhrase(seed: response.activeSeconds)
        let vm = SessionShellModels.PauseSession.ViewModel(
            progressPercentage: percentage,
            timeSpentFormatted: Self.formatActiveTime(response.activeSeconds),
            motivationalPhrase: phrase
        )
        display?.displayPauseSession(vm)
    }

    // MARK: - Helpers

    private static func pickMotivationalPhrase(seed: TimeInterval) -> String {
        guard !motivationalPhrases.isEmpty else {
            return String(localized: "session.pause.motivational")
        }
        let bucket = Int(seed.truncatingRemainder(dividingBy: Double(motivationalPhrases.count)).magnitude)
        let safeIndex = max(0, min(bucket, motivationalPhrases.count - 1))
        return motivationalPhrases[safeIndex]
    }

    private static func formatActiveTime(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds.rounded()))
        let minutes = total / 60
        let secs = total % 60
        return String(format: "%02d:%02d", minutes, secs)
    }
}

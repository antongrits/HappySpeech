import Foundation
import OSLog

// MARK: - SharePlayPresentationLogic

/// Протокол — Interactor → Presenter.
@MainActor
protocol SharePlayPresentationLogic: AnyObject {
    func presentLoad(_ response: SharePlay.Load.Response)
    func presentStartSession(_ response: SharePlay.StartSession.Response)
    func presentSessionStateChange(_ response: SharePlay.SessionStateChange.Response)
    func presentRemoteMessage(_ response: SharePlay.RemoteMessage.Response)
    func presentEndSession(_ response: SharePlay.EndSession.Response)
}

// MARK: - SharePlayPresenter

/// Преобразует доменные Response → ViewModel для отображения в SharePlayView.

@MainActor
final class SharePlayPresenter: SharePlayPresentationLogic {

    // MARK: - VIP wiring

    weak var viewModel: SharePlayViewModel?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SharePlayPresenter"
    )

    // MARK: - SharePlayPresentationLogic

    func presentLoad(_ response: SharePlay.Load.Response) {
        let vm = SharePlay.Load.ViewModel(
            childName: response.childName,
            availableLessons: response.availableLessons,
            startButtonLabel: String(localized: "shareplay.startButton"),
            biometricHintVisible: response.isBiometricAvailable
        )
        viewModel?.applyLoad(vm)
    }

    func presentStartSession(_ response: SharePlay.StartSession.Response) {
        let vm: SharePlay.StartSession.ViewModel
        switch response.outcome {
        case .activating:
            vm = SharePlay.StartSession.ViewModel(
                alertMessage: nil,
                showFallbackHint: false
            )
        case .notAvailable:
            vm = SharePlay.StartSession.ViewModel(
                alertMessage: nil,
                showFallbackHint: true
            )
        case .authFailed:
            vm = SharePlay.StartSession.ViewModel(
                alertMessage: String(localized: "shareplay.error.parentAuthRequired"),
                showFallbackHint: false
            )
        case .error(let message):
            vm = SharePlay.StartSession.ViewModel(
                alertMessage: message,
                showFallbackHint: false
            )
        }
        viewModel?.applyStartSession(vm)
    }

    func presentSessionStateChange(_ response: SharePlay.SessionStateChange.Response) {
        let countLabel: String
        switch response.participantCount {
        case 0:
            countLabel = String(localized: "shareplay.participants.none")
        case 1:
            countLabel = String(localized: "shareplay.participants.one")
        default:
            countLabel = String(
                format: String(localized: "shareplay.participants.many"),
                response.participantCount
            )
        }

        let vm = SharePlay.SessionStateChange.ViewModel(
            isActive: response.isActive,
            participantCountLabel: countLabel,
            endButtonVisible: response.isActive
        )
        viewModel?.applySessionStateChange(vm)
    }

    func presentRemoteMessage(_ response: SharePlay.RemoteMessage.Response) {
        var remoteScore: Double?
        var remoteChildLabel: String?
        var celebrationVisible = false
        var sessionCompleteVisible = false

        switch response.message.kind {
        case .roundComplete(_, let score):
            remoteScore = score
            remoteChildLabel = String(
                format: String(localized: "shareplay.remote.scored"),
                Int(score * 100)
            )
        case .lyalyaCelebration:
            celebrationVisible = true
        case .sessionComplete(let totalScore):
            remoteScore = totalScore
            sessionCompleteVisible = true
        case .participantReady:
            remoteChildLabel = String(localized: "shareplay.remote.ready")
        default:
            break
        }

        let vm = SharePlay.RemoteMessage.ViewModel(
            remoteScore: remoteScore,
            remoteChildLabel: remoteChildLabel,
            celebrationVisible: celebrationVisible,
            sessionCompleteVisible: sessionCompleteVisible
        )
        viewModel?.applyRemoteMessage(vm)
    }

    func presentEndSession(_ response: SharePlay.EndSession.Response) {
        viewModel?.applyEndSession(SharePlay.EndSession.ViewModel())
    }
}

// MARK: - SharePlayViewModel

@Observable
@MainActor
final class SharePlayViewModel {

    // MARK: - Loaded state

    var childName: String = ""
    var availableLessons: [SharePlayLessonItem] = []
    var startButtonLabel: String = ""
    var biometricHintVisible: Bool = false

    // MARK: - Session state

    var isSessionActive: Bool = false
    var participantCountLabel: String = ""
    var endButtonVisible: Bool = false

    // MARK: - Alert / hint

    var alertMessage: String?
    var showAlert: Bool = false
    var showFallbackHint: Bool = false

    // MARK: - Remote state

    var remoteScore: Double?
    var remoteChildLabel: String?
    var celebrationVisible: Bool = false
    var sessionCompleteVisible: Bool = false

    // MARK: - Apply

    func applyLoad(_ vm: SharePlay.Load.ViewModel) {
        childName = vm.childName
        availableLessons = vm.availableLessons
        startButtonLabel = vm.startButtonLabel
        biometricHintVisible = vm.biometricHintVisible
    }

    func applyStartSession(_ vm: SharePlay.StartSession.ViewModel) {
        if let msg = vm.alertMessage {
            alertMessage = msg
            showAlert = true
        }
        showFallbackHint = vm.showFallbackHint
    }

    func applySessionStateChange(_ vm: SharePlay.SessionStateChange.ViewModel) {
        isSessionActive = vm.isActive
        participantCountLabel = vm.participantCountLabel
        endButtonVisible = vm.endButtonVisible
    }

    func applyRemoteMessage(_ vm: SharePlay.RemoteMessage.ViewModel) {
        remoteScore = vm.remoteScore
        remoteChildLabel = vm.remoteChildLabel
        celebrationVisible = vm.celebrationVisible
        sessionCompleteVisible = vm.sessionCompleteVisible
    }

    func applyEndSession(_ vm: SharePlay.EndSession.ViewModel) {
        isSessionActive = false
        endButtonVisible = false
        participantCountLabel = ""
        remoteScore = nil
        remoteChildLabel = nil
    }
}

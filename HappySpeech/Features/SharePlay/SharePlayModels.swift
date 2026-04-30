import Foundation

// MARK: - SharePlayModels
//
// VIP envelope types для модуля «Совместный урок» (SharePlay / GroupActivities).
// Контур: parent (родитель инициирует) + kid (наблюдает прогресс друг друга).
// COPPA: нет PII детей в SyncMessage — только игровое состояние.

enum SharePlay {

    // MARK: - Load

    enum Load {
        struct Request {
            /// Идентификатор ребёнка на этом устройстве.
            var childId: String
        }
        struct Response {
            var childName: String
            var availableLessons: [SharePlayLessonItem]
            var isBiometricAvailable: Bool
        }
        struct ViewModel {
            var childName: String
            var availableLessons: [SharePlayLessonItem]
            var startButtonLabel: String
            var biometricHintVisible: Bool
        }
    }

    // MARK: - StartSession

    enum StartSession {
        struct Request {
            var lesson: SharePlayLessonItem
        }
        struct Response {
            enum Outcome {
                case activating
                case notAvailable   // нет FaceTime-звонка (ожидаемо на симуляторе)
                case authFailed
                case error(String)
            }
            var outcome: Outcome
        }
        struct ViewModel {
            var alertMessage: String?
            var showFallbackHint: Bool
        }
    }

    // MARK: - SessionStateChange

    enum SessionStateChange {
        struct Response {
            var isActive: Bool
            var participantCount: Int
        }
        struct ViewModel {
            var isActive: Bool
            var participantCountLabel: String
            var endButtonVisible: Bool
        }
    }

    // MARK: - RemoteMessage

    enum RemoteMessage {
        struct Response {
            var message: SyncMessage
        }
        struct ViewModel {
            var remoteScore: Double?
            var remoteChildLabel: String?
            var celebrationVisible: Bool
            var sessionCompleteVisible: Bool
        }
    }

    // MARK: - EndSession

    enum EndSession {
        struct Request {}
        struct Response {}
        struct ViewModel {}
    }
}

// MARK: - SharePlayLessonItem

struct SharePlayLessonItem: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let soundId: String
    let templateKind: String
}

// MARK: - SharePlayError

enum SharePlayError: LocalizedError, Sendable {
    case parentAuthRequired
    case notActivated
    case sessionUnavailable
    case messengerUnavailable

    var errorDescription: String? {
        switch self {
        case .parentAuthRequired:
            return String(localized: "shareplay.error.parentAuthRequired")
        case .notActivated:
            return String(localized: "shareplay.error.notActivated")
        case .sessionUnavailable:
            return String(localized: "shareplay.error.sessionUnavailable")
        case .messengerUnavailable:
            return String(localized: "shareplay.error.messengerUnavailable")
        }
    }
}

// MARK: - SharePlayDisplayLogic

/// Протокол отображения — Presenter → View.
@MainActor
protocol SharePlayDisplayLogic: AnyObject {
    func displayLoad(_ viewModel: SharePlay.Load.ViewModel)
    func displayStartSession(_ viewModel: SharePlay.StartSession.ViewModel)
    func displaySessionStateChange(_ viewModel: SharePlay.SessionStateChange.ViewModel)
    func displayRemoteMessage(_ viewModel: SharePlay.RemoteMessage.ViewModel)
    func displayEndSession(_ viewModel: SharePlay.EndSession.ViewModel)
}

// MARK: - SharePlayBusinessLogic

/// Протокол бизнес-логики — View → Interactor.
protocol SharePlayBusinessLogic: AnyObject {
    func load(_ request: SharePlay.Load.Request) async
    func startSession(_ request: SharePlay.StartSession.Request) async
    func sendRoundComplete(roundIndex: Int, score: Double) async
    func sendAnswer(roundIndex: Int, answer: String, isCorrect: Bool) async
    func sendCelebration(intensity: String) async
    func endSession(_ request: SharePlay.EndSession.Request) async
}

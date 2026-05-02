import Foundation

// MARK: - ARActivity VIP Models
//
// ARActivity — диспетчер AR-игр внутри сессии. Получает `SessionActivity`
// из SessionShell, определяет capability устройства, проверяет разрешения,
// строит selection screen с 7 поддерживаемыми AR-играми, подсвечивает
// рекомендованную игру через AdaptivePlannerService, запускает нужный
// AR scene. По завершении записывает ARActivitySession в Realm и
// возвращает финальный score (0.0–1.0) родителю через `onComplete`.

// MARK: - ARGameKind

/// 7 поддерживаемых AR-игр.
enum ARGameKind: String, CaseIterable, Sendable, Equatable {
    case arMirror       = "ARMirror"
    case butterflyCatch = "ButterflyCatch"
    case breathingAR    = "BreathingAR"
    case mimicLyalya    = "MimicLyalya"
    case holdThePose    = "HoldThePose"
    case poseSequence   = "PoseSequence"
    case soundAndFace   = "SoundAndFace"

    var localizedName: String {
        switch self {
        case .arMirror:       return String(localized: "Артикуляционное зеркало")
        case .butterflyCatch: return String(localized: "Поймай бабочку")
        case .breathingAR:    return String(localized: "Дыхательная AR")
        case .mimicLyalya:    return String(localized: "Повтори за Лялей")
        case .holdThePose:    return String(localized: "Удержи позу")
        case .poseSequence:   return String(localized: "Цепочка поз")
        case .soundAndFace:   return String(localized: "Звук и лицо")
        }
    }

    var localizedDescription: String {
        switch self {
        case .arMirror:
            return String(localized: "Повторяй движения губ — зеркало покажет правильную артикуляцию")
        case .butterflyCatch:
            return String(localized: "Дуй через камеру и лови волшебных бабочек")
        case .breathingAR:
            return String(localized: "Контролируй дыхание — шарик растёт от правильного выдоха")
        case .mimicLyalya:
            return String(localized: "Ляля показывает — ты повторяй! Кто лучше?")
        case .holdThePose:
            return String(localized: "Удержи артикуляционную позу как можно дольше")
        case .poseSequence:
            return String(localized: "Выполни цепочку поз по картинке")
        case .soundAndFace:
            return String(localized: "Произноси звук и следи за движением лица в камере")
        }
    }

    var iconSystemName: String {
        switch self {
        case .arMirror:       return "camera.fill"
        case .butterflyCatch: return "wind"
        case .breathingAR:    return "lungs.fill"
        case .mimicLyalya:    return "face.smiling"
        case .holdThePose:    return "figure.stand"
        case .poseSequence:   return "list.bullet"
        case .soundAndFace:   return "waveform.and.person.filled"
        }
    }

    /// Нужна TrueDepth (ARFaceTracking). Игры без TrueDepth работают через AVCapture.
    var requiresFaceTracking: Bool {
        switch self {
        case .arMirror, .mimicLyalya, .holdThePose, .poseSequence, .soundAndFace: return true
        case .butterflyCatch, .breathingAR: return false
        }
    }

    /// Нужен микрофон.
    var requiresMicrophone: Bool {
        switch self {
        case .breathingAR, .soundAndFace: return true
        default: return false
        }
    }

    /// Ориентировочная длительность (секунды).
    var estimatedDurationSec: Int {
        switch self {
        case .arMirror:       return 180
        case .butterflyCatch: return 120
        case .breathingAR:    return 150
        case .mimicLyalya:    return 180
        case .holdThePose:    return 120
        case .poseSequence:   return 180
        case .soundAndFace:   return 150
        }
    }
}

// MARK: - ARCapabilityState

/// Результат проверки hardware capabilities.
struct ARCapabilityState: Sendable, Equatable {
    let supportsFaceTracking: Bool
    let supportsWorldTracking: Bool
    let supportsMicrophone: Bool
}

// MARK: - ARPermissionState

/// Конечный автомат разрешений.
enum ARPermissionState: Sendable, Equatable {
    case notDetermined
    case requesting
    case authorized
    case denied
}

// MARK: - ARActivityGameCard

/// View-модель карточки AR-игры в selection screen.
struct ARActivityGameCard: Identifiable, Sendable, Equatable {
    let id: String
    let kind: ARGameKind
    let title: String
    let description: String
    let iconSystemName: String
    let estimatedLabel: String
    let isRecommended: Bool
    let isAvailable: Bool
    let unavailableReason: String
    let playedToday: Bool
}

// MARK: - ARActivityModels

enum ARActivityModels {

    // MARK: - LoadActivity

    /// Построение данных для selection screen.
    enum LoadActivity {
        struct Request: Sendable {
            let contentUnitId: String
            let soundGroup: String
            let targetSound: String
            let stage: String
            let childName: String
            let childId: String
            let childAge: Int
        }

        struct Response: Sendable {
            let capability: ARCapabilityState
            let cameraPermission: ARPermissionState
            let microphonePermission: ARPermissionState
            let gameCards: [ARActivityGameCard]
            let recommendedKind: ARGameKind?
            let targetSound: String
            let childName: String
        }

        struct ViewModel: Sendable {
            let screenTitle: String
            let subtitle: String
            let gameCards: [ARActivityGameCard]
            let cameraPermissionState: ARPermissionState
            let microphonePermissionState: ARPermissionState
            let showPermissionBanner: Bool
            let permissionBannerMessage: String
            let hasAnyAvailableGame: Bool
            let previewReady: Bool
        }
    }

    // MARK: - RequestPermission

    enum RequestPermission {
        struct Request: Sendable {
            enum Kind: Sendable { case camera, microphone }
            let kind: Kind
        }
        struct Response: Sendable {
            let kind: Request.Kind
            let granted: Bool
        }
        struct ViewModel: Sendable {
            let cameraPermission: ARPermissionState
            let microphonePermission: ARPermissionState
            let showPermissionBanner: Bool
            let permissionBannerMessage: String
        }
    }

    // MARK: - SelectGame

    /// Пользователь выбрал AR-игру.
    enum SelectGame {
        struct Request: Sendable { let kind: ARGameKind }
        struct Response: Sendable { let kind: ARGameKind }
        struct ViewModel: Sendable { let kind: ARGameKind }
    }

    // MARK: - StartActivity (legacy compat + new)

    enum StartActivity {
        struct Request: Sendable { let activityType: ARActivityType }
        struct Response: Sendable { let activityType: ARActivityType }
        struct ViewModel: Sendable { let activityType: ARActivityType }
    }

    // MARK: - CompleteActivity

    enum CompleteActivity {
        struct Request: Sendable {
            let activityType: ARActivityType
            let gameKind: ARGameKind?
            let score: Float
            let attempts: Int
            let durationSec: Int
        }

        struct Response: Sendable {
            let score: Float
            let starsEarned: Int
            let message: String
            let gameKind: ARGameKind?
        }

        struct ViewModel: Sendable {
            let starsEarned: Int
            let scoreLabel: String
            let message: String
            let score: Float
        }
    }

    // MARK: - OpenSettings

    enum OpenSettings {
        struct Request: Sendable {}
    }
}

// MARK: - ARActivityType

/// Какой AR-экран будет показан ребёнку после preview (legacy compat).
enum ARActivityType: String, Sendable, Equatable {
    case mirror
    case storyQuest

    /// Маппинг из нового ARGameKind.
    static func from(kind: ARGameKind) -> ARActivityType {
        switch kind {
        case .arMirror, .mimicLyalya, .holdThePose, .poseSequence, .soundAndFace:
            return .mirror
        case .butterflyCatch, .breathingAR:
            return .storyQuest
        }
    }
}

// MARK: - ARActivityPhase

/// Последовательность состояний UI.
enum ARActivityPhase: Sendable, Equatable {
    case loading
    case permissionDenied
    case selection
    case active
    case completed
}

// MARK: - ARActivityViewDisplay

/// Наблюдаемый store, который Presenter заполняет данными для SwiftUI.
@Observable
@MainActor
final class ARActivityViewDisplay {
    var screenTitle: String = ""
    var subtitle: String = ""
    var gameCards: [ARActivityGameCard] = []
    var cameraPermission: ARPermissionState = .notDetermined
    var microphonePermission: ARPermissionState = .notDetermined
    var showPermissionBanner: Bool = false
    var permissionBannerMessage: String = ""
    var hasAnyAvailableGame: Bool = false
    var phase: ARActivityPhase = .loading
    // completed state
    var starsEarned: Int = 0
    var scoreLabel: String = ""
    var completionMessage: String = ""
    var lastScore: Float = 0
    // active state (legacy)
    var activeGameKind: ARGameKind?
    var activityType: ARActivityType = .mirror
    // kept for DisplayLogic compat
    var title: String = ""
    var description: String = ""
    var iconSystemName: String = "arkit"
    var estimatedLabel: String = ""
}

import Foundation

// MARK: - Onboarding VIP Models
//
// 7-шаговый онбординг (упрощённая версия 10-шагового UX'а из дизайн-спека):
//   1. Welcome           — маскот Ляля + «Начать»
//   2. Role              — родитель / специалист / ребёнок
//   3. ChildProfile      — имя, возраст, аватар-emoji
//   4. Goals             — мультиселект целей
//   5. Permissions       — embed PermissionFlowView (микрофон / камера / уведомления)
//   6. ModelDownload     — Whisper модель + опция Skip
//   7. Completion        — confetti + «Войти в приложение»

// MARK: - OnboardingStep

public enum OnboardingStep: Int, Sendable, CaseIterable {
    case welcome = 0
    case role
    case childProfile
    case goals
    case permissions
    case modelDownload
    case completion

    public var title: String {
        switch self {
        case .welcome:        return String(localized: "onboarding.step.welcome.title")
        case .role:           return String(localized: "onboarding.step.role.title")
        case .childProfile:   return String(localized: "onboarding.step.profile.title")
        case .goals:          return String(localized: "onboarding.step.goals.title")
        case .permissions:   return String(localized: "onboarding.step.permissions.title")
        case .modelDownload: return String(localized: "onboarding.step.model.title")
        case .completion:    return String(localized: "onboarding.step.completion.title")
        }
    }
}

// MARK: - UserRole + Onboarding metadata
//
// Базовый `UserRole` объявлен в `Core/Types/HSTypes.swift`. Здесь добавляем
// CaseIterable / Identifiable / отображаемые поля (только для онбординга).

extension UserRole: CaseIterable, Identifiable {
    public static var allCases: [UserRole] { [.parent, .specialist, .child] }

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .parent:     return String(localized: "onboarding.role.parent")
        case .specialist: return String(localized: "onboarding.role.specialist")
        case .child:      return String(localized: "onboarding.role.child")
        }
    }

    public var emoji: String {
        switch self {
        case .parent:     return "👨‍👩‍👧"
        case .specialist: return "🩺"
        case .child:      return "🧒"
        }
    }

    public var description: String {
        switch self {
        case .parent:     return String(localized: "onboarding.role.parentDesc")
        case .specialist: return String(localized: "onboarding.role.specialistDesc")
        case .child:      return String(localized: "onboarding.role.childDesc")
        }
    }
}

// MARK: - OnboardingProfile

public struct OnboardingProfile: Sendable, Equatable {
    public var role: UserRole
    public var childName: String
    public var childAge: Int
    public var childAvatar: String
    public var goals: Set<String>

    public init(
        role: UserRole = .parent,
        childName: String = "",
        childAge: Int = 6,
        childAvatar: String = "🐱",
        goals: Set<String> = []
    ) {
        self.role = role
        self.childName = childName
        self.childAge = childAge
        self.childAvatar = childAvatar
        self.goals = goals
    }

    public static let availableAvatars: [String] = ["🐱", "🐶", "🦊", "🐻", "🐼", "🦁"]

    public static let availableAges: [Int] = Array(3...12)

    public static let availableGoals: [(id: String, label: String)] = [
        ("rhotic",     String(localized: "onboarding.goal.rhotic")),
        ("hissing",    String(localized: "onboarding.goal.hissing")),
        ("whistling",  String(localized: "onboarding.goal.whistling")),
        ("grammar",    String(localized: "onboarding.goal.grammar")),
        ("communication", String(localized: "onboarding.goal.communication"))
    ]
}

// MARK: - ModelDownloadStatus

public enum ModelDownloadStatus: Sendable, Equatable {
    case idle
    case downloading(progress: Double)
    case completed
    case failed(message: String)
    case skipped
}

// MARK: - VIP scenes

enum OnboardingModels {

    // MARK: - LoadOnboarding

    enum LoadOnboarding {
        struct Request: Sendable {}
        struct Response: Sendable {
            let initialStep: OnboardingStep
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let currentStep: OnboardingStep
            let totalSteps: Int
            let progress: Double
            let progressLabel: String
            let profile: OnboardingProfile
            let canAdvance: Bool
        }
    }

    // MARK: - AdvanceStep

    enum AdvanceStep {
        struct Request: Sendable {
            let from: OnboardingStep
        }
        struct Response: Sendable {
            let currentStep: OnboardingStep
            let profile: OnboardingProfile
            let isCompleted: Bool
        }
        struct ViewModel: Sendable {
            let currentStep: OnboardingStep
            let totalSteps: Int
            let progress: Double
            let progressLabel: String
            let profile: OnboardingProfile
            let canAdvance: Bool
            let isCompleted: Bool
        }
    }

    // MARK: - GoBack

    enum GoBack {
        struct Request: Sendable {}
        struct Response: Sendable {
            let currentStep: OnboardingStep
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let currentStep: OnboardingStep
            let totalSteps: Int
            let progress: Double
            let progressLabel: String
            let canAdvance: Bool
        }
    }

    // MARK: - SetRole

    enum SetRole {
        struct Request: Sendable {
            let role: UserRole
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let canAdvance: Bool
        }
    }

    // MARK: - SetProfile

    enum SetProfile {
        struct Request: Sendable {
            let name: String
            let age: Int
            let avatar: String
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let canAdvance: Bool
        }
    }

    // MARK: - ToggleGoal

    enum ToggleGoal {
        struct Request: Sendable {
            let goalId: String
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let canAdvance: Bool
        }
    }

    // MARK: - SkipPermissions

    enum SkipPermissions {
        struct Request: Sendable {}
        struct Response: Sendable {
            let currentStep: OnboardingStep
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let currentStep: OnboardingStep
            let totalSteps: Int
            let progress: Double
            let progressLabel: String
            let canAdvance: Bool
        }
    }

    // MARK: - StartModelDownload

    enum StartModelDownload {
        struct Request: Sendable {}
        struct Response: Sendable {
            let status: ModelDownloadStatus
        }
        struct ViewModel: Sendable {
            let status: ModelDownloadStatus
            let canAdvance: Bool
            let statusLabel: String
        }
    }

    // MARK: - CompleteOnboarding

    enum CompleteOnboarding {
        struct Request: Sendable {}
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
        }
    }
}

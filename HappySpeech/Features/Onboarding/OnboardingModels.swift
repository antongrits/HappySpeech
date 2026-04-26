import Foundation

// MARK: - Onboarding VIP Models
//
// 10-шаговый онбординг (deep version, B12). Каждый шаг — экран,
// чередуются обязательные / необязательные. Модели и сцены VIP
// строго Sendable + @MainActor-совместимы.
//
//   1. Welcome           — маскот Ляля + «Начать»
//   2. Role              — родитель / специалист / ребёнок
//   3. ChildName         — имя + аватар-emoji
//   4. ChildAge          — возраст (5–8 лет)
//   5. Goals             — мультиселект целей занятий
//   6. Sounds            — какие звуки трудны (опционально, чипы)
//   7. Schedule          — сколько минут в день (5/10/15/20)
//   8. Permissions       — embed PermissionFlowView (микрофон / камера / уведомления)
//   9. ModelDownload     — Whisper модель + опция Skip
//  10. Completion        — confetti + «Войти в приложение»

// MARK: - OnboardingStep

public enum OnboardingStep: Int, Sendable, CaseIterable {
    case welcome = 0
    case role
    case childName
    case childAge
    case goals
    case sounds
    case schedule
    case permissions
    case modelDownload
    case completion

    /// True если шаг можно пропустить кнопкой «Пропустить».
    public var isSkippable: Bool {
        switch self {
        case .sounds, .permissions, .modelDownload:
            return true
        default:
            return false
        }
    }

    public var title: String {
        switch self {
        case .welcome:        return String(localized: "onboarding.step.welcome.title")
        case .role:           return String(localized: "onboarding.step.role.title")
        case .childName:      return String(localized: "onboarding.step.profile.title")
        case .childAge:       return String(localized: "onboarding.step.age.title")
        case .goals:          return String(localized: "onboarding.step.goals.title")
        case .sounds:         return String(localized: "onboarding.step.sounds.title")
        case .schedule:       return String(localized: "onboarding.step.schedule.title")
        case .permissions:    return String(localized: "onboarding.step.permissions.title")
        case .modelDownload:  return String(localized: "onboarding.step.model.title")
        case .completion:     return String(localized: "onboarding.step.completion.title")
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
    public var difficultSounds: Set<String>
    public var dailyMinutes: Int

    public init(
        role: UserRole = .parent,
        childName: String = "",
        childAge: Int = 6,
        childAvatar: String = "🐱",
        goals: Set<String> = [],
        difficultSounds: Set<String> = [],
        dailyMinutes: Int = 10
    ) {
        self.role = role
        self.childName = childName
        self.childAge = childAge
        self.childAvatar = childAvatar
        self.goals = goals
        self.difficultSounds = difficultSounds
        self.dailyMinutes = dailyMinutes
    }

    public static let availableAvatars: [String] = ["🐱", "🐶", "🦊", "🐻", "🐼", "🦁"]

    /// Целевой возраст 5–8 лет (методическое требование).
    /// Допустимый диапазон 3–12 лет — крайние возраста показываются «вне рекомендованного».
    public static let availableAges: [Int] = Array(3...12)
    public static let recommendedAgeRange: ClosedRange<Int> = 5...8

    public static let availableGoals: [(id: String, label: String)] = [
        ("pronunciation", String(localized: "onboarding.goal.pronunciation")),
        ("fluency", String(localized: "onboarding.goal.fluency")),
        ("vocabulary", String(localized: "onboarding.goal.vocabulary")),
        ("grammar", String(localized: "onboarding.goal.grammar")),
        ("communication", String(localized: "onboarding.goal.communication"))
    ]

    /// Звуки русского языка, с которыми чаще всего работают логопеды
    /// в возрасте 5–8 лет. Группа: соноры (Р, Л), шипящие (Ш, Ж, Ч, Щ),
    /// свистящие (С, З), заднеязычные (К, Г, Х).
    public static let availableSounds: [(id: String, label: String)] = [
        ("R", "Р"),
        ("L", "Л"),
        ("Sh", "Ш"),
        ("Zh", "Ж"),
        ("Ch", "Ч"),
        ("Sch", "Щ"),
        ("S", "С"),
        ("Z", "З"),
        ("Ts", "Ц"),
        ("K", "К"),
        ("G", "Г"),
        ("Kh", "Х")
    ]

    /// Варианты длительности занятий в минутах.
    public static let availableSchedules: [Int] = [5, 10, 15, 20]
}

// MARK: - DailySchedulePreset

/// Helper для отображения вариантов расписания с описанием.
public struct DailySchedulePreset: Sendable, Identifiable, Equatable {
    public let minutes: Int
    public let title: String
    public let subtitle: String

    public var id: Int { minutes }

    public init(minutes: Int) {
        self.minutes = minutes
        self.title = String(format: String(localized: "onboarding.schedule.minutes"), minutes)
        switch minutes {
        case 5:  self.subtitle = String(localized: "onboarding.schedule.subtitle.5")
        case 10: self.subtitle = String(localized: "onboarding.schedule.subtitle.10")
        case 15: self.subtitle = String(localized: "onboarding.schedule.subtitle.15")
        default: self.subtitle = String(localized: "onboarding.schedule.subtitle.20")
        }
    }

    public static let allPresets: [DailySchedulePreset] =
        OnboardingProfile.availableSchedules.map { DailySchedulePreset(minutes: $0) }
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
            let mascotText: String
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
            let mascotText: String
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
            let mascotText: String
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

    // MARK: - SetProfile (имя + аватар; возраст — отдельным шагом)

    enum SetProfile {
        struct Request: Sendable {
            let name: String
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

    // MARK: - SetAge

    enum SetAge {
        struct Request: Sendable {
            let age: Int
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

    // MARK: - ToggleSound

    enum ToggleSound {
        struct Request: Sendable {
            let soundId: String
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let canAdvance: Bool
        }
    }

    // MARK: - SetSchedule

    enum SetSchedule {
        struct Request: Sendable {
            let minutes: Int
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
            let mascotText: String
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

// MARK: - OnboardingState (persistence helper)

/// Хранит флаг «онбординг пройден» и сериализованный профиль ребёнка
/// в UserDefaults. Используется AppCoordinator'ом и Splash для роутинга.
public enum OnboardingState {

    private enum Keys {
        static let completed = "onboarding.completed"
        static let profile   = "onboarding.profile"
    }

    public static var isCompleted: Bool {
        UserDefaults.standard.bool(forKey: Keys.completed)
    }

    public static func markCompleted(profile: OnboardingProfile) {
        UserDefaults.standard.set(true, forKey: Keys.completed)
        if let data = try? encodeProfile(profile) {
            UserDefaults.standard.set(data, forKey: Keys.profile)
        }
    }

    public static func reset() {
        UserDefaults.standard.removeObject(forKey: Keys.completed)
        UserDefaults.standard.removeObject(forKey: Keys.profile)
    }

    public static func loadProfile() -> OnboardingProfile? {
        guard let data = UserDefaults.standard.data(forKey: Keys.profile) else {
            return nil
        }
        return try? decodeProfile(data)
    }

    // MARK: - Codec

    private struct CodableProfile: Codable {
        let role: String
        let childName: String
        let childAge: Int
        let childAvatar: String
        let goals: [String]
        let difficultSounds: [String]
        let dailyMinutes: Int
    }

    private static func encodeProfile(_ profile: OnboardingProfile) throws -> Data {
        let codable = CodableProfile(
            role: profile.role.rawValue,
            childName: profile.childName,
            childAge: profile.childAge,
            childAvatar: profile.childAvatar,
            goals: Array(profile.goals).sorted(),
            difficultSounds: Array(profile.difficultSounds).sorted(),
            dailyMinutes: profile.dailyMinutes
        )
        return try JSONEncoder().encode(codable)
    }

    private static func decodeProfile(_ data: Data) throws -> OnboardingProfile {
        let decoded = try JSONDecoder().decode(CodableProfile.self, from: data)
        return OnboardingProfile(
            role: UserRole(rawValue: decoded.role) ?? .parent,
            childName: decoded.childName,
            childAge: decoded.childAge,
            childAvatar: decoded.childAvatar,
            goals: Set(decoded.goals),
            difficultSounds: Set(decoded.difficultSounds),
            dailyMinutes: decoded.dailyMinutes
        )
    }
}

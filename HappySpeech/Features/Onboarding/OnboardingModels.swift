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

    /// Block D v16: эмодзи заменены на SF Symbols (UI chrome category).
    public var systemImageName: String {
        switch self {
        case .parent:     return "person.2.fill"
        case .specialist: return "stethoscope"
        case .child:      return "figure.child"
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

// MARK: - ChildGender

/// Пол ребёнка — используется для выбора голосовой модели и грамматических форм.
public enum ChildGender: String, Sendable, Equatable, CaseIterable, Identifiable {
    case boy
    case girl
    case notSpecified

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .boy:          return String(localized: "onboarding.gender.boy")
        case .girl:         return String(localized: "onboarding.gender.girl")
        case .notSpecified: return String(localized: "onboarding.gender.notSpecified")
        }
    }

    /// Block D v16: эмодзи заменены на SF Symbols.
    public var systemImageName: String {
        switch self {
        case .boy:          return "figure.child"
        case .girl:         return "figure.child"
        case .notSpecified: return "person.fill.questionmark"
        }
    }
}

// MARK: - LyalyaPreset

/// Быстрые пресеты кастомизации маскота Ляли (цвет акцента + аксессуар).
public enum LyalyaPreset: String, Sendable, Equatable, CaseIterable, Identifiable {
    case `default` = "default"
    case sunny = "sunny"
    case ocean = "ocean"
    case forest = "forest"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .default: return String(localized: "onboarding.lyalya.preset.default")
        case .sunny:   return String(localized: "onboarding.lyalya.preset.sunny")
        case .ocean:   return String(localized: "onboarding.lyalya.preset.ocean")
        case .forest:  return String(localized: "onboarding.lyalya.preset.forest")
        }
    }

    /// Символьный идентификатор для LyalyaMascotView
    public var mascotVariant: String {
        switch self {
        case .default: return "lyalya_default"
        case .sunny:   return "lyalya_sunny"
        case .ocean:   return "lyalya_ocean"
        case .forest:  return "lyalya_forest"
        }
    }
}

// MARK: - OnboardingProfile

public struct OnboardingProfile: Sendable, Equatable {
    public var role: UserRole
    public var childName: String
    public var childAge: Int
    public var childAvatar: String
    public var childGender: ChildGender
    public var goals: Set<String>
    public var difficultSounds: Set<String>
    public var dailyMinutes: Int

    // Reminder
    public var reminderEnabled: Bool
    public var reminderHour: Int
    public var reminderMinute: Int
    /// Дни недели: 1 = Пн, 2 = Вт, ... 7 = Вс (Calendar.Component.weekday, ISO)
    public var reminderDays: Set<Int>

    // Privacy + legal
    public var privacyAccepted: Bool

    // Screening
    public var screeningRequested: Bool

    // Lyalya customization
    public var lyalyaPreset: LyalyaPreset

    public init(
        role: UserRole = .parent,
        childName: String = "",
        childAge: Int = 6,
        childAvatar: String = "🐱",
        childGender: ChildGender = .notSpecified,
        goals: Set<String> = [],
        difficultSounds: Set<String> = [],
        dailyMinutes: Int = 10,
        reminderEnabled: Bool = false,
        reminderHour: Int = 17,
        reminderMinute: Int = 0,
        reminderDays: Set<Int> = [1, 2, 3, 4, 5],
        privacyAccepted: Bool = false,
        screeningRequested: Bool = false,
        lyalyaPreset: LyalyaPreset = .default
    ) {
        self.role = role
        self.childName = childName
        self.childAge = childAge
        self.childAvatar = childAvatar
        self.childGender = childGender
        self.goals = goals
        self.difficultSounds = difficultSounds
        self.dailyMinutes = dailyMinutes
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.reminderDays = reminderDays
        self.privacyAccepted = privacyAccepted
        self.screeningRequested = screeningRequested
        self.lyalyaPreset = lyalyaPreset
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

    /// Читаемое представление выбранного времени напоминания (для UI).
    public var reminderTimeFormatted: String {
        String(format: "%02d:%02d", reminderHour, reminderMinute)
    }

    /// Именованные дни недели для UI (1=Пн ... 7=Вс, ISO 8601).
    public static let weekdayLabels: [(day: Int, short: String)] = [
        (1, "Пн"), (2, "Вт"), (3, "Ср"), (4, "Чт"),
        (5, "Пт"), (6, "Сб"), (7, "Вс")
    ]
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
            let permissionsStatus: OnboardingPermissionsStatus
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
            let permissionsStatus: OnboardingPermissionsStatus
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
            let permissionsStatus: OnboardingPermissionsStatus
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

    // MARK: - SetGender

    enum SetGender {
        struct Request: Sendable {
            let gender: ChildGender
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let canAdvance: Bool
        }
    }

    // MARK: - SetLyalyaPreset

    enum SetLyalyaPreset {
        struct Request: Sendable {
            let preset: LyalyaPreset
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let canAdvance: Bool
        }
    }

    // MARK: - RequestPermission

    enum RequestPermission {
        struct Request: Sendable {}
        struct Response: Sendable {
            let profile: OnboardingProfile
            let permissionsStatus: OnboardingPermissionsStatus
        }
        struct ViewModel: Sendable {
            let permissionsStatus: OnboardingPermissionsStatus
            let canAdvance: Bool
            let micLabel: String
            let cameraLabel: String
            let notificationsLabel: String
        }
    }

    // MARK: - SetReminderTime

    enum SetReminderTime {
        struct Request: Sendable {
            let hour: Int
            let minute: Int
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let timeFormatted: String
            let canAdvance: Bool
        }
    }

    // MARK: - ToggleReminderDay

    enum ToggleReminderDay {
        struct Request: Sendable {
            let weekday: Int
        }
        // Response и ViewModel — те же что SetReminderTime (через presentSetReminderTime)
    }

    // MARK: - AcceptPrivacyConsent

    enum AcceptPrivacyConsent {
        struct Request: Sendable {
            let accepted: Bool
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let canAdvance: Bool
        }
    }

    // MARK: - SelectScreeningChoice

    enum SelectScreeningChoice {
        struct Request: Sendable {
            let wantsScreening: Bool
        }
        struct Response: Sendable {
            let profile: OnboardingProfile
            let wantsScreening: Bool
        }
        struct ViewModel: Sendable {
            let profile: OnboardingProfile
            let wantsScreening: Bool
            let canAdvance: Bool
        }
    }

    // MARK: - SkipModelDownload

    enum SkipModelDownload {
        struct Request: Sendable {}
        // Response → StartModelDownload.Response (через presentStartModelDownload со статусом .skipped)
    }

    // MARK: - PrivacyConsentRequired

    enum PrivacyConsentRequired {
        struct Response: Sendable {}
        struct ViewModel: Sendable {
            let errorMessage: String
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

    // CodableProfile объявлен в OnboardingInteractor.swift (fileprivate расширение)
    // и здесь не дублируется — используем OnboardingState.encode/decode.

    private static func encodeProfile(_ profile: OnboardingProfile) throws -> Data {
        try encode(profile: profile)
    }

    private static func decodeProfile(_ data: Data) throws -> OnboardingProfile {
        try decode(data: data)
    }
}

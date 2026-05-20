import Foundation

// MARK: - DailyRitualsLyalyaModels (Clean Swift: Models)
//
// v31 Волна A, Функция Ф8 «Утро и вечер с Лялей».
//
// Композиция: режимные ритуалы для семьи — утренний (3–4 короткие упражнения
// артикуляции/дыхания) и вечерний (1 спокойная история + дыхание). Локальные
// напоминания (UNUserNotificationCenter) родитель настраивает на удобное время.
//
// Контент — статичный композиционный массив существующих упражнений (ссылки
// на ArticulationGym / BreatheAndSpeak / Retelling-style). Этот модуль не
// дублирует контент — он его компонует.

// MARK: - RitualKind

public enum RitualKind: String, CaseIterable, Sendable {
    case morning
    case evening

    public var titleKey: String {
        switch self {
        case .morning: return "dailyRituals.kind.morning"
        case .evening: return "dailyRituals.kind.evening"
        }
    }

    public var subtitleKey: String {
        switch self {
        case .morning: return "dailyRituals.kind.morning.subtitle"
        case .evening: return "dailyRituals.kind.evening.subtitle"
        }
    }

    public var symbolName: String {
        switch self {
        case .morning: return "sun.max.fill"
        case .evening: return "moon.stars.fill"
        }
    }

    /// Время по умолчанию для напоминания.
    public var defaultHour: Int {
        switch self {
        case .morning: return 8
        case .evening: return 19
        }
    }

    public var defaultMinute: Int {
        switch self {
        case .morning: return 0
        case .evening: return 30
        }
    }
}

// MARK: - RitualStep

/// Отдельный шаг ритуала: короткое упражнение (1–2 мин). Поле `themeKey` —
/// ссылка на методическую тему, чтобы Ляля могла озвучить контекст; поле
/// `durationSeconds` — рекомендация для родителя/ребёнка.
public struct RitualStep: Identifiable, Sendable, Equatable {
    public let id: String
    public let titleKey: String
    public let descriptionKey: String
    public let symbolName: String
    public let durationSeconds: Int

    public init(
        id: String,
        titleKey: String,
        descriptionKey: String,
        symbolName: String,
        durationSeconds: Int
    ) {
        self.id = id
        self.titleKey = titleKey
        self.descriptionKey = descriptionKey
        self.symbolName = symbolName
        self.durationSeconds = durationSeconds
    }
}

// MARK: - ReminderTime

public struct ReminderTime: Sendable, Equatable, Hashable {
    public let hour: Int
    public let minute: Int

    public init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }
}

// MARK: - DailyRitualsLyalyaModels namespace

enum DailyRitualsLyalyaModels {

    // MARK: Load

    enum Load {
        struct Request: Sendable {
            let kind: RitualKind
        }

        struct Response: Sendable {
            let kind: RitualKind
            let steps: [RitualStep]
            let reminderEnabled: Bool
            let reminderTime: ReminderTime
            let notificationsAuthorized: Bool
        }

        struct ViewModel: Sendable {
            let kind: RitualKind
            let title: String
            let subtitle: String
            let symbolName: String
            let steps: [StepViewModel]
            let totalMinutesLabel: String
            let reminderToggleLabel: String
            let reminderToggleSubtitle: String
            let reminderEnabled: Bool
            let reminderTime: ReminderTime
            let reminderTimeLabel: String
            let needsAuthorization: Bool
            let authorizationCtaLabel: String
        }

        struct StepViewModel: Identifiable, Sendable, Equatable {
            let id: String
            let title: String
            let description: String
            let symbolName: String
            let durationLabel: String
            let accessibilityLabel: String
        }
    }

    // MARK: ToggleReminder

    enum ToggleReminder {
        struct Request: Sendable {
            let kind: RitualKind
            let isEnabled: Bool
        }

        struct Response: Sendable {
            let kind: RitualKind
            let isEnabled: Bool
            let authorizationNeeded: Bool
        }
    }

    // MARK: UpdateTime

    enum UpdateTime {
        struct Request: Sendable {
            let kind: RitualKind
            let time: ReminderTime
        }

        struct Response: Sendable {
            let kind: RitualKind
            let time: ReminderTime
        }
    }

    // MARK: RequestPermission

    enum RequestPermission {
        struct Request: Sendable {
            let kind: RitualKind
        }

        struct Response: Sendable {
            let granted: Bool
        }
    }
}

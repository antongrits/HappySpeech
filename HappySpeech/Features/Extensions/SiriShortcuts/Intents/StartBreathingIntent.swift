import AppIntents
import Foundation
import OSLog

// MARK: - StartBreathingIntent

/// "Сири, начни дыхательное упражнение в ХэппиСпич"
/// Открывает шаблон breathing через deep link. Поддерживает настройку длительности.
@available(iOS 17.0, *)
public struct StartBreathingIntent: AppIntent {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "StartBreathingIntent")

    public static let title: LocalizedStringResource = "Начать дыхательное упражнение"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.start_breathing.description"),
        categoryName: "Упражнения"
    )
    public static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: LocalizedStringResource("Длительность (секунды)"),
        description: LocalizedStringResource("Сколько секунд выполнять упражнение. По умолчанию — 60 секунд."),
        default: 60,
        requestValueDialog: IntentDialog(
            LocalizedStringResource("Сколько секунд? Рекомендую 60 для начала.")
        )
    )
    public var durationSeconds: Int

    @Parameter(
        title: LocalizedStringResource("Тип дыхания"),
        description: LocalizedStringResource("Техника дыхательного упражнения"),
        default: .calm
    )
    public var breathingType: BreathingType

    public init() {}

    public init(durationSeconds: Int = 60, breathingType: BreathingType = .calm) {
        self.durationSeconds = durationSeconds
        self.breathingType = breathingType
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let clampedDuration = max(15, min(durationSeconds, 300))
        let duration = TimeInterval(clampedDuration)

        await MainActor.run {
            DeepLinkRouter.shared.handleStartBreathing(duration: duration)
        }

        logger.info("StartBreathingIntent: duration=\(clampedDuration)s type=\(breathingType.rawValue)")

        let typeLabel = breathingTypeLabel(breathingType)
        let dialog = IntentDialog(
            LocalizedStringResource("Начинаем \(typeLabel) на \(clampedDuration) секунд. Дыши глубоко!")
        )
        return .result(dialog: dialog)
    }

    // MARK: - Private

    private func breathingTypeLabel(_ t: BreathingType) -> String {
        switch t {
        case .calm:    return "спокойное дыхание"
        case .belly:   return "брюшное дыхание"
        case .counted: return "дыхание со счётом"
        }
    }
}

// MARK: - BreathingType (AppEnum)

@available(iOS 17.0, *)
public enum BreathingType: String, AppEnum {
    case calm
    case belly
    case counted

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Тип дыхания")
    )

    public static let caseDisplayRepresentations: [BreathingType: DisplayRepresentation] = [
        .calm:    DisplayRepresentation(title: "Спокойное"),
        .belly:   DisplayRepresentation(title: "Брюшное"),
        .counted: DisplayRepresentation(title: "Со счётом")
    ]
}

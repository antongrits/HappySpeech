import AppIntents

// MARK: - StartBreathingIntent

/// "Сири, начни дыхательное упражнение"
/// Открывает шаблон дыхательных упражнений в LessonPlayer.
@available(iOS 17.0, *)
public struct StartBreathingIntent: AppIntent {

    public static let title: LocalizedStringResource = "Начать дыхательное упражнение"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.start_breathing.description")
    )
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            DeepLinkRouter.shared.handleStartBreathing()
        }
        return .result()
    }
}

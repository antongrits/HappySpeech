import AppIntents

// MARK: - ShowChildProgressIntent

/// "Сири, покажи прогресс"
/// Открывает ProgressDashboard для текущего активного профиля.
@available(iOS 17.0, *)
public struct ShowChildProgressIntent: AppIntent {

    public static let title: LocalizedStringResource = "Показать прогресс"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.show_progress.description")
    )
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            DeepLinkRouter.shared.handleShowProgress()
        }
        return .result()
    }
}

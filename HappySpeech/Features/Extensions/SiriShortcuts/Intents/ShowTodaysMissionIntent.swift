import AppIntents

// MARK: - ShowTodaysMissionIntent

/// "Сири, покажи задание на сегодня"
/// Открывает адаптивный дневной маршрут (AdaptivePlannerService).
@available(iOS 17.0, *)
public struct ShowTodaysMissionIntent: AppIntent {

    public static let title: LocalizedStringResource = "Задание на сегодня"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.show_todays_mission.description")
    )
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            DeepLinkRouter.shared.handleShowTodaysMission()
        }
        return .result()
    }
}

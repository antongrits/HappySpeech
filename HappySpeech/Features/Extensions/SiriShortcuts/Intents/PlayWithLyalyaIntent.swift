import AppIntents

// MARK: - PlayWithLyalyaIntent

/// "Сири, играй с Лялей"
/// Открывает главный детский экран (ChildHome) с маскотом Лялей.
@available(iOS 17.0, *)
public struct PlayWithLyalyaIntent: AppIntent {

    public static let title: LocalizedStringResource = "Играть с Лялей"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.play_with_lyalya.description")
    )
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult {
        await MainActor.run {
            DeepLinkRouter.shared.handlePlayWithLyalya()
        }
        return .result()
    }
}

import AppIntents
import Foundation
import OSLog

// MARK: - OpenSoundTrafficLightIntent
//
// v31 Волна A research F-08. "Сири, открой звуковой светофор в HappySpeech".
// Открывает экран SoundTrafficLight через DeepLinkRouter.

@available(iOS 17.0, *)
public struct OpenSoundTrafficLightIntent: AppIntent {

    private let logger = Logger(
        subsystem: "ru.happyspeech.app",
        category: "OpenSoundTrafficLightIntent"
    )

    public static let title: LocalizedStringResource = "Открыть звуковой светофор"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.open_sound_traffic_light.description"),
        categoryName: "Звуки"
    )
    public static let openAppWhenRun: Bool = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        await MainActor.run {
            DeepLinkRouter.shared.handleOpenSoundTrafficLight()
        }
        logger.info("OpenSoundTrafficLightIntent: open sound traffic light")
        let dialog = IntentDialog(
            LocalizedStringResource("Открываю звуковой светофор. Готов узнать, какие звуки в работе?")
        )
        return .result(dialog: dialog)
    }
}

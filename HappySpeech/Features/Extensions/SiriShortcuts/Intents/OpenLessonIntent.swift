import AppIntents
import Foundation
import OSLog

// MARK: - OpenLessonIntent

/// "Сири, открой урок звука Ш"
/// Открывает LessonPlayer для указанного логопедического звука.
@available(iOS 17.0, *)
public struct OpenLessonIntent: AppIntent {

    public static let title: LocalizedStringResource = "Открыть урок"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.open_lesson.description")
    )
    public static let openAppWhenRun: Bool = true

    @Parameter(
        title: LocalizedStringResource("intent.open_lesson.param.sound"),
        description: LocalizedStringResource("intent.open_lesson.param.sound.description")
    )
    public var soundId: String

    public init() {}

    public init(soundId: String) {
        self.soundId = soundId
    }

    public func perform() async throws -> some IntentResult {
        let normalized = normalizeSound(soundId)
        let validSounds = ["С", "З", "Ц", "Ш", "Ж", "Ч", "Щ", "Р", "Рь", "Л", "Ль", "К", "Г", "Х"]
        guard validSounds.contains(normalized) else {
            throw $soundId.needsValueError("Не понимаю звук. Назови один из: С, З, Ш, Р, Л")
        }
        await MainActor.run {
            DeepLinkRouter.shared.handleOpenLesson(soundId: normalized)
        }
        return .result()
    }

    // MARK: - Private

    private func normalizeSound(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        // Нормализуем мягкий знак (может прийти как отдельный символ или слитно)
        let upper = trimmed.uppercased()
        // Восстанавливаем строчный мягкий знак для "Рь" / "Ль"
        let result = upper
            .replacingOccurrences(of: "РЬ", with: "Рь")
            .replacingOccurrences(of: "ЛЬ", with: "Ль")
        return result
    }
}

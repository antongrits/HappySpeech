import AppIntents
import Foundation
import OSLog

// MARK: - SoundGroup (AppEnum)

/// Группы звуков русской логопедии.
@available(iOS 17.0, *)
public enum SoundGroup: String, AppEnum {
    case whistling = "С"
    case hissing   = "Ш"
    case sonant    = "Р"
    case lateral   = "Л"
    case velar     = "К"

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Группа звуков")
    )

    public static let caseDisplayRepresentations: [SoundGroup: DisplayRepresentation] = [
        .whistling: DisplayRepresentation(title: "Свистящие (С, З, Ц)"),
        .hissing:   DisplayRepresentation(title: "Шипящие (Ш, Ж, Ч, Щ)"),
        .sonant:    DisplayRepresentation(title: "Соноры Р / Рь"),
        .lateral:   DisplayRepresentation(title: "Соноры Л / Ль"),
        .velar:     DisplayRepresentation(title: "Заднеязычные (К, Г, Х)")
    ]
}

// MARK: - Difficulty (AppEnum)

/// Уровень сложности занятия.
@available(iOS 17.0, *)
public enum LessonDifficulty: String, AppEnum {
    case easy
    case medium
    case hard

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Сложность")
    )

    public static let caseDisplayRepresentations: [LessonDifficulty: DisplayRepresentation] = [
        .easy:   DisplayRepresentation(title: "Лёгкий"),
        .medium: DisplayRepresentation(title: "Средний"),
        .hard:   DisplayRepresentation(title: "Сложный")
    ]
}

// MARK: - OpenLessonIntent

/// "Сири, открой урок звука Ш в ХэппиСпич"
/// Открывает LessonPlayer с заданным звуком, сложностью и (опционально) именем ребёнка.
@available(iOS 17.0, *)
public struct OpenLessonIntent: AppIntent {

    public static let title: LocalizedStringResource = "Открыть урок"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.open_lesson.description"),
        categoryName: "Обучение"
    )
    public static let openAppWhenRun: Bool = true

    // MARK: Parameters

    @Parameter(
        title: LocalizedStringResource("intent.open_lesson.param.sound"),
        description: LocalizedStringResource("intent.open_lesson.param.sound.description"),
        requestValueDialog: IntentDialog(
            LocalizedStringResource("Какой звук будем учить? Например: С, Ш, Р или Л")
        )
    )
    public var soundId: String

    @Parameter(
        title: LocalizedStringResource("Сложность"),
        description: LocalizedStringResource("Уровень сложности занятия"),
        default: .medium
    )
    public var difficulty: LessonDifficulty

    @Parameter(
        title: LocalizedStringResource("Имя ребёнка"),
        description: LocalizedStringResource("Для нескольких профилей в приложении"),
        requestValueDialog: IntentDialog(
            LocalizedStringResource("Чьё занятие открыть?")
        )
    )
    public var childName: String?

    public init() {}

    public init(soundId: String, difficulty: LessonDifficulty = .medium, childName: String? = nil) {
        self.soundId = soundId
        self.difficulty = difficulty
        self.childName = childName
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let normalized = normalizeSound(soundId)
        let validSounds = ["С", "З", "Ц", "Ш", "Ж", "Ч", "Щ", "Р", "Рь", "Л", "Ль", "К", "Г", "Х"]
        guard validSounds.contains(normalized) else {
            throw $soundId.needsValueError(
                "Не знаю звук «\(soundId)». Попробуй назвать один из: С, З, Ш, Р, Л"
            )
        }

        let diffLabel = difficultyLabel(difficulty)
        await MainActor.run {
            DeepLinkRouter.shared.handleOpenLesson(soundId: normalized, difficulty: difficulty.rawValue)
        }

        let dialog: IntentDialog
        if let name = childName, !name.isEmpty {
            dialog = IntentDialog(
                LocalizedStringResource("Открываю урок звука \(normalized) (\(diffLabel)) для \(name)! Поехали!")
            )
        } else {
            dialog = IntentDialog(
                LocalizedStringResource("Открываю урок звука \(normalized) (\(diffLabel))! Поехали!")
            )
        }
        return .result(dialog: dialog)
    }

    // MARK: - Helpers

    private func normalizeSound(_ input: String) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let upper = trimmed.uppercased()
        return upper
            .replacingOccurrences(of: "РЬ", with: "Рь")
            .replacingOccurrences(of: "ЛЬ", with: "Ль")
    }

    private func difficultyLabel(_ d: LessonDifficulty) -> String {
        switch d {
        case .easy:   return "лёгкий"
        case .medium: return "средний"
        case .hard:   return "сложный"
        }
    }
}

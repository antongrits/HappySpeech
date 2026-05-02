import AppIntents
import Foundation
import OSLog

// MARK: - StartCustomSessionIntent

/// "Сири, начни кастомное занятие: звук Р, 7 раундов, сложный"
/// Запускает LessonPlayer с пользовательскими параметрами звука, раундов и сложности.
@available(iOS 17.0, *)
public struct StartCustomSessionIntent: AppIntent {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "StartCustomSessionIntent")

    public static let title: LocalizedStringResource = "Начать кастомное занятие"
    public static let description = IntentDescription(
        LocalizedStringResource("Запустить занятие с вашими параметрами: звук, количество раундов и сложность"),
        categoryName: "Обучение"
    )
    public static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: LocalizedStringResource("Звук"),
        description: LocalizedStringResource("Целевой логопедический звук (С, Ш, Р, Л и другие)"),
        requestValueDialog: IntentDialog(
            LocalizedStringResource("Какой звук будем отрабатывать?")
        )
    )
    public var soundId: String

    @Parameter(
        title: LocalizedStringResource("Количество раундов"),
        description: LocalizedStringResource("От 3 до 20 раундов"),
        default: 5,
        requestValueDialog: IntentDialog(
            LocalizedStringResource("Сколько раундов? От 3 до 20.")
        )
    )
    public var rounds: Int

    @Parameter(
        title: LocalizedStringResource("Сложность"),
        description: LocalizedStringResource("Уровень сложности"),
        default: .medium
    )
    public var difficulty: LessonDifficulty

    @Parameter(
        title: LocalizedStringResource("Позиция звука"),
        description: LocalizedStringResource("В начале, середине или конце слова"),
        default: .any
    )
    public var soundPosition: SoundPosition

    public init() {}

    public init(
        soundId: String,
        rounds: Int = 5,
        difficulty: LessonDifficulty = .medium,
        soundPosition: SoundPosition = .any
    ) {
        self.soundId = soundId
        self.rounds = rounds
        self.difficulty = difficulty
        self.soundPosition = soundPosition
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let normalized = normalizeSound(soundId)
        let validSounds = ["С", "З", "Ц", "Ш", "Ж", "Ч", "Щ", "Р", "Рь", "Л", "Ль", "К", "Г", "Х"]
        guard validSounds.contains(normalized) else {
            throw $soundId.needsValueError(
                "Не знаю звук «\(soundId)». Назови один из: С, З, Ш, Р, Л и другие."
            )
        }

        let clampedRounds = max(3, min(rounds, 20))

        await MainActor.run {
            DeepLinkRouter.shared.handleStartCustomSession(
                soundId: normalized,
                rounds: clampedRounds,
                difficulty: difficulty.rawValue
            )
        }

        logger.info("StartCustomSessionIntent: sound=\(normalized) rounds=\(clampedRounds) difficulty=\(difficulty.rawValue)")

        let posLabel = soundPositionLabel(soundPosition)
        let diffLabel = difficultyLabel(difficulty)
        let text = "Запускаю занятие: звук \(normalized), \(clampedRounds) раундов, \(diffLabel), \(posLabel). Поехали!"
        let dialog = IntentDialog(stringLiteral: text)
        return .result(dialog: dialog)
    }

    // MARK: - Private

    private func normalizeSound(_ input: String) -> String {
        let upper = input.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
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

    private func soundPositionLabel(_ p: SoundPosition) -> String {
        switch p {
        case .initial:   return "звук в начале слова"
        case .medial:    return "звук в середине слова"
        case .wordFinal: return "звук в конце слова"
        case .any:       return "любая позиция"
        }
    }
}

// MARK: - SoundPosition (AppEnum)

@available(iOS 17.0, *)
public enum SoundPosition: String, AppEnum {
    case initial
    case medial
    case wordFinal
    case any

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Позиция звука")
    )

    public static let caseDisplayRepresentations: [SoundPosition: DisplayRepresentation] = [
        .initial:   DisplayRepresentation(title: "В начале слова"),
        .medial:    DisplayRepresentation(title: "В середине слова"),
        .wordFinal: DisplayRepresentation(title: "В конце слова"),
        .any:       DisplayRepresentation(title: "Любая позиция")
    ]
}

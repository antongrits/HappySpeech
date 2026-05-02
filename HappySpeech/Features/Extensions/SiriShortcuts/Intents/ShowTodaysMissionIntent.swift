import AppIntents
import Foundation
import OSLog

// MARK: - GameTemplate (AppEnum)

/// Шаблоны логопедических игр для выбора через Siri.
@available(iOS 17.0, *)
public enum GameTemplate: String, AppEnum {
    case listenAndChoose   = "listen-and-choose"
    case repeatAfterModel  = "repeat-after-model"
    case dragAndMatch      = "drag-and-match"
    case sortingGame       = "sorting"
    case memoryGame        = "memory"
    case storyCompletion   = "story-completion"
    case articulationImit  = "articulation-imitation"
    case rhythmGame        = "rhythm"
    case adaptivePlan      = "adaptive"

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(
        name: LocalizedStringResource("Шаблон игры")
    )

    public static let caseDisplayRepresentations: [GameTemplate: DisplayRepresentation] = [
        .listenAndChoose:  DisplayRepresentation(title: "Слушай и выбирай"),
        .repeatAfterModel: DisplayRepresentation(title: "Повторяй за образцом"),
        .dragAndMatch:     DisplayRepresentation(title: "Перетащи и совмести"),
        .sortingGame:      DisplayRepresentation(title: "Сортировка"),
        .memoryGame:       DisplayRepresentation(title: "Память"),
        .storyCompletion:  DisplayRepresentation(title: "Закончи историю"),
        .articulationImit: DisplayRepresentation(title: "Артикуляция"),
        .rhythmGame:       DisplayRepresentation(title: "Ритм"),
        .adaptivePlan:     DisplayRepresentation(title: "Адаптивный план Ляли")
    ]
}

// MARK: - ShowTodaysMissionIntent

/// "Сири, покажи задание на сегодня" / "Сири, начни сессию"
/// Открывает адаптивный дневной маршрут или конкретный шаблон игры.
@available(iOS 17.0, *)
public struct ShowTodaysMissionIntent: AppIntent {

    private let logger = Logger(subsystem: "ru.happyspeech.app", category: "ShowTodaysMissionIntent")

    public static let title: LocalizedStringResource = "Задание на сегодня"
    public static let description = IntentDescription(
        LocalizedStringResource("intent.show_todays_mission.description"),
        categoryName: "Обучение"
    )
    public static let openAppWhenRun: Bool = true

    // MARK: - Parameters

    @Parameter(
        title: LocalizedStringResource("Шаблон игры"),
        description: LocalizedStringResource("Выберите тип занятия или оставьте пустым для адаптивного выбора"),
        requestValueDialog: IntentDialog(
            LocalizedStringResource("Какой тип занятия? Или скажи «адаптивный» и Ляля выберет сама.")
        )
    )
    public var gameTemplate: GameTemplate?

    public init() {}

    public init(gameTemplate: GameTemplate? = nil) {
        self.gameTemplate = gameTemplate
    }

    // MARK: - Perform

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let mission = await loadMissionFromSharedDefaults()
        let templateId = gameTemplate?.rawValue

        await MainActor.run {
            DeepLinkRouter.shared.handleStartSession(gameTemplate: templateId)
        }

        logger.info("ShowTodaysMissionIntent: template=\(templateId ?? "adaptive")")

        let dialog: IntentDialog
        if let tmpl = gameTemplate {
            let label = gameTemplateName(tmpl)
            dialog = IntentDialog(
                LocalizedStringResource("Открываю занятие «\(label)»! Ляля уже ждёт.")
            )
        } else {
            dialog = IntentDialog(
                LocalizedStringResource("Сегодня: \(mission.title). \(mission.description). Открываю!")
            )
        }
        return .result(dialog: dialog)
    }

    // MARK: - Private

    private struct MissionInfo {
        let title: String
        let description: String
    }

    private func loadMissionFromSharedDefaults() async -> MissionInfo {
        let defaults = UserDefaults(suiteName: "group.com.mmf.bsu.shared")
        let title = defaults?.string(forKey: "daily_mission.title") ?? "Звук Ш"
        let desc  = defaults?.string(forKey: "daily_mission.description") ?? "5 раундов"
        return MissionInfo(title: title, description: desc)
    }

    private func gameTemplateName(_ tmpl: GameTemplate) -> String {
        switch tmpl {
        case .listenAndChoose:  return "Слушай и выбирай"
        case .repeatAfterModel: return "Повторяй за образцом"
        case .dragAndMatch:     return "Перетащи и совмести"
        case .sortingGame:      return "Сортировка"
        case .memoryGame:       return "Память"
        case .storyCompletion:  return "История"
        case .articulationImit: return "Артикуляция"
        case .rhythmGame:       return "Ритм"
        case .adaptivePlan:     return "Адаптивный план"
        }
    }
}

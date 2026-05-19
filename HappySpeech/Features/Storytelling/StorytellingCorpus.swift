import Foundation
import OSLog

// MARK: - StorytellingCorpus
//
// v29 Фаза 8, Функция 11 «Я расскажу историю».
//
// Корпус тем-стимулов с планами-схемами рассказа. Темы возрастные (7–8 лет),
// близкие личному опыту ребёнка. План-схема даёт опору программированию
// высказывания: narrative — кто/где/что/конец; description — кто/какой/что
// делает/где (рассказ-описание предмета).
//
// Контент загружается из бандл-ресурса `pack_storytelling.json` (~60 тем).
// Полностью offline / on-device.

enum StorytellingCorpus {

    /// Все темы-стимулы (из `pack_storytelling.json`).
    static let topics: [StoryTopic] = StorytellingPackLoader.shared.topics

    /// Тема по идентификатору.
    static func topic(id: String) -> StoryTopic? {
        topics.first { $0.id == id }
    }
}

// MARK: - StorytellingPackLoader
//
// Разбирает `pack_storytelling.json` один раз. При отказе бандла возвращает
// безопасный минимальный набор, чтобы модуль оставался рабочим.

struct StorytellingPackLoader {

    static let shared = StorytellingPackLoader()

    let topics: [StoryTopic]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Storytelling.PackLoader"
    )

    private struct Pack: Decodable {
        let plans: [String: [PlanStepDTO]]
        let topics: [TopicDTO]
    }

    private struct PlanStepDTO: Decodable {
        let id: String
        let question: String
        let symbolName: String
    }

    private struct TopicDTO: Decodable {
        let id: String
        let title: String
        let symbolName: String
        let planType: String
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_storytelling", withExtension: "json"
        ) else {
            Self.logger.error("pack_storytelling.json not found in bundle — using fallback")
            topics = StorytellingPackLoader.fallbackTopics
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            topics = pack.topics.compactMap { dto in
                guard let planSteps = pack.plans[dto.planType] else {
                    Self.logger.error("Unknown planType: \(dto.planType, privacy: .public)")
                    return nil
                }
                let plan = planSteps.map { step in
                    StoryPlanStep(
                        id: "\(dto.id)-\(step.id)",
                        question: step.question,
                        symbolName: step.symbolName
                    )
                }
                return StoryTopic(
                    id: dto.id,
                    title: dto.title,
                    symbolName: dto.symbolName,
                    plan: plan
                )
            }
        } catch {
            Self.logger.error(
                "pack_storytelling.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            topics = StorytellingPackLoader.fallbackTopics
        }
    }

    /// Универсальный план-схема для безопасного набора.
    private static func narrativePlan(prefix: String) -> [StoryPlanStep] {
        [
            .init(id: "\(prefix)-who",
                  question: "Кто главный герой рассказа?",
                  symbolName: "person.fill"),
            .init(id: "\(prefix)-where",
                  question: "Где происходит история?",
                  symbolName: "mappin.circle.fill"),
            .init(id: "\(prefix)-what",
                  question: "Что произошло? Что делал герой?",
                  symbolName: "figure.run"),
            .init(id: "\(prefix)-end",
                  question: "Чем всё закончилось?",
                  symbolName: "checkmark.seal.fill")
        ]
    }

    /// Минимальный безопасный набор на случай отказа бандла.
    private static let fallbackTopics: [StoryTopic] = [
        .init(id: "zoo-trip", title: "Прогулка в зоопарк",
              symbolName: "tortoise.fill", plan: narrativePlan(prefix: "zoo")),
        .init(id: "birthday", title: "Мой день рождения",
              symbolName: "gift.fill", plan: narrativePlan(prefix: "bday")),
        .init(id: "winter-walk", title: "Зимняя прогулка",
              symbolName: "snowflake", plan: narrativePlan(prefix: "winter")),
        .init(id: "favorite-toy", title: "Моя любимая игрушка",
              symbolName: "teddybear.fill", plan: narrativePlan(prefix: "toy")),
        .init(id: "forest-trip", title: "Поход в лес",
              symbolName: "tree.fill", plan: narrativePlan(prefix: "forest"))
    ]
}

import Foundation

// MARK: - ConversationStartersContent

/// Курируемый набор вопросов-стартеров для развития связной речи ребёнка.
///
/// Это методический контент (открытые вопросы, развивающие словарь и
/// грамматику), а не фабрикованная аналитика. Хранится как единый источник
/// правды; `ConversationStartersParentInteractor` накладывает поверх состояние
/// избранного из `UserDefaults`.
enum ConversationStartersContent {

    struct Item: Sendable {
        let id: String
        let text: String
        let category: ConversationStartersParentModels.Category
    }

    static let all: [Item] = build()

    private static func build() -> [Item] {
        let raw: [(text: String, cat: ConversationStartersParentModels.Category)] = [
            ("Что было самым весёлым сегодня?", .daily),
            ("Что было самым трудным?", .daily),
            ("С кем ты играл в садике?", .daily),
            ("Расскажи про любимую игрушку", .daily),
            ("Что мы делали вместе на выходных?", .daily),
            ("Какой звук тебе нравится больше всего?", .learning),
            ("Какое слово ты выучил сегодня?", .learning),
            ("Какое слово было трудным произнести?", .learning),
            ("Какое слово смешно звучит?", .learning),
            ("Какая твоя любимая буква?", .learning),
            ("Чему ты научился сегодня?", .learning),
            ("О чём ты мечтал по дороге домой?", .imagination),
            ("Какую сказку ты бы придумал?", .imagination),
            ("Что бы ты делал, если бы умел летать?", .imagination),
            ("Какой звук издают облака?", .imagination),
            ("Что бы ты приготовил для Ляли?", .imagination),
            ("Какое было самое доброе дело сегодня?", .feelings),
            ("Когда ты сегодня смеялся?", .feelings),
            ("Когда тебе было грустно?", .feelings),
            ("Кому ты сегодня помог?", .feelings),
            ("О чём ты хочешь поговорить со мной?", .feelings)
        ]
        return raw.enumerated().map { idx, item in
            Item(id: "q\(idx)", text: item.text, category: item.cat)
        }
    }
}

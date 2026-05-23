import Foundation

// MARK: - ConversationStartersParentModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum ConversationStartersParentModels {

    struct Question: Identifiable, Hashable {
        let id: String
        let text: String
        let category: Category
        var isFavorite: Bool
    }

    enum Category: String, CaseIterable, Hashable {
        case daily
        case feelings
        case imagination
        case learning

        var title: String {
            switch self {
            case .daily:       return "День"
            case .feelings:    return "Чувства"
            case .imagination: return "Фантазия"
            case .learning:    return "Учёба"
            }
        }

        var color: String { rawValue } // placeholder ключ
    }

    struct ViewState: Equatable {
        var questions: [Question]

        static let initial: ViewState = {
            let raw: [(text: String, cat: Category)] = [
                ("Что было самым весёлым сегодня?", .daily),
                ("Что было самым трудным?", .daily),
                ("С кем ты играл в садике?", .daily),
                ("Какой звук тебе нравится больше всего?", .learning),
                ("О чём ты мечтал по дороге домой?", .imagination),
                ("Какую сказку ты бы придумал?", .imagination),
                ("Что бы ты делал, если бы умел летать?", .imagination),
                ("Какое слово ты выучил сегодня?", .learning),
                ("Какое слово было трудным произнести?", .learning),
                ("Какое было самое доброе дело сегодня?", .feelings),
                ("Когда ты сегодня смеялся?", .feelings),
                ("Когда тебе было грустно?", .feelings),
                ("Расскажи про любимую игрушку", .daily),
                ("Какой звук издают облака?", .imagination),
                ("Что бы ты приготовил для Ляли?", .imagination),
                ("Кому ты сегодня помог?", .feelings),
                ("Чему ты научился сегодня?", .learning),
                ("Какое слово смешно звучит?", .learning),
                ("Какая твоя любимая буква?", .learning),
                ("О чём ты хочешь поговорить со мной?", .feelings)
            ]
            let qs = raw.enumerated().map { idx, item in
                Question(
                    id: "q\(idx)",
                    text: item.text,
                    category: item.cat,
                    isFavorite: idx == 0 || idx == 9
                )
            }
            return ViewState(questions: qs)
        }()
    }
}

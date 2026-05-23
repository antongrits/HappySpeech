import Foundation

// MARK: - WeeklyParentTipModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum WeeklyParentTipModels {

    struct Tip: Equatable {
        let id: String
        let weekLabel: String
        let title: String
        let bodyParagraphs: [String]
        let bulletPoints: [String]
        let authorName: String
        let authorRole: String
    }

    struct ViewState: Equatable {
        var tip: Tip

        static let initial = ViewState(
            tip: Tip(
                id: "w-21",
                weekLabel: "Неделя 21",
                title: "Как развивать связную речь через ежедневные ритуалы",
                bodyParagraphs: [
                    "Самые сильные речевые навыки развиваются не на занятиях, а в обычных бытовых ситуациях: за столом, в машине, при укладывании.",
                    "Ребёнку 5–8 лет нужно 10–15 минут активного разговора в день, " +
                    "чтобы расширять словарь и грамматику. " +
                    "Главное — задавать открытые вопросы, требующие развёрнутого ответа."
                ],
                bulletPoints: [
                    "После садика спросите: «Расскажи 3 события дня по порядку»",
                    "За едой обсудите вкус, запах и цвет блюда",
                    "Перед сном проговорите 3 хороших дела"
                ],
                authorName: "Анна Чернова",
                authorRole: "логопед, 12 лет практики"
            )
        )
    }
}

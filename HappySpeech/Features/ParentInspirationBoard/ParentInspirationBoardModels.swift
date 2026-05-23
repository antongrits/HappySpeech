import Foundation

// MARK: - ParentInspirationBoardModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum ParentInspirationBoardModels {

    struct Quote: Identifiable, Hashable {
        let id: String
        let text: String
        let author: String
        let role: String
        var isFavorite: Bool
    }

    struct ViewState: Equatable {
        var quotes: [Quote]
        var currentIndex: Int

        var current: Quote? {
            quotes.indices.contains(currentIndex) ? quotes[currentIndex] : nil
        }

        static let initial = ViewState(
            quotes: [
                Quote(id: "q1",
                      text: "Каждая буква, которую малыш произнёс правильно, — это маленькая победа.",
                      author: "Татьяна Ткаченко",
                      role: "логопед-методист",
                      isFavorite: false),
                Quote(id: "q2",
                      text: "Дети говорят так же, как с ними говорят родители. Будьте образцом.",
                      author: "Маргарита Фомичёва",
                      role: "логопед-методист",
                      isFavorite: true),
                Quote(id: "q3",
                      text: "Терпение и ежедневная практика побеждают любой звук.",
                      author: "Лариса Фомина",
                      role: "логопед-методист",
                      isFavorite: false),
                Quote(id: "q4",
                      text: "Артикуляционная гимнастика — это фундамент чистой речи.",
                      author: "Светлана Большакова",
                      role: "логопед-методист",
                      isFavorite: false),
                Quote(id: "q5",
                      text: "Ребёнок учится через игру — превратите занятие в приключение.",
                      author: "Розалия Левина",
                      role: "логопед-методист",
                      isFavorite: false),
                Quote(id: "q6",
                      text: "Хвалите за усилия, а не только за результат.",
                      author: "Зоя Репина",
                      role: "логопед-методист",
                      isFavorite: false)
            ],
            currentIndex: 0
        )
    }
}

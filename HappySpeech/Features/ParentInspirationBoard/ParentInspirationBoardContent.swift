import Foundation

// MARK: - ParentInspirationBoardContent

/// Курируемый каталог вдохновляющих цитат логопедов-методистов для родителей.
///
/// Это контент-каталог (единый источник правды), вынесенный из ViewState.
/// Цитаты — методические принципы русской логопедии в доступной форме.
enum ParentInspirationBoardContent {

    /// Каталог цитат. `id` стабилен (для персистентности избранного).
    static let quotes: [ParentInspirationBoardModels.Quote] = [
        .init(id: "q1",
              text: String(localized: "inspiration.q1.text"),
              author: "Татьяна Ткаченко",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q2",
              text: String(localized: "inspiration.q2.text"),
              author: "Маргарита Фомичёва",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q3",
              text: String(localized: "inspiration.q3.text"),
              author: "Лариса Фомина",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q4",
              text: String(localized: "inspiration.q4.text"),
              author: "Светлана Большакова",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q5",
              text: String(localized: "inspiration.q5.text"),
              author: "Розалия Левина",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q6",
              text: String(localized: "inspiration.q6.text"),
              author: "Зоя Репина",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q7",
              text: String(localized: "inspiration.q7.text"),
              author: "Наталия Нищева",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q8",
              text: String(localized: "inspiration.q8.text"),
              author: "Елена Косинова",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q9",
              text: String(localized: "inspiration.q9.text"),
              author: "Вера Цвынтарная",
              role: String(localized: "inspiration.role.methodist")),
        .init(id: "q10",
              text: String(localized: "inspiration.q10.text"),
              author: "Ольга Громова",
              role: String(localized: "inspiration.role.methodist"))
    ]
}

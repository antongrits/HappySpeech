import Foundation

// MARK: - WeeklyParentTipModels

/// Модели «Совет недели». Совет — методический контент (`WeeklyParentTipContent`),
/// выбирается интерактором по номеру календарной недели.
enum WeeklyParentTipModels {

    struct Tip: Equatable {
        let id: String
        let title: String
        let bodyParagraphs: [String]
        let bulletPoints: [String]
        let authorName: String
        let authorRole: String
    }

    struct ViewState: Equatable {
        var tip: Tip
        /// Подпись недели (например «Неделя 21»), вычисляется из календаря.
        var weekLabel: String
    }
}

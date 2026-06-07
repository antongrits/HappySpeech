import Foundation

// MARK: - VisualVocabularyFlipModels

/// Компактный VIP-модуль (@Observable Interactor + View) — реализация полная.
enum VisualVocabularyFlipModels {

    struct Card: Identifiable, Hashable {
        let id: UUID
        let word: String
        let targetSound: String
        let symbol: String
    }

    enum SoundFilter: String, CaseIterable, Identifiable, Hashable {
        case all = "Все"
        case s = "С"
        case sh = "Ш"
        case r = "Р"
        case zh = "Ж"
        case k = "К"

        var id: String { rawValue }
    }

    static let deck: [Card] = [
        // С (5)
        .init(id: UUID(), word: "сова",   targetSound: "С", symbol: "bird.fill"),
        .init(id: UUID(), word: "снег",   targetSound: "С", symbol: "snowflake"),
        .init(id: UUID(), word: "сумка",  targetSound: "С", symbol: "bag.fill"),
        .init(id: UUID(), word: "санки",  targetSound: "С", symbol: "snowflake.circle"),
        .init(id: UUID(), word: "сок",    targetSound: "С", symbol: "cup.and.saucer.fill"),
        // Ш (4)
        .init(id: UUID(), word: "шар",    targetSound: "Ш", symbol: "circle.fill"),
        .init(id: UUID(), word: "шапка",  targetSound: "Ш", symbol: "graduationcap.fill"),
        .init(id: UUID(), word: "шкаф",   targetSound: "Ш", symbol: "rectangle.split.3x1"),
        .init(id: UUID(), word: "шуба",   targetSound: "Ш", symbol: "tshirt.fill"),
        // Р (5)
        .init(id: UUID(), word: "роза",   targetSound: "Р", symbol: "flower"),
        .init(id: UUID(), word: "рыба",   targetSound: "Р", symbol: "fish.fill"),
        .init(id: UUID(), word: "ракета", targetSound: "Р", symbol: "airplane"),
        .init(id: UUID(), word: "ручка",  targetSound: "Р", symbol: "pencil"),
        .init(id: UUID(), word: "рука",   targetSound: "Р", symbol: "hand.raised.fill"),
        // Ж (3)
        .init(id: UUID(), word: "жук",    targetSound: "Ж", symbol: "ladybug.fill"),
        .init(id: UUID(), word: "жираф",  targetSound: "Ж", symbol: "pawprint.fill"),
        .init(id: UUID(), word: "жёлудь", targetSound: "Ж", symbol: "leaf.fill"),
        // К (3)
        .init(id: UUID(), word: "кот",    targetSound: "К", symbol: "cat.fill"),
        .init(id: UUID(), word: "книга",  targetSound: "К", symbol: "book.fill"),
        .init(id: UUID(), word: "кубик",  targetSound: "К", symbol: "cube.fill")
    ]
}

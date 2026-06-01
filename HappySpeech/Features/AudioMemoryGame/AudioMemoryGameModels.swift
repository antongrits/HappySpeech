import Foundation

// MARK: - AudioMemoryGameModels

/// Модели «Звукового мемори».
///
/// Колода строится из реальных слов рабочих звуков ребёнка
/// (`KidWordContentProvider`): каждое слово даётся парой карточек. Ребёнок ищет
/// совпадения по слову/звуку. Удачные пары идут в outcome планировщика.
enum AudioMemoryGameModels {

    struct Tile: Identifiable, Hashable {
        let id: UUID
        /// Ключ пары — слово (отображается на карточке).
        let pairKey: String
        /// Группа звука слова («С», «Р» …) — для outcome.
        let soundFamily: String
        var isFlipped: Bool
        var isMatched: Bool
    }

    /// Сколько пар в колоде (карточек = pairCount × 2).
    static let pairCount = 6

    /// Колода из набора слов: каждое слово → две карточки, всё перемешано.
    static func makeDeck(words: [KidWordContentProvider.GameWord]) -> [Tile] {
        let chosen = Array(words.prefix(pairCount))
        var tiles: [Tile] = chosen.flatMap { word in
            [
                Tile(id: UUID(), pairKey: word.text, soundFamily: word.soundFamily ?? "С",
                     isFlipped: false, isMatched: false),
                Tile(id: UUID(), pairKey: word.text, soundFamily: word.soundFamily ?? "С",
                     isFlipped: false, isMatched: false)
            ]
        }
        tiles.shuffle()
        return tiles
    }
}

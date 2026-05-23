import Foundation

// MARK: - AudioMemoryGameModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum AudioMemoryGameModels {

    struct Tile: Identifiable, Hashable {
        let id: UUID
        let pairKey: String
        var isFlipped: Bool
        var isMatched: Bool
    }

    static let pairKeys: [String] = ["С", "Ш", "Р", "Ж", "К", "З"]

    static func makeShuffledDeck() -> [Tile] {
        var tiles: [Tile] = pairKeys.flatMap { key in
            [
                Tile(id: UUID(), pairKey: key, isFlipped: false, isMatched: false),
                Tile(id: UUID(), pairKey: key, isFlipped: false, isMatched: false)
            ]
        }
        tiles.shuffle()
        return tiles
    }
}

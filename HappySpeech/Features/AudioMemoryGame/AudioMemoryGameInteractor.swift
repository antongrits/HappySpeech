import Foundation
import OSLog

// MARK: - AudioMemoryGameInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class AudioMemoryGameInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AudioMemoryGame"
    )

    let childId: String
    var tiles: [AudioMemoryGameModels.Tile]
    var firstPickIndex: Int?
    var moves: Int = 0
    var matchedCount: Int = 0
    var isResolving: Bool = false

    init(childId: String) {
        self.childId = childId
        self.tiles = AudioMemoryGameModels.makeShuffledDeck()
    }

    var isComplete: Bool {
        matchedCount == AudioMemoryGameModels.pairKeys.count
    }

    func tap(at index: Int) {
        guard !isResolving,
              index < tiles.count,
              !tiles[index].isFlipped,
              !tiles[index].isMatched else { return }

        tiles[index].isFlipped = true

        if let first = firstPickIndex {
            moves += 1
            if tiles[first].pairKey == tiles[index].pairKey {
                tiles[first].isMatched = true
                tiles[index].isMatched = true
                matchedCount += 1
                firstPickIndex = nil
                Self.logger.info("Matched \(self.tiles[index].pairKey, privacy: .public)")
            } else {
                isResolving = true
                Task {
                    try? await Task.sleep(for: .milliseconds(700))
                    await MainActor.run {
                        self.tiles[first].isFlipped = false
                        self.tiles[index].isFlipped = false
                        self.firstPickIndex = nil
                        self.isResolving = false
                    }
                }
            }
        } else {
            firstPickIndex = index
        }
    }

    func restart() {
        tiles = AudioMemoryGameModels.makeShuffledDeck()
        firstPickIndex = nil
        moves = 0
        matchedCount = 0
        isResolving = false
    }
}

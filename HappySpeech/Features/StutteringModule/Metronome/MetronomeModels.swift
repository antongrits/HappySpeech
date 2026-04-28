import Foundation

// MARK: - MetronomeGameState

enum MetronomeGameState: Sendable, Equatable {
    case idle
    case running(syllableIndex: Int)
    case syllableDetected(index: Int)
    case wordComplete(successCount: Int, totalSyllables: Int)
    case roundComplete(wordsCompleted: Int, totalWords: Int)
}

import Foundation
import OSLog

// MARK: - WordOfTheDayInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class WordOfTheDayInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordOfTheDay"
    )

    let childId: String
    var card: WordOfTheDayModels.Card
    var phase: WordOfTheDayModels.RecordingPhase = .idle

    init(childId: String) {
        self.childId = childId
        self.card = WordOfTheDayModels.wordForToday()
    }

    func startRecording() {
        phase = .recording
        // MVP: имитация скоринга через 1.5 сек.
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            await MainActor.run {
                let stars = Int.random(in: 2...3)
                self.phase = .scored(stars)
                Self.logger.info("Recorded WOTD '\(self.card.word, privacy: .public)' → ★\(stars)")
            }
        }
    }

    func reset() {
        phase = .idle
    }
}

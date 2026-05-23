import Foundation
import OSLog

// MARK: - LyalyaPersonalCoachInteractor

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
@MainActor
@Observable
final class LyalyaPersonalCoachInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LyalyaPersonalCoach"
    )

    let childId: String
    let rounds: [LyalyaPersonalCoachModels.Round] = LyalyaPersonalCoachModels.seedRounds
    var currentIndex: Int = 0
    var reaction: LyalyaPersonalCoachModels.Reaction = .none
    var correctCount: Int = 0

    init(childId: String) {
        self.childId = childId
    }

    var current: LyalyaPersonalCoachModels.Round? {
        guard currentIndex < rounds.count else { return nil }
        return rounds[currentIndex]
    }

    var isFinished: Bool { currentIndex >= rounds.count }

    func answer(_ index: Int) {
        guard let round = current else { return }
        if index == round.correctIndex {
            reaction = .correct
            correctCount += 1
            Self.logger.info("Coach round \(round.id) — correct")
        } else {
            reaction = .tryAgain
            Self.logger.info("Coach round \(round.id) — wrong")
        }
    }

    func next() {
        currentIndex += 1
        reaction = .none
    }
}

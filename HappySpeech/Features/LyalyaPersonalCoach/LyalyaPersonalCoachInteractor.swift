import Foundation
import OSLog

// MARK: - LyalyaPersonalCoachInteractor

/// Бизнес-логика «Личный коуч Ляли».
///
/// Раунды собираются `LyalyaPersonalCoachWorker` персонально под рабочие звуки
/// ребёнка (вопросы о реальных словах его рабочих групп). Результаты
/// фиксируются в интервальном планировщике повторов; по завершении — SM-2.
/// Без worker (Preview/тесты) экран показывает пустой загруженный список.
@MainActor
@Observable
final class LyalyaPersonalCoachInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LyalyaPersonalCoach"
    )

    let childId: String
    var rounds: [LyalyaPersonalCoachModels.Round] = []
    var currentIndex: Int = 0
    var reaction: LyalyaPersonalCoachModels.Reaction = .none
    var correctCount: Int = 0
    var isLoaded: Bool = false

    private let worker: (any LyalyaPersonalCoachWorkerProtocol)?
    private let adaptivePlanner: (any AdaptivePlannerService)?

    init(
        childId: String,
        worker: (any LyalyaPersonalCoachWorkerProtocol)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.adaptivePlanner = adaptivePlanner
    }

    var current: LyalyaPersonalCoachModels.Round? {
        guard currentIndex < rounds.count else { return nil }
        return rounds[currentIndex]
    }

    var isFinished: Bool { isLoaded && !rounds.isEmpty && currentIndex >= rounds.count }

    var isEmpty: Bool { isLoaded && rounds.isEmpty }

    func load() async {
        guard let worker else {
            isLoaded = true
            return
        }
        rounds = await worker.buildRounds(childId: childId)
        currentIndex = 0
        correctCount = 0
        reaction = .none
        isLoaded = true
        Self.logger.info("loaded \(self.rounds.count, privacy: .public) rounds")
    }

    func answer(_ index: Int) {
        guard let round = current else { return }
        let correct = index == round.correctIndex
        if correct {
            reaction = .correct
            correctCount += 1
            Self.logger.info("Coach round \(round.id) — correct")
        } else {
            reaction = .tryAgain
            Self.logger.info("Coach round \(round.id) — wrong")
        }
        recordOutcome(round: round, correct: correct)
    }

    func next() {
        currentIndex += 1
        reaction = .none
        if isFinished {
            recordSession()
        }
    }

    func restart() async {
        await load()
    }

    // MARK: - Persistence

    private func recordOutcome(round: LyalyaPersonalCoachModels.Round, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let sound = round.options.indices.contains(round.correctIndex)
            ? round.options[round.correctIndex]
            : "С"
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "coach-\(round.id)",
                sound: sound,
                correct: correct
            )
        }
    }

    private func recordSession() {
        guard let planner = adaptivePlanner, !childId.isEmpty, !rounds.isEmpty else { return }
        let rate = Double(correctCount) / Double(rounds.count)
        let quality = SM2Quality.fromSuccessRate(rate)
        let sound = rounds.first.flatMap { round -> String? in
            round.options.indices.contains(round.correctIndex) ? round.options[round.correctIndex] : nil
        } ?? "С"
        Task { [weak self] in
            guard let self else { return }
            do {
                try await planner.recordSessionResult(
                    childId: self.childId,
                    soundTarget: sound,
                    qualityScore: quality
                )
            } catch {
                Self.logger.error("recordSession failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

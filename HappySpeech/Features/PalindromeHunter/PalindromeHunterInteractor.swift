import Foundation
import OSLog

// MARK: - PalindromeHunterInteractor

/// VIP-модуль игры «Охотник за палиндромами» (@Observable Interactor + View).
///
/// По завершении раундов сохраняет реальную сессию через
/// `SessionPersistenceCoordinating` (минуты практики, серия дней, агрегаты профиля).
/// Счёт честный: `correctAttempts` = угаданные палиндромы из `totalAttempts` раундов.
/// Без координатора/childId (Preview/тесты) — персистентность пропускается.
@MainActor
@Observable
final class PalindromeHunterInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PalindromeHunter"
    )

    let childId: String
    var state: PalindromeHunterModels.ViewState

    private let sessionPersistence: (any SessionPersistenceCoordinating)?
    private let sessionId = UUID().uuidString
    private var sessionStart = Date()
    private var didPersistSession = false

    init(
        childId: String,
        sessionPersistence: (any SessionPersistenceCoordinating)? = nil
    ) {
        self.childId = childId
        self.sessionPersistence = sessionPersistence
        self.state = .initial
    }

    func pick(_ word: String) -> Bool {
        guard let round = state.currentRound else { return false }
        let isCorrect = (word == round.palindrome)
        if isCorrect {
            state.correctCount += 1
        }
        state.currentRoundIndex = min(state.currentRoundIndex + 1, state.rounds.count)
        Self.logger.info("pick \(word, privacy: .public) correct=\(isCorrect)")

        // Раунды кончились — фиксируем реальную сессию (идемпотентно).
        if state.currentRound == nil {
            Task { [weak self] in await self?.persistSessionIfNeeded() }
        }
        return isCorrect
    }

    func reset() {
        state = .initial
        sessionStart = Date()
        didPersistSession = false
    }

    /// Сохраняет завершённую сессию: реальные минуты + честный счёт раундов.
    /// Ровно один раз на прохождение; без координатора/childId — no-op.
    private func persistSessionIfNeeded() async {
        guard !didPersistSession, let sessionPersistence, !childId.isEmpty else { return }
        didPersistSession = true

        let dto = SessionDTO(
            id: sessionId,
            childId: childId,
            date: Date(),
            templateType: TemplateType.sorting.rawValue,
            targetSound: "",
            stage: CorrectionStage.wordInit.rawValue,
            durationSeconds: Int(Date().timeIntervalSince(sessionStart)),
            totalAttempts: state.rounds.count,
            correctAttempts: state.correctCount,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
        await sessionPersistence.persistAndSync(dto)
        Self.logger.info("PalindromeHunter session persisted correct=\(self.state.correctCount)/\(self.state.rounds.count)")
    }
}

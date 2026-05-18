import Foundation
import OSLog

// MARK: - ProsodyBusinessLogic

@MainActor
protocol ProsodyBusinessLogic: AnyObject {
    func start(request: ProsodyModels.Start.Request) async
    func answer(request: ProsodyModels.Answer.Request) async
}

// MARK: - ProsodyDataStore

@MainActor
protocol ProsodyDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [ProsodyRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
}

// MARK: - ProsodyInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 1 «Голосовые краски».
//
// Бизнес-логика просодии: ведёт прогресс по раундам, проверяет ответ в
// зависимости от этапа. На этапе различения сравнивается выбор типа
// интонации; на этапах повтора/продуцирования засчитывается голосовая
// попытка (без жёсткой оценки — методически верно для просодики, где
// важна сама практика мелодики).

@MainActor
final class ProsodyInteractor: ProsodyBusinessLogic, ProsodyDataStore {

    // MARK: - DataStore

    var childId: String
    var rounds: [ProsodyRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0

    // MARK: - VIP

    var presenter: (any ProsodyPresentationLogic)?

    // MARK: - Deps

    private let worker: any ProsodyWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Prosody.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any ProsodyWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Start

    func start(request: ProsodyModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(childId: request.childId)
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        Self.logger.debug("Started prosody: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Answer

    func answer(request: ProsodyModels.Answer.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("Answer called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let wasCorrect = Self.isCorrect(request: request, round: round)
        if wasCorrect {
            correctCount += 1
            hapticService.notification(.success)
        } else {
            hapticService.notification(.warning)
        }

        currentIndex += 1
        let isFinished = currentIndex >= rounds.count
        let nextRound = isFinished ? nil : rounds[currentIndex]

        let response = ProsodyModels.Answer.Response(
            wasCorrect: wasCorrect,
            isFinished: isFinished,
            nextRound: nextRound,
            nextRoundIndex: isFinished ? nil : currentIndex,
            correctCount: correctCount,
            totalRounds: rounds.count
        )
        await presenter?.presentAnswer(response: response)
    }

    // MARK: - Answer evaluation

    /// Возвращает 0-based индекс правильного варианта для этапа различения.
    /// Порядок вариантов согласован с `IntonationType.allCases`.
    static func correctOptionIndex(for round: ProsodyRound) -> Int {
        IntonationType.allCases.firstIndex(of: round.phrase.intonation) ?? 0
    }

    /// Проверяет ответ. На этапе различения — по выбранному типу интонации;
    /// на этапах повтора/продуцирования — по факту голосовой попытки.
    static func isCorrect(
        request: ProsodyModels.Answer.Request,
        round: ProsodyRound
    ) -> Bool {
        switch round.stage {
        case .discriminate:
            return request.optionIndex == correctOptionIndex(for: round)
        case .imitate, .produce:
            return request.voiceAttempted
        }
    }
}

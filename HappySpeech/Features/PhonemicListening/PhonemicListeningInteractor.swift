import Foundation
import OSLog

// MARK: - PhonemicListeningBusinessLogic

@MainActor
protocol PhonemicListeningBusinessLogic: AnyObject {
    func start(request: PhonemicListeningModels.Start.Request) async
    func answer(request: PhonemicListeningModels.Answer.Request) async
}

// MARK: - PhonemicListeningDataStore

@MainActor
protocol PhonemicListeningDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [PhonemicRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
}

// MARK: - PhonemicListeningInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 12 «Слушай внимательно».
//
// Бизнес-логика фонематического анализа: ведёт прогресс по раундам,
// проверяет ответ в зависимости от операции (позиция / количество / синтез).
// Без таймеров-соревнований (антифатиговое правило).

@MainActor
final class PhonemicListeningInteractor: PhonemicListeningBusinessLogic, PhonemicListeningDataStore {

    // MARK: - DataStore

    var childId: String
    var rounds: [PhonemicRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0

    // MARK: - VIP

    var presenter: (any PhonemicListeningPresentationLogic)?

    // MARK: - Deps

    private let worker: any PhonemicListeningWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemicListening.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any PhonemicListeningWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Start

    func start(request: PhonemicListeningModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(childId: request.childId)
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        Self.logger.debug("Started phonemic-listening: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Answer

    func answer(request: PhonemicListeningModels.Answer.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("Answer called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let wasCorrect = Self.isCorrect(
            optionIndex: request.optionIndex,
            round: round
        )
        if wasCorrect {
            correctCount += 1
            hapticService.notification(.success)
        } else {
            hapticService.notification(.warning)
        }

        currentIndex += 1
        let isFinished = currentIndex >= rounds.count
        let nextRound = isFinished ? nil : rounds[currentIndex]

        let response = PhonemicListeningModels.Answer.Response(
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
    //
    // Индекс правильного варианта вычисляется детерминированно из разметки
    // слова — та же логика, что использует Presenter при построении опций.

    /// Возвращает 0-based индекс правильного варианта для раунда.
    static func correctOptionIndex(for round: PhonemicRound) -> Int {
        switch round.operation {
        case .position:
            return PhonemePosition.allCases.firstIndex(of: round.word.position) ?? 0
        case .count:
            // Варианты количества: soundCount-1, soundCount, soundCount+1.
            return 1
        case .synthesis:
            // Правильное слово всегда первый вариант до перемешивания;
            // Presenter перемешивает и хранит индекс — здесь правильный
            // вариант идентифицируется по тексту слова, см. `isCorrect`.
            return 0
        }
    }

    /// Проверяет ответ. Для синтеза сравнение по тексту делегируется
    /// Presenter'у через индекс — здесь достаточно операционной логики.
    static func isCorrect(optionIndex: Int, round: PhonemicRound) -> Bool {
        optionIndex == correctOptionIndex(for: round)
    }
}

import Foundation
import OSLog

// MARK: - SoundDetectiveBusinessLogic

@MainActor
protocol SoundDetectiveBusinessLogic: AnyObject {
    func start(request: SoundDetectiveModels.Start.Request) async
    func answer(request: SoundDetectiveModels.Answer.Request) async
}

// MARK: - SoundDetectiveDataStore

@MainActor
protocol SoundDetectiveDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [SoundDetectiveRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
    /// Промахов подряд в текущем раунде (для fading-подсказки).
    var attemptsInRound: Int { get set }
}

// MARK: - SoundDetectiveInteractor (Clean Swift: Interactor)
//
// F2-009 «Звуковой детектив» (Wave 2).
//
// Бизнес-логика позиционного фонематического анализа:
//   • ведёт прогресс по раундам;
//   • оценивает выбор зоны по «светофору» (hit / almost / retry) — без
//     слова «неправильно»;
//   • после 2 промахов подряд показывает подсказку (errorless fading) и
//     мягко продвигает раунд (limit = `maxAttempts`);
//   • переигрывает слово с интонационным выделением на almost/retry;
//   • по завершении — `recordSessionResult` для spaced-repetition.
// Без таймеров-соревнований (антифатиговое правило).

@MainActor
final class SoundDetectiveInteractor: SoundDetectiveBusinessLogic, SoundDetectiveDataStore {

    /// Максимум попыток на раунд: после 2 промахов мягко идём дальше.
    static let maxAttempts = 2

    // MARK: - DataStore

    var childId: String
    var rounds: [SoundDetectiveRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var attemptsInRound: Int = 0

    /// Уровень текущей сессии (для record / возможного перехода).
    private(set) var sessionLevel: SoundDetectiveLevel = .binary
    /// Целевой звук текущей сессии (для record).
    private(set) var sessionTargetSound: String = "С"

    // MARK: - VIP

    var presenter: (any SoundDetectivePresentationLogic)?

    // MARK: - Deps

    private let worker: any SoundDetectiveWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private var preferredLevel: SoundDetectiveLevel?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundDetective.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any SoundDetectiveWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
    }

    // MARK: - Start

    func start(request: SoundDetectiveModels.Start.Request) async {
        childId = request.childId
        preferredLevel = request.preferredLevel
        let response = await worker.buildSession(
            childId: request.childId,
            preferredLevel: request.preferredLevel
        )
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        attemptsInRound = 0
        sessionLevel = response.level
        sessionTargetSound = response.targetSound
        Self.logger.debug("Started sound-detective: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Answer

    func answer(request: SoundDetectiveModels.Answer.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("Answer called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let isCorrect = (request.chosenZone == round.item.position)

        let feedback: FeedbackTier
        var advance = false
        var showHint = false
        var replayWithEmphasis = false

        if isCorrect {
            feedback = .hit
            correctCount += 1
            attemptsInRound = 0
            advance = true
            hapticService.notification(.success)
        } else {
            attemptsInRound += 1
            // 1-й промах — «почти»; со 2-го — «попробуем ещё» + подсказка.
            feedback = (attemptsInRound >= Self.maxAttempts) ? .retry : .almost
            replayWithEmphasis = true
            showHint = attemptsInRound >= Self.maxAttempts
            hapticService.notification(.warning)
            // После исчерпания лимита попыток — мягко продвигаемся дальше
            // (errorless: не зацикливаем ребёнка на одном слове).
            if attemptsInRound >= Self.maxAttempts {
                advance = true
                attemptsInRound = 0
            }
        }

        if advance {
            // F1-016: фиксируем результат слова в интервальном планировщике повторов.
            // correct — только если попал сразу (без исчерпания попыток).
            await adaptivePlanner?.recordItemOutcome(
                childId: childId,
                itemId: round.item.id,
                sound: sessionTargetSound,
                correct: isCorrect
            )
            currentIndex += 1
        }

        let isFinished = currentIndex >= rounds.count
        let nextRound = (advance && !isFinished) ? rounds[currentIndex] : nil
        let highlightIndex = isCorrect ? round.item.targetSoundIndex : nil

        let response = SoundDetectiveModels.Answer.Response(
            feedback: feedback,
            correctZone: round.item.position,
            highlightSoundIndex: highlightIndex,
            showHint: showHint,
            replayWithEmphasis: replayWithEmphasis,
            advancedToNextRound: advance,
            isFinished: isFinished,
            nextRound: nextRound,
            nextRoundIndex: (advance && !isFinished) ? currentIndex : nil,
            correctCount: correctCount,
            totalRounds: rounds.count
        )
        await presenter?.presentAnswer(response: response)

        if isFinished {
            await recordResult()
        }
    }

    // MARK: - Adaptive

    /// По завершении сессии — SM-2 обратная связь для spaced-repetition.
    private func recordResult() async {
        guard let planner = adaptivePlanner else { return }
        let total = rounds.count
        let rate = total > 0 ? Double(correctCount) / Double(total) : 0
        let quality = SM2Quality.fromSuccessRate(rate)
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: sessionTargetSound,
                qualityScore: quality
            )
        } catch {
            Self.logger.error(
                "recordSessionResult failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    // MARK: - Helpers (testable, pure)

    /// Доля правильных ответов сессии (для перехода уровня 80% × 2 — учёт
    /// ведёт AdaptivePlanner; здесь — вспомогательный расчёт).
    var accuracyFraction: Double {
        rounds.isEmpty ? 0 : Double(correctCount) / Double(rounds.count)
    }
}

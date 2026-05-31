import Foundation
import OSLog

// MARK: - WhoseTailBusinessLogic

@MainActor
protocol WhoseTailBusinessLogic: AnyObject {
    func start(request: WhoseTailModels.Start.Request) async
    func answer(request: WhoseTailModels.Answer.Request) async
}

// MARK: - WhoseTailDataStore

@MainActor
protocol WhoseTailDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [WhoseRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
    /// Промахов подряд в текущем раунде (для fading-подсказки).
    var attemptsInRound: Int { get set }
}

// MARK: - WhoseTailInteractor (Clean Swift: Interactor)
//
// F2-006 «Чей хвост / чей домик» (Wave 2).
//
// Бизнес-логика словообразования прилагательных:
//   • ведёт прогресс по раундам;
//   • сверяет выбранную карточку с правильным сопоставлением (correctOptionId);
//   • оценивает по «светофору» (hit / almost / retry) — без «неправильно»;
//   • после 2 промахов подряд показывает подсказку (errorless fading) и мягко
//     продвигает раунд (limit = `maxAttempts`);
//   • на попадание отдаёт целевую форму прилагательного для озвучки (закрепление
//     по слуху — методическое ядро словообразования);
//   • для 7–8 лет — мягкая просьба «скажи, чей хвост?» (без оценки произношения),
//     кроме relativeMaterial (там форма-конструкция «Стол деревянный»);
//   • по завершении — `recordSessionResult` (soundTarget «грамматика.притяжат»)
//     для spaced-repetition (SM-2).
// Без таймеров-соревнований (антифатиговое правило).
//
// `FeedbackTier` — общий тип (SoundDetectiveModels).

@MainActor
final class WhoseTailInteractor: WhoseTailBusinessLogic, WhoseTailDataStore {

    /// Максимум попыток на раунд: после 2 промахов мягко идём дальше.
    static let maxAttempts = 2
    /// С какого возраста просим повторить форму вслух.
    static let verbalizeMinAge = 7

    // MARK: - DataStore

    var childId: String
    var rounds: [WhoseRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var attemptsInRound: Int = 0

    /// «Звук» сессии для record («грамматика.притяжат»).
    private(set) var sessionSoundTarget: String = "грамматика.притяжат"
    /// Возраст ребёнка (для гейта вербализации).
    private(set) var childAge: Int = 6

    // MARK: - VIP

    var presenter: (any WhoseTailPresentationLogic)?

    // MARK: - Deps

    private let worker: any WhoseTailWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WhoseTail.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any WhoseTailWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
    }

    // MARK: - Start

    func start(request: WhoseTailModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(
            childId: request.childId,
            preferredSubtask: request.preferredSubtask
        )
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        attemptsInRound = 0
        sessionSoundTarget = response.soundTarget
        childAge = response.childAge
        Self.logger.debug("Started whose-tail: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Answer

    func answer(request: WhoseTailModels.Answer.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("Answer called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let correctId = round.correctOptionId ?? round.options.first?.id ?? ""
        let isCorrect = (request.chosenOptionId == correctId)

        let feedback: FeedbackTier
        var advance = false
        var showHint = false
        var askToRepeat = false

        if isCorrect {
            feedback = .hit
            correctCount += 1
            attemptsInRound = 0
            advance = true
            // Вербализация «скажи, чей хвост?» — 7–8 лет, не для относительных
            // (там форма-конструкция «Стол деревянный», не притяжательная).
            askToRepeat = (childAge >= Self.verbalizeMinAge && round.subtask != .relativeMaterial)
            hapticService.notification(.success)
        } else {
            attemptsInRound += 1
            // Никогда «неправильно». Со 2-го промаха — «давай вместе» + подсказка;
            // до этого — мягкое `.almost` (errorless fading).
            feedback = (attemptsInRound >= Self.maxAttempts) ? .retry : .almost
            hapticService.notification(.warning)
            // После исчерпания лимита попыток — мягко идём дальше (errorless).
            if attemptsInRound >= Self.maxAttempts {
                advance = true
                showHint = true
                attemptsInRound = 0
            }
        }

        if advance {
            // F1-016: результат слова в интервальный планировщик повторов.
            await adaptivePlanner?.recordItemOutcome(
                childId: childId,
                itemId: round.id,
                sound: sessionSoundTarget,
                correct: isCorrect
            )
            currentIndex += 1
        }

        let isFinished = currentIndex >= rounds.count
        let nextRound = (advance && !isFinished) ? rounds[currentIndex] : nil
        // Целевую форму озвучиваем на hit (закрепление по слуху).
        let spokenForm = isCorrect ? round.spokenForm : ""

        let response = WhoseTailModels.Answer.Response(
            feedback: feedback,
            correctOptionId: correctId,
            spokenForm: spokenForm,
            askToRepeat: askToRepeat,
            hintOptionId: showHint ? correctId : nil,
            showHint: showHint,
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
                soundTarget: sessionSoundTarget,
                qualityScore: quality
            )
        } catch {
            Self.logger.error(
                "recordSessionResult failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Доля правильных ответов сессии (для перехода уровня 80% × 2 — учёт ведёт
    /// AdaptivePlanner; здесь — вспомогательный расчёт).
    var accuracyFraction: Double {
        rounds.isEmpty ? 0 : Double(correctCount) / Double(rounds.count)
    }
}

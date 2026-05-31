import Foundation
import OSLog

// MARK: - WordFormationBusinessLogic

@MainActor
protocol WordFormationBusinessLogic: AnyObject {
    func start(request: WordFormationModels.Start.Request) async
    func answer(request: WordFormationModels.Answer.Request) async
}

// MARK: - WordFormationDataStore

@MainActor
protocol WordFormationDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [FormationRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
    /// Промахов подряд в текущем раунде (для fading-подсказки).
    var attemptsInRound: Int { get set }
}

// MARK: - WordFormationInteractor (Clean Swift: Interactor)
//
// F2-007 «Назови ласково / Один-много-нет» (Wave 2).
//
// Бизнес-логика словообразования/словоизменения:
//   • ведёт прогресс по раундам;
//   • сверяет выбранный вариант с нормативной формой (correctOptionId);
//   • оценивает по «светофору» (hit / almost / retry) — без «неправильно»;
//     при выборе nearMiss-дистрактора («стулы») — мягкий `.almost`, при грубой
//     ошибке («стулья» в manyOf) — тоже `.almost` (никогда «неправильно»), но
//     различение служит для тёплого тона реплики и спец-выделения формы;
//   • после 2 промахов подряд показывает подсказку (errorless fading) и мягко
//     продвигает раунд (limit = `maxAttempts`);
//   • на попадание отдаёт нормативную форму для озвучки (закрепление по слуху —
//     методическое ядро);
//   • для 7–8 лет — мягкая просьба «повтори форму» (без оценки произношения);
//   • по завершении — `recordSessionResult` для spaced-repetition.
// Без таймеров-соревнований (антифатиговое правило).
//
// `FeedbackTier` — общий тип (SoundDetectiveModels).

@MainActor
final class WordFormationInteractor: WordFormationBusinessLogic, WordFormationDataStore {

    /// Максимум попыток на раунд: после 2 промахов мягко идём дальше.
    static let maxAttempts = 2
    /// С какого возраста просим повторить форму вслух.
    static let verbalizeMinAge = 7

    // MARK: - DataStore

    var childId: String
    var rounds: [FormationRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var attemptsInRound: Int = 0

    /// «Звук» сессии для record («грамматика.словообр»).
    private(set) var sessionSoundTarget: String = "грамматика.словообр"
    /// Возраст ребёнка (для гейта вербализации).
    private(set) var childAge: Int = 6

    // MARK: - VIP

    var presenter: (any WordFormationPresentationLogic)?

    // MARK: - Deps

    private let worker: any WordFormationWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordFormation.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any WordFormationWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
    }

    // MARK: - Start

    func start(request: WordFormationModels.Start.Request) async {
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
        Self.logger.debug("Started word-formation: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Answer

    func answer(request: WordFormationModels.Answer.Request) async {
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
            askToRepeat = (childAge >= Self.verbalizeMinAge)
            hapticService.notification(.success)
        } else {
            attemptsInRound += 1
            // Никогда «неправильно». Со 2-го промаха — «попробуем ещё» +
            // подсказка; до этого — всегда `.almost` (мягко), независимо от
            // близости ошибки. Различение nearMiss/грубая влияет на тон реплики
            // Presenter'а, но обе ветки остаются `.almost` (errorless).
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
            currentIndex += 1
        }

        let isFinished = currentIndex >= rounds.count
        let nextRound = (advance && !isFinished) ? rounds[currentIndex] : nil
        // Нормативную форму озвучиваем на hit (закрепление по слуху).
        let spokenForm = isCorrect ? round.spokenForm : ""
        // Близкая ли ошибка (для тёплой дифференциации тона на almost/retry).
        let wasNearMiss = !isCorrect && isNearMiss(optionId: request.chosenOptionId, in: round)

        let response = WordFormationModels.Answer.Response(
            feedback: feedback,
            correctOptionId: correctId,
            spokenForm: spokenForm,
            chosenWasNearMiss: wasNearMiss,
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

    // MARK: - Helpers (testable, pure)

    /// Близкая ли это ошибка — выбранный вариант помечен `isNearMiss`
    /// (типичная детская ошибка «стулы»). Для тёплой дифференциации тона.
    func isNearMiss(optionId: String, in round: FormationRound) -> Bool {
        round.options.first { $0.id == optionId }?.isNearMiss ?? false
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

    /// Доля правильных ответов сессии (для перехода уровня 80% × 2 — учёт
    /// ведёт AdaptivePlanner; здесь — вспомогательный расчёт).
    var accuracyFraction: Double {
        rounds.isEmpty ? 0 : Double(correctCount) / Double(rounds.count)
    }
}

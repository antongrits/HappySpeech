import Foundation
import OSLog

// MARK: - ComprehensionDetectiveBusinessLogic

@MainActor
protocol ComprehensionDetectiveBusinessLogic: AnyObject {
    func start(request: ComprehensionDetectiveModels.Start.Request) async
    func pick(request: ComprehensionDetectiveModels.Pick.Request) async
}

// MARK: - ComprehensionDetectiveDataStore

@MainActor
protocol ComprehensionDetectiveDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [DetectiveRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
    /// Промахов подряд в текущем раунде (для fading-подсказки).
    var attemptsInRound: Int { get set }
}

// MARK: - ComprehensionDetectiveInteractor (Clean Swift: Interactor)
//
// v31 Волна B, Функция Ф.2 «Понимание-детектив» (F2-014).
//
// Бизнес-логика понимания устной инструкции (импрессивная речь):
//   • ведёт прогресс по раундам сессии;
//   • сверяет выбранную картинку с правильной и оценивает по «светофору»
//     (hit / almost / retry) — без слова «неправильно»;
//   • после 2 промахов подряд — errorless-подсказка (пульсация правильной
//     картинки + повтор инструкции медленнее/по частям) и мягкое продвижение;
//   • по завершении — `recordSessionResult` для spaced-repetition (SM-2);
//   • переход уровня: при доле ≥ 80% следующая сессия идёт на ступень выше
//     (через `recommendedNextTier`, в рамках возрастного гейта).
// Без таймеров-соревнований (антифатиговое правило).

@MainActor
final class ComprehensionDetectiveInteractor:
    ComprehensionDetectiveBusinessLogic, ComprehensionDetectiveDataStore {

    /// Максимум попыток на раунд: после 2 промахов мягко идём дальше.
    static let maxAttempts = 2
    /// Порог перехода на уровень выше (доля правильных за сессию).
    static let levelUpThreshold = 0.8

    // MARK: - DataStore

    var childId: String
    var rounds: [DetectiveRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var attemptsInRound: Int = 0

    /// «Звук»-цель сессии (для record).
    private(set) var sessionSoundTarget: String = "понимание речи"
    /// Ведущий уровень текущей сессии.
    private(set) var leadTier: GrammarTier = .simple
    private(set) var childAge: Int = 6

    // MARK: - VIP

    var presenter: (any ComprehensionDetectivePresentationLogic)?

    // MARK: - Deps

    private let worker: any ComprehensionDetectiveWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "ComprehensionDetective.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any ComprehensionDetectiveWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
    }

    // MARK: - Start

    func start(request: ComprehensionDetectiveModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(
            childId: request.childId,
            preferredTier: request.preferredTier
        )
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        attemptsInRound = 0
        sessionSoundTarget = response.soundTarget
        leadTier = response.leadTier
        childAge = response.childAge
        Self.logger.debug("Started detective: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)

        // Озвучиваем первую инструкцию.
        if let first = rounds.first {
            let text = first.item.instruction
            Task { @MainActor [worker] in
                await worker.voiceInstruction(text, slowly: false)
            }
        }
    }

    // MARK: - Pick

    func pick(request: ComprehensionDetectiveModels.Pick.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("pick called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let isCorrect = request.pictureId == round.item.correctPictureId

        let feedback: FeedbackTier
        var advance = false
        var showHint = false
        var replaySlowly = false

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
            replaySlowly = true
            showHint = attemptsInRound >= Self.maxAttempts
            hapticService.notification(.warning)
            // Errorless: после исчерпания лимита попыток мягко продвигаемся.
            if attemptsInRound >= Self.maxAttempts {
                advance = true
                attemptsInRound = 0
            }
        }

        if advance {
            currentIndex += 1
        }

        let isFinished = currentIndex >= rounds.count
        let nextRound = (advance && !isFinished) ? rounds[currentIndex] : nil

        let response = ComprehensionDetectiveModels.Pick.Response(
            feedback: feedback,
            pickedPictureId: request.pictureId,
            correctPictureId: round.item.correctPictureId,
            instruction: round.item.instruction,
            showHint: showHint,
            replaySlowly: replaySlowly,
            advancedToNextRound: advance,
            isFinished: isFinished,
            nextRound: nextRound,
            nextRoundIndex: (advance && !isFinished) ? currentIndex : nil,
            correctCount: correctCount,
            totalRounds: rounds.count
        )
        await presenter?.presentPick(response: response)

        // Errorless: переозвучить инструкцию (медленнее на подсказке).
        if replaySlowly {
            let text = round.item.instruction
            Task { @MainActor [worker] in
                await worker.voiceInstruction(text, slowly: showHint)
            }
        } else if let next = nextRound {
            // Озвучиваем следующую инструкцию.
            let text = next.item.instruction
            Task { @MainActor [worker] in
                await worker.voiceInstruction(text, slowly: false)
            }
        }

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

    // MARK: - Helpers (testable, pure)

    /// Доля правильных ответов сессии.
    var accuracyFraction: Double {
        rounds.isEmpty ? 0 : Double(correctCount) / Double(rounds.count)
    }

    /// Рекомендуемый уровень для следующей сессии: при доле ≥ 80% — ступень
    /// выше (в рамках возрастного гейта), иначе остаёмся на ведущем.
    var recommendedNextTier: GrammarTier {
        guard accuracyFraction >= Self.levelUpThreshold, let next = leadTier.next else {
            return leadTier
        }
        // Возрастной гейт capping (как в Worker).
        return min(next, ComprehensionDetectiveWorker.ageAllowedTier(age: childAge))
    }
}

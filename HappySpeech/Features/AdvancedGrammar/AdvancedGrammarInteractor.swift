import Foundation
import OSLog

// MARK: - AdvancedGrammarBusinessLogic

@MainActor
protocol AdvancedGrammarBusinessLogic: AnyObject {
    func start(_ request: AdvancedGrammarModels.Start.Request) async
    func playPrompt()
    func evaluate(_ request: AdvancedGrammarModels.Evaluate.Request)
    func advance() async
    func cancel()
}

// MARK: - AdvancedGrammarInteractor
//
// Бизнес-логика «Грамматического конструктора-2».
//   • start    — выбирает режим, определяет сложность по недавнему success rate
//                (через AdaptivePlanner), грузит раунды и подаёт первый.
//   • playPrompt — озвучка вопроса/целевой фразы голосом Ляли.
//   • evaluate — проверяет выбранный вариант против правильного. Верно →
//                полная фраза + success-хаптика, переход к следующему раунду
//                разрешён. Неверно → мягкая коррекция (без слова «неправильно»),
//                ребёнок остаётся на том же раунде и пробует снова (errorless).
//   • advance  — следующий раунд или завершение сессии.
//
// Скоринг: доля раундов, решённых с ПЕРВОЙ попытки (correctFirstTry / total).
// Результат сохраняется в AdaptivePlanner: пословный outcome на каждый раунд +
// SM-2 quality по итогу сессии.

@MainActor
final class AdvancedGrammarInteractor: AdvancedGrammarBusinessLogic {

    // MARK: VIP

    var presenter: (any AdvancedGrammarPresentationLogic)?

    // MARK: Deps

    private let childId: String
    private let mode: AdvancedGrammarMode
    private let content: AdvancedGrammarContentWorker
    private let feedback: AdvancedGrammarFeedbackWorker
    private let adaptivePlanner: (any AdaptivePlannerService)?
    /// Тестовый seam: фиксированная сложность (минует запрос к планировщику).
    private let forcedDifficulty: AdvancedGrammarDifficulty?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "AdvancedGrammarInteractor")

    // MARK: State

    private var difficulty: AdvancedGrammarDifficulty = .medium
    private var rounds: [AdvancedGrammarRound] = []
    private var roundIndex: Int = 0
    /// id раундов, на которых уже была ошибка (для отсечки очка с первой попытки).
    private var erroredRoundIds: Set<String> = []
    private var correctFirstTry: Int = 0
    private var isFinished: Bool = false

    // MARK: Init

    init(
        childId: String,
        mode: AdvancedGrammarMode,
        content: AdvancedGrammarContentWorker,
        feedback: AdvancedGrammarFeedbackWorker,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        forcedDifficulty: AdvancedGrammarDifficulty? = nil
    ) {
        self.childId = childId
        self.mode = mode
        self.content = content
        self.feedback = feedback
        self.adaptivePlanner = adaptivePlanner
        self.forcedDifficulty = forcedDifficulty
    }

    // MARK: - start

    func start(_ request: AdvancedGrammarModels.Start.Request) async {
        if let forcedDifficulty {
            difficulty = forcedDifficulty
        } else {
            difficulty = await resolveDifficulty()
        }
        rounds = await content.loadRounds(mode: mode, difficulty: difficulty)
        roundIndex = 0
        erroredRoundIds = []
        correctFirstTry = 0
        isFinished = false

        let modeName = mode.rawValue
        logger.info(
            "start mode=\(modeName, privacy: .public) diff=\(self.difficulty.rawValue, privacy: .public) rounds=\(self.rounds.count, privacy: .public)"
        )

        presenter?.presentStart(AdvancedGrammarModels.Start.Response(
            mode: mode,
            difficulty: difficulty,
            totalRounds: rounds.count,
            firstRound: rounds.first
        ))
        if let first = rounds.first {
            speak(first.hint)
        }
    }

    /// Сложность из недавнего результата по «грамматике-сложной». Если истории
    /// нет — medium (нейтральный старт).
    private func resolveDifficulty() async -> AdvancedGrammarDifficulty {
        guard let planner = adaptivePlanner else { return .medium }
        do {
            let route = try await planner.buildDailyRoute(for: childId)
            // Уровень усталости — мягкий регулятор: при усталости не усложняем
            // (даём лёгкий уровень), иначе — нейтральный medium.
            switch route.fatigueLevel {
            case .tired:
                return .easy
            case .normal, .fresh:
                return .medium
            }
        } catch {
            logger.debug("resolveDifficulty fallback medium: \(error.localizedDescription, privacy: .public)")
            return .medium
        }
    }

    // MARK: - playPrompt

    func playPrompt() {
        guard !isFinished, let round = currentRound else { return }
        // До ответа — озвучиваем вопрос/целевую фразу; после верного ответа —
        // полную фразу.
        speak(round.fullPhrase)
    }

    // MARK: - evaluate

    func evaluate(_ request: AdvancedGrammarModels.Evaluate.Request) {
        guard !isFinished, let round = currentRound else { return }
        let isCorrect = request.selectedChoiceId == round.correctChoiceId
        let firstAttempt = !erroredRoundIds.contains(round.id)

        feedback.selection()

        if isCorrect {
            if firstAttempt { correctFirstTry += 1 }
            feedback.success()
            speak(round.fullPhrase)
        } else {
            erroredRoundIds.insert(round.id)
            feedback.softError()
        }

        let correction = isCorrect ? "" : buildCorrection(round: round)

        presenter?.presentEvaluate(AdvancedGrammarModels.Evaluate.Response(
            isCorrect: isCorrect,
            selectedChoiceId: request.selectedChoiceId,
            correctChoiceId: round.correctChoiceId,
            fullPhrase: round.fullPhrase,
            correctionText: correction,
            isFirstAttempt: firstAttempt
        ))

        logger.debug("evaluate correct=\(isCorrect) firstAttempt=\(firstAttempt) round=\(round.id, privacy: .public)")
    }

    /// Мягкая коррекция без слова «неправильно»: подсказывает значение и
    /// направляет к правильной форме.
    private func buildCorrection(round: AdvancedGrammarRound) -> String {
        round.hint.isEmpty
            ? String(localized: "advancedGrammar.softCorrection.default",
                     defaultValue: "Послушай ещё раз и попробуй другое словечко.")
            : round.hint
    }

    // MARK: - advance

    func advance() async {
        guard !isFinished else { return }
        await recordRoundOutcome()

        let next = roundIndex + 1
        if next >= rounds.count {
            await complete()
            return
        }
        roundIndex = next
        let round = rounds[next]
        presenter?.presentRound(AdvancedGrammarModels.PresentRound.Response(
            round: round,
            roundIndex: next,
            totalRounds: rounds.count
        ))
        speak(round.hint)
    }

    // MARK: - complete

    private func complete() async {
        guard !isFinished else { return }
        isFinished = true
        feedback.stop()
        let total = max(rounds.count, 1)
        let rate = min(max(Float(correctFirstTry) / Float(total), 0), 1)
        await recordSession(rate: rate)
        presenter?.presentComplete(AdvancedGrammarModels.Complete.Response(
            mode: mode,
            totalRounds: rounds.count,
            correctFirstTry: correctFirstTry,
            successRate: rate
        ))
        logger.info("complete correctFirstTry=\(self.correctFirstTry, privacy: .public)/\(total, privacy: .public) rate=\(rate, privacy: .public)")
    }

    // MARK: - cancel

    func cancel() {
        isFinished = true
        feedback.stop()
        logger.info("AdvancedGrammar cancelled")
    }

    // MARK: - Persistence

    private func recordRoundOutcome() async {
        guard let round = currentRound, let planner = adaptivePlanner else { return }
        let correct = !erroredRoundIds.contains(round.id)
        await planner.recordItemOutcome(
            childId: childId,
            itemId: round.id,
            sound: "грамматика",
            correct: correct
        )
    }

    private func recordSession(rate: Float) async {
        guard let planner = adaptivePlanner else { return }
        let quality = SM2Quality.fromSuccessRate(Double(rate))
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: "грамматика-сложная",
                qualityScore: quality
            )
        } catch {
            logger.error("recordSessionResult failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    // MARK: - Helpers

    private var currentRound: AdvancedGrammarRound? {
        rounds.indices.contains(roundIndex) ? rounds[roundIndex] : nil
    }

    private func speak(_ text: String) {
        guard !text.isEmpty else { return }
        presenter?.presentPlaying(true)
        feedback.speak(text) { [weak self] in
            self?.presenter?.presentPlaying(false)
        }
    }

    // MARK: - Test seams

    /// Доля раундов, решённых с первой попытки (для тестов).
    var firstTryFraction: Double {
        rounds.isEmpty ? 0 : Double(correctFirstTry) / Double(rounds.count)
    }
}

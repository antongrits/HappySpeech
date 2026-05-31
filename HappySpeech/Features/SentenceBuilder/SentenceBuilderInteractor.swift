import Foundation
import OSLog

// MARK: - SentenceBuilderBusinessLogic

@MainActor
protocol SentenceBuilderBusinessLogic: AnyObject {
    func start(request: SentenceBuilderModels.Start.Request) async
    func answer(request: SentenceBuilderModels.Answer.Request) async
}

// MARK: - SentenceBuilderDataStore

@MainActor
protocol SentenceBuilderDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [SentenceRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
    /// Промахов подряд в текущем раунде (для fading-подсказки).
    var attemptsInRound: Int { get set }
}

// MARK: - SentenceBuilderInteractor (Clean Swift: Interactor)
//
// F2-004 «Конструктор предложения» (Wave 2).
//
// Бизнес-логика синтаксиса (порядок слов, согласование, предлоги). В отличие от
// механик-«выбор-одного-ответа» (WhoseTail, WordFormation, FourthExtra) здесь
// ребёнок СОБИРАЕТ ленту из карточек, поэтому оценка — ПОСЛЕДОВАТЕЛЬНАЯ и
// ЧАСТИЧНАЯ:
//   • из выложенного `placedOrder` отфильтровываем дистракторы (лишние слова);
//   • точное совпадение с любым `acceptedOrders` → hit (+ озвучка фразы целиком,
//     закрепление по слуху);
//   • иначе — `matchesPartially` (pure, тестируемо): ≥ 60 % верных соседних пар
//     ИЛИ перепутан только предлог → almost; светофор без «неправильно»;
//   • после 2 промахов подряд (`maxAttempts`) — retry-подсказка (первая карточка
//     «прилипает» в слот) и мягкое продвижение раунда (errorless fading);
//   • по завершении — `recordSessionResult` (soundTarget «грамматика.синтаксис»)
//     для spaced-repetition (SM-2).
// Без таймеров-соревнований (антифатиговое правило).
//
// `FeedbackTier` — общий тип (SoundDetectiveModels).

@MainActor
final class SentenceBuilderInteractor: SentenceBuilderBusinessLogic, SentenceBuilderDataStore {

    /// Максимум попыток на раунд: после 2 промахов мягко идём дальше.
    static let maxAttempts = 2
    /// Порог «частичного совпадения» по доле верных соседних пар (биграмм).
    nonisolated static let partialBigramThreshold = 0.6

    // MARK: - DataStore

    var childId: String
    var rounds: [SentenceRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var attemptsInRound: Int = 0

    /// «Звук» сессии для record («грамматика.синтаксис»).
    private(set) var sessionSoundTarget: String = "грамматика.синтаксис"
    /// Возраст ребёнка.
    private(set) var childAge: Int = 6

    // MARK: - VIP

    var presenter: (any SentenceBuilderPresentationLogic)?

    // MARK: - Deps

    private let worker: any SentenceBuilderWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SentenceBuilder.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any SentenceBuilderWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
    }

    // MARK: - Start

    func start(request: SentenceBuilderModels.Start.Request) async {
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
        Self.logger.debug("Started sentence-builder: \(response.rounds.count) rounds")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Answer

    func answer(request: SentenceBuilderModels.Answer.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("Answer called after session finished")
            return
        }
        let round = rounds[currentIndex]

        // Истина: точное совпадение допустимого порядка (отфильтровав дистракторы).
        let placed = request.placedOrder.filter { !round.distractorIds.contains($0) }
        let isExact = Self.matchesExactly(placed, round.acceptedOrders)
        let almost = !isExact && Self.matchesPartially(
            placed,
            accepted: round.acceptedOrders,
            prepositionIds: Self.prepositionIds(in: round)
        )
        _ = almost  // тон реплики almost формирует Presenter; для tier важен только isExact.

        let feedback: FeedbackTier
        var advance = false
        var showHint = false

        if isExact {
            feedback = .hit
            correctCount += 1
            attemptsInRound = 0
            advance = true
            hapticService.notification(.success)
        } else {
            attemptsInRound += 1
            // Никогда «неправильно». До лимита — мягкое `.almost` (переслушать /
            // пересобрать); со 2-го промаха — `.retry` + подсказка (errorless).
            feedback = (attemptsInRound >= Self.maxAttempts) ? .retry : .almost
            hapticService.notification(.warning)
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
        // Фразу целиком озвучиваем только на hit (закрепление по слуху).
        let spokenSentence = isExact ? round.spokenSentence : ""

        let response = SentenceBuilderModels.Answer.Response(
            feedback: feedback,
            correctOrder: round.canonicalOrder,
            spokenSentence: spokenSentence,
            firstHintTokenId: showHint ? round.firstHintTokenId : nil,
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

    // MARK: - Pure evaluation (тестируемо, без состояния)

    /// Точное совпадение выложенной последовательности с любым допустимым
    /// порядком (без учёта дистракторов — они уже отфильтрованы вызывающим).
    /// `nonisolated` — pure, тестируема из любого контекста.
    nonisolated static func matchesExactly(_ placed: [String], _ accepted: [[String]]) -> Bool {
        accepted.contains { $0 == placed }
    }

    /// Частичное совпадение (для тёплого `.almost`):
    ///   1) перепутан ТОЛЬКО предлог — состав слов верный, и единственное
    ///      несовпадение с допустимым порядком приходится на позицию предлога
    ///      (роль `.prep`/`.prepSlot`); ИЛИ
    ///   2) доля верных соседних пар (биграмм) ≥ `partialBigramThreshold` (60 %)
    ///      относительно лучшего допустимого порядка.
    /// Pure-функция: без побочных эффектов, легко покрывается тестами.
    /// `nonisolated` — тестируема из любого контекста.
    nonisolated static func matchesPartially(
        _ placed: [String],
        accepted: [[String]],
        prepositionIds: Set<String>
    ) -> Bool {
        guard !placed.isEmpty else { return false }
        // Точное совпадение здесь уже исключено вызывающим; перестрахуемся.
        if matchesExactly(placed, accepted) { return false }

        for order in accepted {
            if onlyPrepositionMisplaced(placed, expected: order, prepositionIds: prepositionIds) {
                return true
            }
            if bigramOverlap(placed, expected: order) >= partialBigramThreshold {
                return true
            }
        }
        return false
    }

    /// Перепутан только предлог: один и тот же мультимножественный состав слов,
    /// и все несовпадающие по позиции элементы — предлоги (роль prep/prepSlot).
    nonisolated static func onlyPrepositionMisplaced(
        _ placed: [String],
        expected: [String],
        prepositionIds: Set<String>
    ) -> Bool {
        guard placed.count == expected.count else { return false }
        // Состав слов должен совпадать как мультимножество.
        guard placed.sorted() == expected.sorted() else { return false }
        var mismatchedAllPrep = false
        for (a, b) in zip(placed, expected) where a != b {
            // Несовпадение по позиции — допустимо только если оба элемента
            // (и поставленный, и ожидаемый) — предлоги.
            guard prepositionIds.contains(a), prepositionIds.contains(b) else {
                return false
            }
            mismatchedAllPrep = true
        }
        return mismatchedAllPrep
    }

    /// Доля верных соседних пар (биграмм) выложенной последовательности
    /// относительно ожидаемой. 1.0 — все пары на месте, 0.0 — ни одной.
    /// Для последовательности из N элементов всего N−1 пар.
    nonisolated static func bigramOverlap(_ placed: [String], expected: [String]) -> Double {
        guard placed.count >= 2, expected.count >= 2 else { return 0 }
        let expectedPairs = Set(zip(expected, expected.dropFirst()).map { Pair($0, $1) })
        guard !expectedPairs.isEmpty else { return 0 }
        let placedPairs = zip(placed, placed.dropFirst()).map { Pair($0, $1) }
        let hits = placedPairs.filter { expectedPairs.contains($0) }.count
        return Double(hits) / Double(expectedPairs.count)
    }

    /// id всех токенов-предлогов раунда (роль `.prep` или `.prepSlot`).
    nonisolated static func prepositionIds(in round: SentenceRound) -> Set<String> {
        Set(round.bankTokens.filter { $0.role == .prep || $0.role == .prepSlot }.map(\.id))
    }

    /// Упорядоченная пара id (для множества биграмм). Hashable, Sendable.
    private struct Pair: Hashable, Sendable {
        let first: String
        let second: String
        init(_ first: String, _ second: String) {
            self.first = first
            self.second = second
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

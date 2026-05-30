import Foundation
import OSLog

// MARK: - SyllableSnailBusinessLogic

@MainActor
protocol SyllableSnailBusinessLogic: AnyObject {
    func start(request: SyllableSnailModels.Start.Request) async
    func tap(request: SyllableSnailModels.Tap.Request) async
    func submit(request: SyllableSnailModels.Submit.Request) async
    func fix(request: SyllableSnailModels.Fix.Request) async
}

// MARK: - SyllableSnailDataStore

@MainActor
protocol SyllableSnailDataStore: AnyObject {
    var childId: String { get set }
    var rounds: [SnailRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
    /// Промахов подряд в текущем раунде (для fading-подсказки).
    var attemptsInRound: Int { get set }
}

// MARK: - SyllableSnailInteractor (Clean Swift: Interactor)
//
// F2-003 «Слоговая улитка» (Wave 2).
//
// Бизнес-логика слоговой работы в трёх режимах:
//   • A clap   — `tapCount == word.syllables.count` → hit; ±1 → almost; иначе retry;
//   • B build  — собранное == эталон → hit; различие в 1 слог (Левенштейн по
//                слогам) → almost; иначе retry;
//   • C fix    — то же сравнение, но материал — преднабор перестановки (НСС);
// «Светофор» (hit/almost/retry) — без «неправильно». После 2 промахов подряд —
// подсказка (errorless fading) и мягкое продвижение раунда. По-слоговое
// переигрывание на almost/retry (с замедлением в retry). По завершении —
// `recordSessionResult` (SM-2) для spaced-repetition. Без таймеров.

@MainActor
@Observable
final class SyllableSnailInteractor: SyllableSnailBusinessLogic, SyllableSnailDataStore {

    /// Максимум попыток на раунд: после 2 промахов мягко идём дальше.
    static let maxAttempts = 2

    // MARK: - DataStore

    var childId: String
    var rounds: [SnailRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0
    var attemptsInRound: Int = 0

    /// Режим текущей сессии.
    private(set) var sessionMode: SnailMode = .clap
    /// Уровень текущей сессии.
    private(set) var sessionTier: SyllableTier = .oneSyllableOpen

    // MARK: - VIP

    var presenter: (any SyllableSnailPresentationLogic)?

    // MARK: - Deps

    private let worker: any SyllableSnailWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableSnail.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any SyllableSnailWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
    }

    // MARK: - Start

    func start(request: SyllableSnailModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(
            childId: request.childId,
            mode: request.mode,
            preferredTier: request.preferredTier
        )
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        attemptsInRound = 0
        sessionMode = response.mode
        sessionTier = response.tier
        Self.logger.debug("Started syllable-snail: \(response.rounds.count) rounds, mode \(response.mode.rawValue, privacy: .public)")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Tap (режим A)

    func tap(request: SyllableSnailModels.Tap.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("tap called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let expected = round.word.syllables.count
        let diff = abs(request.tapCount - expected)

        let evaluation = evaluate(isExactHit: diff == 0, isAlmost: diff == 1)

        let highlight = evaluation.feedback == .hit
        let response = SyllableSnailModels.Tap.Response(
            feedback: evaluation.feedback,
            expectedSyllables: expected,
            gotTaps: request.tapCount,
            replayBySyllable: evaluation.replay,
            snailReachedHome: highlight,
            showHint: evaluation.showHint,
            advancedToNextRound: evaluation.advance,
            isFinished: evaluation.isFinished,
            nextRound: evaluation.nextRound,
            nextRoundIndex: evaluation.nextRoundIndex,
            correctCount: correctCount,
            totalRounds: rounds.count
        )
        await presenter?.presentTap(response: response)
        await finishIfNeeded(evaluation.isFinished)
    }

    // MARK: - Submit (режим B)

    func submit(request: SyllableSnailModels.Submit.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("submit called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let assembledTexts = orderedTexts(for: request.tileIds, in: round)
        let expectedTexts = round.word.syllables
        let isExact = assembledTexts == expectedTexts
        let distance = Self.syllableLevenshtein(assembledTexts, expectedTexts)
        let evaluation = evaluate(isExactHit: isExact, isAlmost: distance <= 1)

        let wrongSlot = evaluation.showHint
            ? Self.firstWrongIndex(assembledTexts, expectedTexts)
            : nil

        let response = SyllableSnailModels.Submit.Response(
            feedback: evaluation.feedback,
            assembled: assembledTexts.joined(),
            expected: expectedTexts.joined(),
            snailReachedHome: evaluation.feedback == .hit,
            replayBySyllable: evaluation.replay,
            firstWrongSlotIndex: wrongSlot,
            showHint: evaluation.showHint,
            advancedToNextRound: evaluation.advance,
            isFinished: evaluation.isFinished,
            nextRound: evaluation.nextRound,
            nextRoundIndex: evaluation.nextRoundIndex,
            correctCount: correctCount,
            totalRounds: rounds.count
        )
        await presenter?.presentSubmit(response: response)
        await finishIfNeeded(evaluation.isFinished)
    }

    // MARK: - Fix (режим C — ядро)

    func fix(request: SyllableSnailModels.Fix.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("fix called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let assembledTexts = orderedTexts(for: request.orderedTileIds, in: round)
        let expectedTexts = round.word.syllables
        let isExact = assembledTexts == expectedTexts
        let distance = Self.syllableLevenshtein(assembledTexts, expectedTexts)
        let evaluation = evaluate(isExactHit: isExact, isAlmost: distance <= 1)

        let wrongSlot = evaluation.showHint
            ? Self.firstWrongIndex(assembledTexts, expectedTexts)
            : nil

        let response = SyllableSnailModels.Fix.Response(
            feedback: evaluation.feedback,
            assembled: assembledTexts.joined(),
            expected: expectedTexts.joined(),
            snailReachedHome: evaluation.feedback == .hit,
            replayBySyllable: evaluation.replay,
            firstWrongSlotIndex: wrongSlot,
            showHint: evaluation.showHint,
            advancedToNextRound: evaluation.advance,
            isFinished: evaluation.isFinished,
            nextRound: evaluation.nextRound,
            nextRoundIndex: evaluation.nextRoundIndex,
            correctCount: correctCount,
            totalRounds: rounds.count
        )
        await presenter?.presentFix(response: response)
        await finishIfNeeded(evaluation.isFinished)
    }

    // MARK: - Shared evaluation («светофор» + fading + продвижение)

    private struct Evaluation {
        let feedback: FeedbackTier
        let advance: Bool
        let showHint: Bool
        let replay: Bool
        let isFinished: Bool
        let nextRound: SnailRound?
        let nextRoundIndex: Int?
    }

    /// Единая логика оценки для всех режимов: hit/almost/retry, errorless
    /// fading (подсказка и мягкое продвижение после 2 промахов).
    private func evaluate(isExactHit: Bool, isAlmost: Bool) -> Evaluation {
        let feedback: FeedbackTier
        var advance = false
        var showHint = false
        var replay = false

        if isExactHit {
            feedback = .hit
            correctCount += 1
            attemptsInRound = 0
            advance = true
            hapticService.notification(.success)
        } else {
            attemptsInRound += 1
            // 1-й промах — «почти» (если близко) или мягкое «почти»; со 2-го —
            // «попробуем ещё» + подсказка. Никогда «неправильно».
            if attemptsInRound >= Self.maxAttempts {
                feedback = .retry
                showHint = true
                advance = true        // errorless: не зацикливаем ребёнка.
            } else {
                // Первый промах всегда мягкий «почти» (методика «светофора»,
                // никогда «неправильно»). `isAlmost` (близость в 1 правку)
                // ведёт замедление по-слогового переигрывания.
                feedback = .almost
                advance = false
            }
            _ = isAlmost
            replay = true
            hapticService.notification(.warning)
            if advance { attemptsInRound = 0 }
        }

        if advance { currentIndex += 1 }

        let isFinished = currentIndex >= rounds.count
        let next = (advance && !isFinished) ? rounds[currentIndex] : nil
        let nextIndex = (advance && !isFinished) ? currentIndex : nil

        return Evaluation(
            feedback: feedback,
            advance: advance,
            showHint: showHint,
            replay: replay,
            isFinished: isFinished,
            nextRound: next,
            nextRoundIndex: nextIndex
        )
    }

    private func finishIfNeeded(_ isFinished: Bool) async {
        guard isFinished else { return }
        await recordResult()
    }

    // MARK: - Adaptive

    /// По завершении сессии — SM-2 обратная связь для spaced-repetition.
    private func recordResult() async {
        guard let planner = adaptivePlanner else { return }
        let total = rounds.count
        let rate = total > 0 ? Double(correctCount) / Double(total) : 0
        let quality = SM2Quality.fromSuccessRate(rate)
        // Слоговая структура — не звук; в качестве soundTarget передаём метку
        // навыка (планировщик трекует слоговой трек отдельно).
        do {
            try await planner.recordSessionResult(
                childId: childId,
                soundTarget: Self.skillTarget,
                qualityScore: quality
            )
        } catch {
            Self.logger.error(
                "recordSessionResult failed: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    /// Метка слогового навыка для AdaptivePlanner (этап `syllable`).
    static let skillTarget = "слоги"

    // MARK: - Helpers (testable, pure)

    /// Доля правильных ответов сессии.
    var accuracyFraction: Double {
        rounds.isEmpty ? 0 : Double(correctCount) / Double(rounds.count)
    }

    /// Сортирует тексты слогов в порядке tileIds (отсутствующие пропускаются).
    private func orderedTexts(for tileIds: [String], in round: SnailRound) -> [String] {
        let lookup = Dictionary(uniqueKeysWithValues: round.tiles.map { ($0.id, $0.text) })
        return tileIds.compactMap { lookup[$0] }
    }

    /// Расстояние Левенштейна между двумя последовательностями слогов.
    /// Используется для отличия «почти» (1 правка) от «попробуем ещё».
    nonisolated static func syllableLevenshtein(_ lhs: [String], _ rhs: [String]) -> Int {
        let m = lhs.count
        let n = rhs.count
        if m == 0 { return n }
        if n == 0 { return m }
        var previous = Array(0...n)
        var current = [Int](repeating: 0, count: n + 1)
        for i in 1...m {
            current[0] = i
            for j in 1...n {
                let cost = lhs[i - 1] == rhs[j - 1] ? 0 : 1
                current[j] = min(
                    previous[j] + 1,        // удаление
                    current[j - 1] + 1,     // вставка
                    previous[j - 1] + cost  // замена
                )
            }
            swap(&previous, &current)
        }
        return previous[n]
    }

    /// Индекс первого слота, где собранное расходится с эталоном (для подсказки).
    nonisolated static func firstWrongIndex(_ assembled: [String], _ expected: [String]) -> Int? {
        for index in 0..<expected.count {
            let got = index < assembled.count ? assembled[index] : nil
            if got != expected[index] { return index }
        }
        return assembled.count > expected.count ? expected.count : nil
    }
}

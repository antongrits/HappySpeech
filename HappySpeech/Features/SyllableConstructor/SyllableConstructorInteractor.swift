import Foundation
import OSLog

// MARK: - SyllableConstructorBusinessLogic

@MainActor
protocol SyllableConstructorBusinessLogic: AnyObject {
    func start(request: SyllableConstructorModels.Start.Request) async
    func submitGuess(request: SyllableConstructorModels.SubmitGuess.Request) async
    func nextWord(request: SyllableConstructorModels.NextWord.Request) async
    /// Завершение упражнения (уход с экрана): фиксирует результат сессии в
    /// адаптивном планировщике и персистентности. Идемпотентно.
    func finish() async
}

// MARK: - SyllableConstructorDataStore

@MainActor
protocol SyllableConstructorDataStore: AnyObject {
    var childId: String { get set }
    var currentTier: SyllableTier { get set }
    var currentWord: SyllableWord? { get set }
    var currentTiles: [SyllableTile] { get set }
    var playedIds: Set<String> { get set }
}

// MARK: - SyllableConstructorInteractor (Clean Swift: Interactor)
//
// v31 Волна B, Функция Ф.1 «Слог-конструктор».
//
// Бизнес-логика:
// 1. start  — выбирает уровень (по умолчанию первый доступный) и слово,
//             перемешивает плитки, отдаёт presenter'у.
// 2. submit — сравнивает порядок плиток с эталоном `word.syllables`.
//             При успехе — haptic .success + новое слово. При ошибке —
//             haptic .error и плитки остаются на месте. Каждая попытка по слову
//             фиксируется как per-word outcome в едином планировщике интервальных
//             повторов (FSRS-лестница) — упражнение даёт обучающий сигнал.
// 3. next   — следующий случайный пример из текущего/нового уровня.
// 4. finish — при уходе с экрана сохраняет результат сессии (SM-2 + персистентность),
//             как сиблинг-фичи (LiveSounds, VoiceColors): доля собранных с первой
//             попытки слов → история, прогресс, due-повторы.

@MainActor
final class SyllableConstructorInteractor:
    SyllableConstructorBusinessLogic, SyllableConstructorDataStore {

    // MARK: - DataStore

    var childId: String
    var currentTier: SyllableTier = .oneSyllableOpen
    var currentWord: SyllableWord?
    var currentTiles: [SyllableTile] = []
    var playedIds: Set<String> = []

    // MARK: - VIP

    var presenter: (any SyllableConstructorPresentationLogic)?

    // MARK: - Deps

    private let worker: any SyllableConstructorWorkerProtocol
    private let hapticService: any HapticService
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let sessionPersistence: (any SessionPersistenceCoordinating)?

    // MARK: - Session state (для записи результата)

    /// Слова, которые ребёнок уже хотя бы раз проверял в этой сессии.
    private var attemptedWordIds: Set<String> = []
    /// Слова, собранные с первой попытки (для скоринга сессии).
    private var firstTrySolvedIds: Set<String> = []
    /// Уже сделанные ошибки по текущему слову (исключают его из «с первой попытки»).
    private var currentWordHadError: Bool = false
    /// Слово засчитано как решённое (чтобы не давать SM-2 кредит дважды).
    private var solvedWordIds: Set<String> = []

    private let sessionId = UUID().uuidString
    private let sessionStart = Date()
    private var didFinish: Bool = false

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableConstructor.Interactor"
    )

    init(
        childId: String,
        worker: any SyllableConstructorWorkerProtocol,
        hapticService: any HapticService,
        adaptivePlanner: (any AdaptivePlannerService)? = nil,
        sessionPersistence: (any SessionPersistenceCoordinating)? = nil
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
        self.adaptivePlanner = adaptivePlanner
        self.sessionPersistence = sessionPersistence
    }

    // MARK: - Start

    func start(request: SyllableConstructorModels.Start.Request) async {
        childId = request.childId
        let availableTiers = worker.availableTiers()
        let resolvedTier = request.preferredTier
            ?? availableTiers.first
            ?? .oneSyllableOpen
        currentTier = resolvedTier

        guard let word = worker.nextWord(for: resolvedTier, exclude: playedIds) else {
            Self.logger.warning("No words available for tier \(resolvedTier.rawValue, privacy: .public)")
            return
        }
        currentWord = word
        currentTiles = worker.makeTiles(from: word)
        currentWordHadError = false
        playedIds.insert(word.id)

        let response = SyllableConstructorModels.Start.Response(
            tier: resolvedTier,
            word: word,
            shuffledTiles: currentTiles,
            availableTiers: availableTiers,
            totalWordsInTier: worker.count(for: resolvedTier),
            wordIndex: playedIds.intersection(Set(SyllableConstructorCorpus.words(for: resolvedTier).map(\.id))).count
        )
        await presenter?.presentStart(response: response)
        // Озвучиваем слово голосом Ляли — не блокируем UI.
        let voicedWord = word
        Task { @MainActor [worker] in
            await worker.voiceWord(voicedWord)
        }
    }

    // MARK: - Submit

    func submitGuess(request: SyllableConstructorModels.SubmitGuess.Request) async {
        guard let word = currentWord else {
            Self.logger.warning("submitGuess called without active word")
            return
        }
        let orderedTexts = orderedTexts(for: request.tileIds)
        let assembled = orderedTexts.joined()
        let expected = word.syllables.joined()
        let isCorrect = assembled.caseInsensitiveCompare(expected) == .orderedSame

        if isCorrect {
            hapticService.notification(.success)
        } else {
            hapticService.notification(.error)
            currentWordHadError = true
        }

        await recordWordOutcome(word: word, correct: isCorrect)

        let response = SyllableConstructorModels.SubmitGuess.Response(
            isCorrect: isCorrect,
            assembled: assembled,
            expected: expected
        )
        await presenter?.presentSubmit(response: response)
    }

    // MARK: - Next

    func nextWord(request: SyllableConstructorModels.NextWord.Request) async {
        let targetTier = request.nextTier ?? currentTier
        await start(request: .init(childId: childId, preferredTier: targetTier))
    }

    // MARK: - Finish (уход с экрана)

    func finish() async {
        guard !didFinish else { return }
        didFinish = true
        await recordSession()
    }

    // MARK: - Persistence

    /// Фиксирует результат попытки по конкретному слову в едином планировщике
    /// интервальных повторов (лестница 1→3→7→14→30 дней). Засчитываем слово
    /// «верным» для FSRS только при сборке (correct == true); ошибочные попытки
    /// тоже логируются (correct == false) — планировщик учитывает оба исхода.
    private func recordWordOutcome(word: SyllableWord, correct: Bool) async {
        attemptedWordIds.insert(word.id)
        if correct {
            if !currentWordHadError, !solvedWordIds.contains(word.id) {
                firstTrySolvedIds.insert(word.id)
            }
            solvedWordIds.insert(word.id)
        }
        guard let planner = adaptivePlanner else { return }
        await planner.recordItemOutcome(
            childId: childId,
            itemId: word.id,
            sound: "слоговая-структура",
            correct: correct
        )
    }

    private func recordSession() async {
        guard !attemptedWordIds.isEmpty else { return }
        let total = max(attemptedWordIds.count, 1)
        let score = min(max(Float(firstTrySolvedIds.count) / Float(total), 0), 1)
        Self.logger.info(
            "finish firstTry=\(self.firstTrySolvedIds.count, privacy: .public)/\(total, privacy: .public) score=\(score, privacy: .public)"
        )

        // 1. SM-2 в планировщике.
        if let planner = adaptivePlanner {
            let quality = SM2Quality.fromSuccessRate(Double(score))
            do {
                try await planner.recordSessionResult(
                    childId: childId,
                    soundTarget: "слоговая-структура",
                    qualityScore: quality
                )
            } catch {
                Self.logger.error("recordSessionResult failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // 2. Персистентность сессии (offline-first + sync для аутентиф. родителя).
        guard let sessionPersistence, !childId.isEmpty else { return }
        let dto = SessionDTO(
            id: sessionId,
            childId: childId,
            date: Date(),
            templateType: TemplateType.dragAndMatch.rawValue,
            targetSound: "слоговая-структура",
            stage: CorrectionStage.syllable.rawValue,
            durationSeconds: Int(Date().timeIntervalSince(sessionStart)),
            totalAttempts: attemptedWordIds.count,
            correctAttempts: solvedWordIds.count,
            fatigueDetected: false,
            isSynced: false,
            attempts: []
        )
        await sessionPersistence.persistAndSync(dto)
    }

    // MARK: - Helpers

    /// Сортирует тексты слогов в порядке tileIds (отсутствующие пропускаются).
    private func orderedTexts(for tileIds: [String]) -> [String] {
        let lookup = Dictionary(uniqueKeysWithValues: currentTiles.map { ($0.id, $0.text) })
        return tileIds.compactMap { lookup[$0] }
    }

    // MARK: - Test seams

    /// Доля собранных с первой попытки слов (для тестов и расчётов).
    var firstTryFraction: Double {
        attemptedWordIds.isEmpty ? 0 : Double(firstTrySolvedIds.count) / Double(attemptedWordIds.count)
    }
}

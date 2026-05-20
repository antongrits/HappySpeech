import Foundation
import OSLog

// MARK: - SyllableConstructorBusinessLogic

@MainActor
protocol SyllableConstructorBusinessLogic: AnyObject {
    func start(request: SyllableConstructorModels.Start.Request) async
    func submitGuess(request: SyllableConstructorModels.SubmitGuess.Request) async
    func nextWord(request: SyllableConstructorModels.NextWord.Request) async
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
//             haptic .error и плитки остаются на месте.
// 3. next   — следующий случайный пример из текущего/нового уровня.

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

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableConstructor.Interactor"
    )

    init(
        childId: String,
        worker: any SyllableConstructorWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
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
        }

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

    // MARK: - Helpers

    /// Сортирует тексты слогов в порядке tileIds (отсутствующие пропускаются).
    private func orderedTexts(for tileIds: [String]) -> [String] {
        let lookup = Dictionary(uniqueKeysWithValues: currentTiles.map { ($0.id, $0.text) })
        return tileIds.compactMap { lookup[$0] }
    }
}

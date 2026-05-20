import Foundation
import OSLog

// MARK: - LexicalThemesBusinessLogic

@MainActor
protocol LexicalThemesBusinessLogic: AnyObject {
    func loadThemes(request: LexicalThemesModels.LoadThemes.Request) async
    func startTheme(request: LexicalThemesModels.StartTheme.Request) async
    func answer(request: LexicalThemesModels.Answer.Request) async
}

// MARK: - LexicalThemesDataStore

@MainActor
protocol LexicalThemesDataStore: AnyObject {
    var childId: String { get set }
    var activeThemeId: String? { get set }
    var rounds: [LexicalRound] { get set }
    var currentIndex: Int { get set }
    var correctCount: Int { get set }
}

// MARK: - LexicalThemesInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 7 «Мир слов».
//
// Бизнес-логика хаба лексических тем: загружает темы, ведёт мини-игру
// внутри темы, проверяет ответы, при точности ≥ 75% отмечает тему освоенной.

@MainActor
final class LexicalThemesInteractor: LexicalThemesBusinessLogic, LexicalThemesDataStore {

    // MARK: - DataStore

    var childId: String
    var activeThemeId: String?
    var rounds: [LexicalRound] = []
    var currentIndex: Int = 0
    var correctCount: Int = 0

    // MARK: - VIP

    var presenter: (any LexicalThemesPresentationLogic)?

    // MARK: - Deps

    private let worker: any LexicalThemesWorkerProtocol
    private let hapticService: any HapticService

    /// Минимальная точность сессии для отметки темы освоенной.
    static let masteryThreshold = 0.75

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LexicalThemes.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any LexicalThemesWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - LoadThemes

    func loadThemes(request: LexicalThemesModels.LoadThemes.Request) async {
        childId = request.childId
        let response = await worker.loadThemes(childId: request.childId)
        Self.logger.debug("Loaded \(response.themes.count) lexical themes")
        await presenter?.presentThemes(response: response)
    }

    // MARK: - StartTheme

    func startTheme(request: LexicalThemesModels.StartTheme.Request) async {
        guard let response = worker.buildThemeSession(themeId: request.themeId) else {
            Self.logger.warning("Failed to build session for \(request.themeId, privacy: .public)")
            return
        }
        activeThemeId = request.themeId
        rounds = response.rounds
        currentIndex = 0
        correctCount = 0
        await presenter?.presentThemeStart(response: response)
    }

    // MARK: - Answer

    func answer(request: LexicalThemesModels.Answer.Request) async {
        guard currentIndex < rounds.count else {
            Self.logger.warning("Answer called after session finished")
            return
        }
        let round = rounds[currentIndex]
        let wasCorrect = request.optionIndex == Self.correctOptionIndex(for: round)
        if wasCorrect {
            correctCount += 1
            hapticService.notification(.success)
        } else {
            hapticService.notification(.warning)
        }

        // v31 Волна D Ф.2 — FSRS-6 spaced repetition: применяем результат
        // к расписанию повторений для слова.
        await worker.recordReview(
            childId: childId,
            wordId: round.word.id,
            wasCorrect: wasCorrect
        )

        currentIndex += 1
        let isFinished = currentIndex >= rounds.count
        let nextRound = isFinished ? nil : rounds[currentIndex]

        if isFinished {
            let accuracy = rounds.isEmpty
                ? 0
                : Double(correctCount) / Double(rounds.count)
            if accuracy >= Self.masteryThreshold, let themeId = activeThemeId {
                await worker.markThemeMastered(childId: childId, themeId: themeId)
            }
        }

        let response = LexicalThemesModels.Answer.Response(
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

    /// Возвращает 0-based индекс правильного варианта для раунда.
    /// Правильный вариант детерминированно — индекс 0 (Presenter
    /// перемешивает позицию, согласуя с этой логикой через стабильный
    /// порядок построения опций).
    static func correctOptionIndex(for round: LexicalRound) -> Int {
        0
    }
}

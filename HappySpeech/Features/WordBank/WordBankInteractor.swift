import Foundation
import OSLog

// MARK: - WordBankBusinessLogic

@MainActor
protocol WordBankBusinessLogic: AnyObject {
    func loadBank(request: WordBankModels.Load.Request) async
    func filterBySound(request: WordBankModels.Filter.Request) async
    func selectWord(request: WordBankModels.SelectWord.Request) async
    func practiceWord(request: WordBankModels.Practice.Request) async
}

// MARK: - WordBankDataStore

@MainActor
protocol WordBankDataStore: AnyObject {
    var childId: String { get set }
    var allStats: [BankWordStat] { get set }
    var selectedFilter: String? { get set }
}

// MARK: - WordBankInteractor (Clean Swift: Interactor)
//
// F-303 v25 — «Копилка слов» (детский контур).
//
// Ответственность:
//   • Загрузить агрегированный словарь ребёнка через Worker.
//   • Фильтровать по целевому звуку.
//   • Раскрыть детальную информацию по слову.
//   • Запустить практику конкретного слова (через Router).
//   • Зафиксировать события `word_bank_opened`, `word_practiced_from_bank`.

@MainActor
final class WordBankInteractor: WordBankBusinessLogic, WordBankDataStore {

    // MARK: - DataStore

    var childId: String
    var allStats: [BankWordStat] = []
    var selectedFilter: String?

    // MARK: - VIP

    var presenter: (any WordBankPresentationLogic)?

    // MARK: - Dependencies

    private let worker: any WordBankWorkerProtocol
    private let analyticsService: any AnalyticsService
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordBank.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any WordBankWorkerProtocol,
        analyticsService: any AnalyticsService,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.analyticsService = analyticsService
        self.hapticService = hapticService
    }

    // MARK: - Load

    func loadBank(request: WordBankModels.Load.Request) async {
        childId = request.childId
        do {
            let stats = try await worker.fetchWordStats(childId: request.childId)
            allStats = stats
            analyticsService.track(event: AnalyticsEvent(name: "word_bank_opened"))
            await presenter?.presentLoad(
                response: .init(wordStats: stats)
            )
        } catch {
            Self.logger.error("loadBank failed: \(error.localizedDescription, privacy: .public)")
            allStats = []
            await presenter?.presentLoad(response: .init(wordStats: []))
        }
    }

    // MARK: - Filter

    func filterBySound(request: WordBankModels.Filter.Request) async {
        selectedFilter = request.soundTarget
        let filtered: [BankWordStat]
        if let sound = request.soundTarget {
            filtered = allStats.filter { $0.targetSound == sound }
        } else {
            filtered = allStats
        }
        await presenter?.presentFilter(response: .init(filtered: filtered))
    }

    // MARK: - SelectWord

    func selectWord(request: WordBankModels.SelectWord.Request) async {
        guard let stat = allStats.first(where: { $0.id == request.wordId }) else {
            Self.logger.error("selectWord: unknown id \(request.wordId, privacy: .public)")
            return
        }
        // Celebration haptic для 3-звёздочных слов.
        if WordBankPresenter.starRating(avgScore: stat.avgScore) == 3 {
            hapticService.impact(.medium)
        } else {
            hapticService.selection()
        }
        await presenter?.presentSelectWord(response: .init(stat: stat))
    }

    // MARK: - Practice

    func practiceWord(request: WordBankModels.Practice.Request) async {
        Self.logger.info("Practice from bank: \(request.word, privacy: .public)")
        analyticsService.track(
            event: AnalyticsEvent(
                name: "word_practiced_from_bank",
                parameters: ["targetSound": request.targetSound]
            )
        )
        await presenter?.presentPractice(request: request)
    }
}

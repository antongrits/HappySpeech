import Foundation
import OSLog

// MARK: - WordBankPresentationLogic

@MainActor
protocol WordBankPresentationLogic: AnyObject {
    func presentLoad(response: WordBankModels.Load.Response) async
    func presentFilter(response: WordBankModels.Filter.Response) async
    func presentSelectWord(response: WordBankModels.SelectWord.Response) async
    func presentPractice(request: WordBankModels.Practice.Request) async
}

// MARK: - WordBankDisplayLogic

@MainActor
protocol WordBankDisplayLogic: AnyObject {
    func displayLoad(viewModel: WordBankModels.Load.ViewModel) async
    func displayFilter(viewModel: WordBankModels.Filter.ViewModel) async
    func displaySelectWord(viewModel: WordBankModels.SelectWord.ViewModel) async
    func displayPractice(request: WordBankModels.Practice.Request) async
}

// MARK: - WordBankPresenter (Clean Swift: Presenter)
//
// F-303 v25 — мапит Response → ViewModel.
// Все строки — через `String(localized:)`.

@MainActor
final class WordBankPresenter: WordBankPresentationLogic {

    weak var displayLogic: (any WordBankDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "WordBank.Presenter"
    )

    init(displayLogic: (any WordBankDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Star rating

    /// Вычисляет рейтинг звёзд из средней оценки: 1 (<0.6), 2 (<0.8), 3 (≥0.8).
    static func starRating(avgScore: Double) -> Int {
        switch avgScore {
        case ..<0.6:  return 1
        case ..<0.8:  return 2
        default:      return 3
        }
    }

    /// Цветовая категория карточки по рейтингу звёзд.
    static func tileTint(for stars: Int) -> WordTileTint {
        switch stars {
        case 3:  return .gold
        case 2:  return .mint
        default: return .neutral
        }
    }

    // MARK: - Load

    func presentLoad(response: WordBankModels.Load.Response) async {
        let tiles = Self.buildTiles(from: response.wordStats)
        let counterText = String(response.wordStats.count)
        let filters = Self.soundFilters(from: response.wordStats)

        let viewModel = WordBankModels.Load.ViewModel(
            totalCount: response.wordStats.count,
            counterText: counterText,
            soundFilters: filters,
            tiles: tiles,
            isEmpty: response.wordStats.isEmpty
        )
        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - Filter

    func presentFilter(response: WordBankModels.Filter.Response) async {
        let tiles = Self.buildTiles(from: response.filtered)
        await displayLogic?.displayFilter(viewModel: .init(tiles: tiles))
    }

    // MARK: - SelectWord

    func presentSelectWord(response: WordBankModels.SelectWord.Response) async {
        let stat = response.stat
        let stars = Self.starRating(avgScore: stat.avgScore)
        let attemptText = String.localizedStringWithFormat(
            String(localized: "wordBank.detail.attemptCount"),
            stat.attemptCount
        )
        let lastText = Self.lastPracticedText(from: stat.lastPracticedAt)

        let viewModel = WordBankModels.SelectWord.ViewModel(
            word: stat.word,
            starRating: stars,
            attemptCountText: attemptText,
            lastPracticedText: lastText,
            targetSound: stat.targetSound
        )
        await displayLogic?.displaySelectWord(viewModel: viewModel)
    }

    // MARK: - Practice

    func presentPractice(request: WordBankModels.Practice.Request) async {
        await displayLogic?.displayPractice(request: request)
    }

    // MARK: - Builders

    /// Строит карточки слов. Сортировка: сначала 3-звёздочные, потом 2, потом 1.
    static func buildTiles(from stats: [BankWordStat]) -> [WordTileViewModel] {
        stats
            .map { stat -> WordTileViewModel in
                let stars = starRating(avgScore: stat.avgScore)
                return WordTileViewModel(
                    id: stat.id,
                    word: stat.word,
                    targetSoundLabel: stat.targetSound,
                    starRating: stars,
                    tileTint: tileTint(for: stars)
                )
            }
            .sorted { lhs, rhs in
                if lhs.starRating != rhs.starRating {
                    return lhs.starRating > rhs.starRating
                }
                return lhs.word < rhs.word
            }
    }

    /// Уникальные звуки с данными — для пикера фильтра.
    static func soundFilters(from stats: [BankWordStat]) -> [String] {
        Array(Set(stats.map(\.targetSound)))
            .filter { !$0.isEmpty }
            .sorted()
    }

    /// Человекочитаемая дата последней практики.
    static func lastPracticedText(from date: Date, now: Date = Date()) -> String {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let startToday = calendar.startOfDay(for: now)
        let startDate = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: startDate, to: startToday).day ?? 0

        if days <= 0 {
            return String(localized: "wordBank.lastPracticed.today")
        }
        if days == 1 {
            return String(localized: "wordBank.lastPracticed.yesterday")
        }
        return String.localizedStringWithFormat(
            String(localized: "wordBank.lastPracticed.daysAgo"),
            days
        )
    }
}

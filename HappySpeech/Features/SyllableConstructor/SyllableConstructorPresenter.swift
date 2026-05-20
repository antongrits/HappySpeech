import Foundation
import OSLog

// MARK: - SyllableConstructorPresentationLogic

@MainActor
protocol SyllableConstructorPresentationLogic: AnyObject {
    func presentStart(response: SyllableConstructorModels.Start.Response) async
    func presentSubmit(response: SyllableConstructorModels.SubmitGuess.Response) async
}

// MARK: - SyllableConstructorPresenter (Clean Swift: Presenter)
//
// v31 Волна B, Функция Ф.1 «Слог-конструктор».

@MainActor
final class SyllableConstructorPresenter: SyllableConstructorPresentationLogic {

    weak var displayLogic: (any SyllableConstructorDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableConstructor.Presenter"
    )

    init(displayLogic: (any SyllableConstructorDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
    }

    // MARK: - Start

    func presentStart(response: SyllableConstructorModels.Start.Response) async {
        let title = String(localized: "syllable.title")
        let tierLabel = Self.localized(response.tier.titleKey)
        let tierHint = Self.localized(response.tier.hintKey)

        let tiles = response.shuffledTiles.map { tile in
            SyllableConstructorModels.Start.TileViewModel(
                id: tile.id,
                text: tile.text,
                accessibilityLabel: String(
                    format: String(localized: "syllable.tile.a11y"),
                    tile.text
                )
            )
        }

        let chips = response.availableTiers.map { tier in
            SyllableConstructorModels.Start.TierChip(
                id: tier.rawValue,
                title: Self.localized(tier.titleKey),
                isSelected: tier == response.tier
            )
        }

        let progressLabel = String(
            format: String(localized: "syllable.progress"),
            response.wordIndex,
            response.totalWordsInTier
        )

        let accessibility = String(
            format: String(localized: "syllable.word.a11y"),
            response.word.word
        )

        let viewModel = SyllableConstructorModels.Start.ViewModel(
            title: title,
            tierLabel: tierLabel,
            tierHint: tierHint,
            wordLabel: response.word.word,
            placeholdersCount: response.word.syllables.count,
            tiles: tiles,
            availableTiers: chips,
            progressLabel: progressLabel,
            symbolName: response.word.symbolName,
            accessibilityLabel: accessibility
        )
        await displayLogic?.displayStart(viewModel: viewModel)
    }

    // MARK: - Submit

    func presentSubmit(response: SyllableConstructorModels.SubmitGuess.Response) async {
        let toastTitle: String
        let toastDetail: String
        if response.isCorrect {
            toastTitle = String(localized: "syllable.toast.correct.title")
            toastDetail = String(
                format: String(localized: "syllable.toast.correct.detail"),
                response.expected
            )
        } else {
            toastTitle = String(localized: "syllable.toast.wrong.title")
            toastDetail = String(localized: "syllable.toast.wrong.detail")
        }
        let viewModel = SyllableConstructorModels.SubmitGuess.ViewModel(
            isCorrect: response.isCorrect,
            toastTitle: toastTitle,
            toastDetail: toastDetail,
            assembled: response.assembled
        )
        await displayLogic?.displaySubmit(viewModel: viewModel)
    }
}

// MARK: - Dynamic localization helper

extension SyllableConstructorPresenter {
    /// Локализация по динамическому строковому ключу (значение
    /// вычисляется в runtime, поэтому статический `String(localized:)`
    /// тут не годится — он принимает только StaticString-литерал для
    /// catalog-инструментов).
    static func localized(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }
}

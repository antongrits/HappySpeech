import Foundation
import OSLog

// MARK: - CulturalContentPresentationLogic

@MainActor
protocol CulturalContentPresentationLogic: AnyObject, Sendable {
    func presentLoad(response: CulturalContentModels.Load.Response) async
    func presentOpen(response: CulturalContentModels.Open.Response) async
    func presentToggleBookmark(response: CulturalContentModels.ToggleBookmark.Response) async
}

// MARK: - CulturalContentPresenter (Clean Swift: Presenter)
//
// Block R.5 v18 — мапит Response → ViewModel.
//
// • Все строки через `String(localized:)` — ключи появятся в xcstrings
//   при сборке.
// • Длительность форматируется как «1 мин 30 с» через DateComponentsFormatter.
// • Сортировка: bookmarked сначала, потом по category → titleKey.

@MainActor
final class CulturalContentPresenter: CulturalContentPresentationLogic {

    weak var displayLogic: (any CulturalContentDisplayLogic)?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CulturalContent.Presenter"
    )

    private let durationFormatter: DateComponentsFormatter

    init(displayLogic: (any CulturalContentDisplayLogic)? = nil) {
        self.displayLogic = displayLogic
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.minute, .second]
        formatter.zeroFormattingBehavior = .dropAll
        formatter.calendar = Calendar(identifier: .gregorian)
        self.durationFormatter = formatter
    }

    // MARK: - Load

    func presentLoad(response: CulturalContentModels.Load.Response) async {
        let categories = CulturalCategory.allCases.map { cat -> CulturalContentModels.Load.CategoryRow in
            let count = CulturalItem.items(for: cat).count
            let title = String(localized: String.LocalizationValue(cat.titleKey))
            let isActive = cat == response.activeCategory
            return CulturalContentModels.Load.CategoryRow(
                id: cat.id,
                title: title,
                symbolName: cat.symbolName,
                isActive: isActive,
                count: count,
                accessibilityLabel: String(
                    format: String(localized: "cultural.category.a11y"),
                    title,
                    count
                )
            )
        }

        // Bookmarked первыми.
        let sortedItems = response.items.sorted { lhs, rhs in
            let lhsBookmarked = response.bookmarkedItemIDs.contains(lhs.id)
            let rhsBookmarked = response.bookmarkedItemIDs.contains(rhs.id)
            if lhsBookmarked != rhsBookmarked {
                return lhsBookmarked
            }
            if lhs.category != rhs.category {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            return lhs.titleKey < rhs.titleKey
        }

        let rows = sortedItems.map { item -> CulturalContentModels.Load.ItemRow in
            let title = String(localized: String.LocalizationValue(item.titleKey))
            let author = item.authorKey.map {
                String(localized: String.LocalizationValue($0))
            }
            let categoryTitle = String(
                localized: String.LocalizationValue(item.category.titleKey)
            )
            let durationLabel = durationFormatter.string(from: item.durationSeconds) ?? ""
            let soundsText = item.targetSounds.isEmpty
                ? String(localized: "cultural.item.allSounds")
                : item.targetSounds.joined(separator: " · ")
            let isBookmarked = response.bookmarkedItemIDs.contains(item.id)

            let a11y: String
            if let author = author {
                a11y = String(
                    format: String(localized: "cultural.item.a11y.withAuthor"),
                    title,
                    author,
                    categoryTitle
                )
            } else {
                a11y = String(
                    format: String(localized: "cultural.item.a11y.noAuthor"),
                    title,
                    categoryTitle
                )
            }

            return CulturalContentModels.Load.ItemRow(
                id: item.id,
                title: title,
                author: author,
                categoryTitle: categoryTitle,
                symbolName: item.symbolName,
                durationLabel: durationLabel,
                targetSoundsText: soundsText,
                isBookmarked: isBookmarked,
                accessibilityLabel: a11y
            )
        }

        let totalLabel = String(
            format: String(localized: "cultural.list.total"),
            response.items.count
        )

        let emptyHint: String? = response.items.isEmpty
            ? String(localized: "cultural.list.empty")
            : nil

        let viewModel = CulturalContentModels.Load.ViewModel(
            categories: categories,
            activeCategoryId: response.activeCategory?.id,
            items: rows,
            totalLabel: totalLabel,
            emptyHint: emptyHint
        )

        await displayLogic?.displayLoad(viewModel: viewModel)
    }

    // MARK: - Open

    func presentOpen(response: CulturalContentModels.Open.Response) async {
        let item = response.item
        let title = String(localized: String.LocalizationValue(item.titleKey))
        let author = item.authorKey.map {
            String(localized: String.LocalizationValue($0))
        }
        let durationLabel = durationFormatter.string(from: item.durationSeconds) ?? ""
        let soundsText = item.targetSounds.isEmpty
            ? String(localized: "cultural.item.allSounds")
            : item.targetSounds.joined(separator: " · ")

        let lines = item.lines.map {
            CulturalContentModels.Open.LineViewModel(
                id: $0.id,
                text: $0.text,
                startSeconds: $0.startSeconds,
                endSeconds: $0.endSeconds
            )
        }

        let viewModel = CulturalContentModels.Open.ViewModel(
            title: title,
            author: author,
            lines: lines,
            durationLabel: durationLabel,
            targetSoundsText: soundsText,
            isBookmarked: response.isBookmarked
        )

        await displayLogic?.displayOpen(viewModel: viewModel)
    }

    // MARK: - ToggleBookmark

    func presentToggleBookmark(response: CulturalContentModels.ToggleBookmark.Response) async {
        let toast: String
        if response.isBookmarked {
            toast = String(localized: "cultural.toast.bookmarked")
        } else {
            toast = String(localized: "cultural.toast.unbookmarked")
        }

        // Бэкап list bookmarks: parent layer обновит из interactor.load.
        let viewModel = CulturalContentModels.ToggleBookmark.ViewModel(
            toastMessage: toast,
            bookmarkedItemIDs: []   // не используется — view перезагружает list
        )

        await displayLogic?.displayToggleBookmark(viewModel: viewModel)
    }
}

import Foundation
import OSLog

// MARK: - CulturalContentBusinessLogic

@MainActor
protocol CulturalContentBusinessLogic: AnyObject {
    func load(request: CulturalContentModels.Load.Request) async
    func open(request: CulturalContentModels.Open.Request) async
    func toggleBookmark(request: CulturalContentModels.ToggleBookmark.Request) async
}

// MARK: - CulturalContentDataStore

@MainActor
protocol CulturalContentDataStore: AnyObject {
    var childId: String { get set }
    var activeCategory: CulturalCategory? { get set }
}

// MARK: - CulturalContentInteractor (Clean Swift: Interactor)
//
// Block R.5 v18 — Русские сказки/песни/стихи/скороговорки от методиста.
//
// Логика:
//   1. `load` — собрать список items по выбранной категории (или все)
//   2. `open` — открыть item для чтения с karaoke-style transcript
//   3. `toggleBookmark` — добавить/убрать из закладок
//
// Persistence: bookmarks через UserDefaults (per-child).
// Контент: bundled, статичный CulturalItem.catalog.
// COPPA: всё on-device, никаких сетевых запросов.

@MainActor
final class CulturalContentInteractor: CulturalContentBusinessLogic, CulturalContentDataStore {

    // MARK: - DataStore

    var childId: String
    var activeCategory: CulturalCategory?

    // MARK: - VIP

    var presenter: (any CulturalContentPresentationLogic)?

    // MARK: - Dependencies

    private let userDefaults: UserDefaults
    private let hapticService: any HapticService
    private static let logger = Logger(subsystem: "ru.happyspeech", category: "CulturalContent")

    // MARK: - UserDefaults keys

    private enum Keys {
        static let prefix = "happyspeech.cultural."
        static func bookmarks(_ childId: String) -> String {
            "\(prefix)\(childId).bookmarks"
        }
    }

    // MARK: - Init

    init(
        childId: String,
        hapticService: any HapticService,
        userDefaults: UserDefaults = .standard
    ) {
        self.childId = childId
        self.hapticService = hapticService
        self.userDefaults = userDefaults
        self.activeCategory = nil
    }

    // MARK: - Load

    func load(request: CulturalContentModels.Load.Request) async {
        let category = request.category ?? activeCategory
        activeCategory = category

        let items: [CulturalItem]
        if let cat = category {
            items = CulturalItem.items(for: cat)
        } else {
            items = CulturalItem.catalog
        }

        let bookmarks = readBookmarks(for: request.childId)

        let response = CulturalContentModels.Load.Response(
            activeCategory: category,
            items: items,
            bookmarkedItemIDs: bookmarks
        )

        await presenter?.presentLoad(response: response)
    }

    // MARK: - Open

    func open(request: CulturalContentModels.Open.Request) async {
        guard let item = CulturalItem.find(id: request.itemId) else {
            Self.logger.error("Cultural item not found: \(request.itemId, privacy: .public)")
            return
        }

        let bookmarks = readBookmarks(for: childId)
        let isBookmarked = bookmarks.contains(item.id)

        Self.logger.info("Opening cultural item: \(item.id, privacy: .public)")

        let response = CulturalContentModels.Open.Response(
            item: item,
            isBookmarked: isBookmarked
        )

        await presenter?.presentOpen(response: response)
    }

    // MARK: - ToggleBookmark

    func toggleBookmark(request: CulturalContentModels.ToggleBookmark.Request) async {
        var bookmarks = readBookmarks(for: request.childId)
        let isCurrently = bookmarks.contains(request.itemId)

        if isCurrently {
            bookmarks.remove(request.itemId)
        } else {
            bookmarks.insert(request.itemId)
        }

        writeBookmarks(bookmarks, for: request.childId)

        if !isCurrently {
            hapticService.impact(.light)
        }

        Self.logger.info(
            "Bookmark toggled for \(request.itemId, privacy: .public): \(!isCurrently)"
        )

        let response = CulturalContentModels.ToggleBookmark.Response(
            itemId: request.itemId,
            isBookmarked: !isCurrently
        )

        await presenter?.presentToggleBookmark(response: response)
    }

    // MARK: - Bookmarks persistence

    private func readBookmarks(for childId: String) -> Set<String> {
        let joined = userDefaults.string(forKey: Keys.bookmarks(childId)) ?? ""
        return Set(
            joined.split(separator: ",")
                .map { String($0) }
                .filter { !$0.isEmpty }
        )
    }

    private func writeBookmarks(_ bookmarks: Set<String>, for childId: String) {
        let joined = bookmarks.sorted().joined(separator: ",")
        userDefaults.set(joined, forKey: Keys.bookmarks(childId))
    }
}

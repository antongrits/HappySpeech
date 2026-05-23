import Foundation

// MARK: - SoundJournalKidModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SoundJournalKidModels {

    struct Entry: Identifiable, Hashable {
        let id: String
        let sound: String
        let timesPracticed: Int
        let lastScore: Int
        let emoji: String
    }

    struct ViewState: Equatable {
        var entries: [Entry]
        var selectedEntryId: String?

        static let initial = ViewState(entries: [
            Entry(id: "e1", sound: "Р", timesPracticed: 7, lastScore: 82, emoji: "🦁"),
            Entry(id: "e2", sound: "С", timesPracticed: 5, lastScore: 91, emoji: "🐍"),
            Entry(id: "e3", sound: "Ш", timesPracticed: 4, lastScore: 78, emoji: "🌬"),
            Entry(id: "e4", sound: "Л", timesPracticed: 3, lastScore: 65, emoji: "🛶"),
            Entry(id: "e5", sound: "Ж", timesPracticed: 2, lastScore: 73, emoji: "🐝")
        ], selectedEntryId: nil)
    }
}

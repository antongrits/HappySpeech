import Foundation

// MARK: - StoryEndingMakerModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum StoryEndingMakerModels {

    struct PictureCard: Identifiable, Hashable {
        let id: String
        let emoji: String
        let label: String
    }

    enum Phase: Hashable {
        case choosing
        case recording
        case saved
    }

    struct ViewState: Equatable {
        var cards: [PictureCard]
        var selectedId: String?
        var phase: Phase

        static let initial = ViewState(
            cards: [
                PictureCard(id: "c1", emoji: "🦊", label: "Лиса убежала"),
                PictureCard(id: "c2", emoji: "🐰", label: "Зайка спрятался"),
                PictureCard(id: "c3", emoji: "🌳", label: "Все стали друзьями")
            ],
            selectedId: nil,
            phase: .choosing
        )
    }
}

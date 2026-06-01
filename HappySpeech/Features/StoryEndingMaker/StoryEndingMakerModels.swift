import Foundation

// MARK: - StoryEndingMakerModels

/// Модели игры «Придумай концовку». Картинки-концовки — реальные слова из
/// словаря (`StoryEndingMakerWorker`); запись голоса реальная (через сервисы).
enum StoryEndingMakerModels {

    struct PictureCard: Identifiable, Hashable {
        let id: String
        /// Имя имейджсета (`word_*`), либо nil → плейсхолдер.
        let asset: String?
        let label: String
    }

    enum Phase: Hashable {
        case choosing
        case recording
        case saving
        case saved
    }

    struct ViewState: Equatable {
        var cards: [PictureCard]
        var selectedId: String?
        var phase: Phase
        var isLoaded: Bool
        /// Сколько концовок ребёнок сохранил всего (персистентно).
        var savedCount: Int

        var isEmpty: Bool {
            isLoaded && cards.isEmpty
        }

        static let initial = ViewState(
            cards: [],
            selectedId: nil,
            phase: .choosing,
            isLoaded: false,
            savedCount: 0
        )
    }
}

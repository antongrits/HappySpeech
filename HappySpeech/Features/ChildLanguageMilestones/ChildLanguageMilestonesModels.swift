import Foundation

// MARK: - ChildLanguageMilestonesModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum ChildLanguageMilestonesModels {

    enum Section: String, CaseIterable, Identifiable, Hashable {
        case comprehension
        case sounds
        case vocabulary
        case grammar

        var id: String { rawValue }

        var title: String {
            switch self {
            case .comprehension: return "Понимание речи"
            case .sounds:        return "Звукопроизношение"
            case .vocabulary:    return "Словарный запас"
            case .grammar:       return "Грамматика"
            }
        }

        var iconSystemName: String {
            switch self {
            case .comprehension: return "ear.fill"
            case .sounds:        return "waveform"
            case .vocabulary:    return "text.book.closed.fill"
            case .grammar:       return "text.alignleft"
            }
        }
    }

    struct Item: Identifiable, Hashable {
        let id: String
        let section: Section
        let title: String
        var isAchieved: Bool
    }

    struct ViewState: Equatable {
        var items: [Item]
        var ageBand: String

        func items(in section: Section) -> [Item] {
            items.filter { $0.section == section }
        }

        var overallProgress: Double {
            guard !items.isEmpty else { return 0 }
            let done = items.filter(\.isAchieved).count
            return Double(done) / Double(items.count)
        }

        static let initial = ViewState(
            items: [
                // Понимание
                Item(id: "c1", section: .comprehension, title: "Понимает 2-ступенчатые инструкции", isAchieved: true),
                Item(id: "c2", section: .comprehension, title: "Различает прошлое и настоящее", isAchieved: true),
                Item(id: "c3", section: .comprehension, title: "Понимает шутки и поддразнивания", isAchieved: false),
                // Звуки
                Item(id: "s1", section: .sounds, title: "Чётко произносит все свистящие (С, З, Ц)", isAchieved: true),
                Item(id: "s2", section: .sounds, title: "Чётко произносит шипящие (Ш, Ж, Ч, Щ)", isAchieved: false),
                Item(id: "s3", section: .sounds, title: "Чётко произносит Р и Л", isAchieved: false),
                // Словарь
                Item(id: "v1", section: .vocabulary, title: "Активный словарь 2000+ слов", isAchieved: true),
                Item(id: "v2", section: .vocabulary, title: "Использует обобщающие слова", isAchieved: true),
                Item(id: "v3", section: .vocabulary, title: "Знает антонимы и синонимы", isAchieved: false),
                // Грамматика
                Item(id: "g1", section: .grammar, title: "Согласовывает прилагательные с существительными", isAchieved: true),
                Item(id: "g2", section: .grammar, title: "Использует сложные предложения", isAchieved: false),
                Item(id: "g3", section: .grammar, title: "Правильно использует предлоги (в/на/под/над)", isAchieved: true)
            ],
            ageBand: "Возраст 5–6 лет"
        )
    }
}

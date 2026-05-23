import Foundation

// MARK: - SoundExplorerMapModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum SoundExplorerMapModels {

    enum MasteryFilter: String, CaseIterable, Identifiable, Hashable {
        case all
        case known
        case learning
        case untried

        var id: String { rawValue }

        var title: String {
            switch self {
            case .all:      return "Все"
            case .known:    return "Знаю"
            case .learning: return "Учу"
            case .untried:  return "Не пробовал"
            }
        }
    }

    enum Mastery: String, Hashable {
        case known, learning, untried

        var color: SoundMasteryColor { .init(self) }
    }

    struct SoundMasteryColor {
        let mastery: Mastery
        init(_ mastery: Mastery) { self.mastery = mastery }
    }

    struct SoundCell: Identifiable, Hashable {
        let id: String
        let group: String
        var mastery: Mastery

        var matches: (MasteryFilter) -> Bool {
            { filter in
                switch filter {
                case .all:      return true
                case .known:    return self.mastery == .known
                case .learning: return self.mastery == .learning
                case .untried:  return self.mastery == .untried
                }
            }
        }
    }

    /// Базовый набор русских фонем (42 — упрощённая инвентаризация).
    static let seedSounds: [SoundCell] = {
        let groups: [(String, [String], Mastery)] = [
            ("Гласные", ["А", "О", "У", "Ы", "Э", "И", "Я", "Ё", "Ю", "Е"], .known),
            ("Свистящие", ["С", "Сь", "З", "Зь", "Ц"], .learning),
            ("Шипящие", ["Ш", "Ж", "Ч", "Щ"], .learning),
            ("Соноры", ["Р", "Рь", "Л", "Ль", "М", "Мь", "Н", "Нь", "Й"], .untried),
            ("Заднеязычные", ["К", "Кь", "Г", "Гь", "Х", "Хь"], .known),
            ("Губные", ["П", "Пь", "Б", "Бь", "Ф", "Фь", "В", "Вь"], .known)
        ]
        return groups.flatMap { group, sounds, m in
            sounds.map { SoundCell(id: $0, group: group, mastery: m) }
        }
    }()
}

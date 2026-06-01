import Foundation

// MARK: - SoundExplorerMapModels

/// Карта звуков ребёнка. Уровень освоения (`mastery`) каждого звука вычисляется
/// из реальных данных: `progressSummary` профиля (per-sound rate) + история сессий.
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

    /// Инвентарь русских фонем с группами. Mastery по умолчанию `.untried` —
    /// он перезаписывается реальными данными в `SoundExplorerMapInteractor`.
    /// Гласные считаем освоенными (не корректируются методикой) — нейтральный
    /// контекст для карты.
    static let inventory: [(group: String, sounds: [String], defaultMastery: Mastery)] = [
        ("Гласные", ["А", "О", "У", "Ы", "Э", "И", "Я", "Ё", "Ю", "Е"], .known),
        ("Свистящие", ["С", "Сь", "З", "Зь", "Ц"], .untried),
        ("Шипящие", ["Ш", "Ж", "Ч", "Щ"], .untried),
        ("Соноры", ["Р", "Рь", "Л", "Ль", "М", "Мь", "Н", "Нь", "Й"], .untried),
        ("Заднеязычные", ["К", "Кь", "Г", "Гь", "Х", "Хь"], .untried),
        ("Губные", ["П", "Пь", "Б", "Бь", "Ф", "Фь", "В", "Вь"], .known)
    ]

    /// Базовый набор для preview/тестов (всё в дефолтном mastery).
    static let seedSounds: [SoundCell] = {
        inventory.flatMap { group, sounds, m in
            sounds.map { SoundCell(id: $0, group: group, mastery: m) }
        }
    }()

    /// Порог «освоено» по доле успешных попыток / progressSummary.
    static let knownThreshold: Double = 0.80
}

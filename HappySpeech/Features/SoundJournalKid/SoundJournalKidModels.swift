import Foundation

// MARK: - SoundJournalKidModels

/// Детский «дневник звуков». Состояние строится из реальных сессий ребёнка:
/// по каждому отрабатываемому звуку — сколько раз практиковался и последний балл.
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

        /// Нет ни одной сессии с попытками — показываем пустое состояние.
        var isEmpty: Bool { entries.isEmpty }

        /// Стартовое (загрузочное) состояние — пустое, без выдуманных записей.
        /// Реальные записи приходят из `SoundJournalKidInteractor.refresh()`.
        static let initial = ViewState(entries: [], selectedEntryId: nil)
    }

    /// Эмодзи-маскот для звука (детский UX). Соноры/свистящие/шипящие/заднеязычные.
    static func emoji(for sound: String) -> String {
        switch sound.uppercased() {
        case "Р", "РЬ": return "🦁"
        case "Л", "ЛЬ": return "🛶"
        case "С", "СЬ": return "🐍"
        case "З", "ЗЬ": return "🦓"
        case "Ц":       return "🌼"
        case "Ш":       return "🌬"
        case "Ж":       return "🐝"
        case "Ч":       return "🕰"
        case "Щ":       return "🪥"
        case "К":       return "🐸"
        case "Г":       return "🦢"
        case "Х":       return "🐹"
        default:        return "🎈"
        }
    }
}

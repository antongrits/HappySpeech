import Foundation

// MARK: - AnimalSoundsBingoModels

/// Модели игры «Звуковое бинго».
///
/// Поле собирается из звукоподражаний (`AnimalSoundsBingoContent`), отобранных
/// под рабочие звуки ребёнка. «Диктор» называет животное по звуку, ребёнок ищет
/// и отмечает карточку; верные отметки идут в outcome планировщика.
enum AnimalSoundsBingoModels {

    struct Cell: Identifiable, Hashable {
        let id: UUID
        let emoji: String
        let label: String
        let soundDescription: String
        /// Группа звука, к которой относится звукоподражание («С», «Р», «Ш» …).
        let soundFamily: String
        var isMarked: Bool
    }

    struct ViewState: Equatable {
        var cells: [Cell]
        var calledOutId: UUID?
        /// Сколько раз отметили именно ту клетку, что назвал «диктор».
        var correctMarks: Int = 0
        /// Сколько раз отметили НЕ ту клетку при активном вызове.
        var wrongMarks: Int = 0
        var bestStars: Int = 0
        var isLoaded: Bool = false

        var markedCount: Int { cells.filter(\.isMarked).count }

        /// «Бинго» — отмечено всё поле.
        var isBingo: Bool {
            !cells.isEmpty && markedCount >= cells.count
        }

        var accuracy: Double {
            let attempts = correctMarks + wrongMarks
            return attempts > 0 ? Double(correctMarks) / Double(attempts) : 0
        }

        /// Звёзды 0–3 по точности отметок.
        var stars: Int {
            guard correctMarks + wrongMarks > 0 else { return 0 }
            switch accuracy {
            case 0.95...: return 3
            case 0.75..<0.95: return 2
            default: return 1
            }
        }

        static let empty = ViewState(cells: [], calledOutId: nil)

        /// Базовое поле (Preview / тесты без репозитория).
        static let initial = ViewState(
            cells: AnimalSoundsBingoContent.cells(forTargetSounds: []),
            calledOutId: nil,
            isLoaded: true
        )
    }
}

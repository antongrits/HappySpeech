import Foundation

// MARK: - AnimalSoundsBingoModels

/// MVP: thin VIP, expand to full Presenter/Router/DisplayLogic post-launch.
enum AnimalSoundsBingoModels {

    struct Cell: Identifiable, Hashable {
        let id: UUID
        let emoji: String
        let label: String
        let soundDescription: String
        var isMarked: Bool
    }

    struct ViewState: Equatable {
        var cells: [Cell]
        var calledOutId: UUID?

        var markedCount: Int {
            cells.filter(\.isMarked).count
        }

        var isBingo: Bool {
            // Простой 4×4 bingo: засчитываем «бинго» когда отмечено ≥ 8 клеток.
            markedCount >= 8
        }

        static let animals: [(emoji: String, label: String, sound: String)] = [
            ("🐶", "Собака", "гав-гав"),
            ("🐱", "Кошка", "мяу"),
            ("🐮", "Корова", "му-у"),
            ("🐷", "Свинья", "хрю-хрю"),
            ("🐔", "Курица", "ко-ко"),
            ("🐴", "Лошадь", "и-го-го"),
            ("🐑", "Овечка", "бе-е"),
            ("🐰", "Заяц", "прыг-прыг"),
            ("🐻", "Медведь", "р-р-р"),
            ("🦁", "Лев", "р-р-р-р"),
            ("🐸", "Лягушка", "ква-ква"),
            ("🦆", "Утка", "кря-кря"),
            ("🐔", "Петух", "ку-ка-ре-ку"),
            ("🦉", "Сова", "у-ух"),
            ("🐺", "Волк", "у-у-у"),
            ("🐢", "Черепаха", "тих-тих")
        ]

        static let initial: ViewState = {
            let cells = animals.map { animal in
                Cell(
                    id: UUID(),
                    emoji: animal.emoji,
                    label: animal.label,
                    soundDescription: animal.sound,
                    isMarked: false
                )
            }
            return ViewState(cells: cells, calledOutId: nil)
        }()
    }
}

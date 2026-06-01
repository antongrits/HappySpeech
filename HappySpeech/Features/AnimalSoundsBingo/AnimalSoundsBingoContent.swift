import Foundation

// MARK: - AnimalSoundsBingoContent

/// Курируемый каталог звукоподражаний для «Звукового бинго».
///
/// Каждая запись связывает животное/объект, его звукоподражание и группу
/// логопедического звука, которая в этом звукоподражании отрабатывается. Игра
/// отбирает карточки под рабочие звуки ребёнка (с добором, чтобы поле было
/// заполнено), что превращает бинго в адресную тренировку нужных звуков по
/// слуху. Это методический контент — единый источник правды.
enum AnimalSoundsBingoContent {

    /// Одна запись каталога.
    struct AnimalSound: Hashable {
        let emoji: String
        let label: String
        let onomatopoeia: String
        /// Группа звука русской логопедии («С», «З», «Ш», «Ж», «Р», «Л», «К», «Х» …).
        let soundFamily: String
    }

    /// Полный каталог, сгруппированный по тренируемому звуку.
    static let all: [AnimalSound] = [
        // Свистящие
        .init(emoji: "🐍", label: "Змея",   onomatopoeia: "с-с-с",   soundFamily: "С"),
        .init(emoji: "🌬", label: "Насос",  onomatopoeia: "с-с-с",   soundFamily: "С"),
        .init(emoji: "🦟", label: "Комар",  onomatopoeia: "з-з-з",   soundFamily: "З"),
        .init(emoji: "🐝", label: "Шмель",  onomatopoeia: "дз-з-з",  soundFamily: "З"),
        // Шипящие
        .init(emoji: "🍃", label: "Листва", onomatopoeia: "ш-ш-ш",   soundFamily: "Ш"),
        .init(emoji: "🐍", label: "Шипение", onomatopoeia: "ш-ш-ш",  soundFamily: "Ш"),
        .init(emoji: "🐝", label: "Пчела",  onomatopoeia: "ж-ж-ж",   soundFamily: "Ж"),
        .init(emoji: "🪲", label: "Жук",    onomatopoeia: "ж-ж-ж",   soundFamily: "Ж"),
        .init(emoji: "🚂", label: "Поезд",  onomatopoeia: "чух-чух", soundFamily: "Ч"),
        .init(emoji: "🦗", label: "Кузнечик", onomatopoeia: "щёлк-щёлк", soundFamily: "Щ"),
        // Соноры
        .init(emoji: "🐯", label: "Тигр",   onomatopoeia: "р-р-р",   soundFamily: "Р"),
        .init(emoji: "🐶", label: "Собака", onomatopoeia: "р-р-гав", soundFamily: "Р"),
        .init(emoji: "✈️", label: "Самолёт", onomatopoeia: "л-л-л",  soundFamily: "Л"),
        .init(emoji: "🎵", label: "Песенка", onomatopoeia: "ля-ля-ля", soundFamily: "Л"),
        // Заднеязычные
        .init(emoji: "🐔", label: "Курица", onomatopoeia: "ко-ко-ко", soundFamily: "К"),
        .init(emoji: "🐸", label: "Лягушка", onomatopoeia: "ква-ква", soundFamily: "К"),
        .init(emoji: "🦆", label: "Утка",   onomatopoeia: "кря-кря", soundFamily: "К"),
        .init(emoji: "🐹", label: "Гусь",   onomatopoeia: "га-га-га", soundFamily: "Г"),
        .init(emoji: "🐻", label: "Медведь", onomatopoeia: "у-у-ух", soundFamily: "Х"),
        .init(emoji: "❄️", label: "Метель", onomatopoeia: "ху-у-у",  soundFamily: "Х")
    ]

    /// Карточки поля под рабочие звуки ребёнка. Сначала берутся записи рабочих
    /// звуков, затем поле добирается остальными до `count` карточек. Если
    /// рабочих звуков нет (Preview/онбординг не пройден) — берётся стартовый
    /// набор (свистящие).
    static func cells(
        forTargetSounds targets: [String],
        count: Int = 12
    ) -> [AnimalSoundsBingoModels.Cell] {
        let families = Set(targets.map { String($0.prefix(1)).uppercased() })
        let matched = all.filter { families.contains($0.soundFamily.uppercased()) }
        let rest = all.filter { !matched.contains($0) }
        // Если совпадений нет — начинаем со свистящих как стартовой группы.
        let primary = matched.isEmpty ? all.filter { $0.soundFamily == "С" || $0.soundFamily == "З" } : matched
        let secondary = matched.isEmpty ? all.filter { $0.soundFamily != "С" && $0.soundFamily != "З" } : rest
        let ordered = (primary + secondary).prefix(count)
        return ordered.map {
            AnimalSoundsBingoModels.Cell(
                id: UUID(),
                emoji: $0.emoji,
                label: $0.label,
                soundDescription: $0.onomatopoeia,
                soundFamily: $0.soundFamily,
                isMarked: false
            )
        }
    }
}

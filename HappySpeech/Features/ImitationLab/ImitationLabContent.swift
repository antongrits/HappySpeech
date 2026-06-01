import Foundation

// MARK: - ImitationLabContent

/// Курируемый каталог звукоподражаний-образцов для «Лаборатории подражания».
///
/// Каждый образец привязан к группе звука, который в нём отрабатывается
/// (изолированный звук / простой слог — этап автоматизации). Игра отбирает
/// образцы под рабочие звуки ребёнка. Это методический контент, единый
/// источник правды.
enum ImitationLabContent {

    struct Sample: Hashable {
        let id: String
        let emoji: String
        let name: String
        let onomatopoeia: String
        let soundFamily: String
    }

    static let all: [Sample] = [
        // Свистящие
        .init(id: "snake", emoji: "🐍", name: "Змейка", onomatopoeia: "С-с-с", soundFamily: "С"),
        .init(id: "pump",  emoji: "🚲", name: "Насос",  onomatopoeia: "Сс-сс", soundFamily: "С"),
        .init(id: "mosquito", emoji: "🦟", name: "Комар", onomatopoeia: "З-з-з", soundFamily: "З"),
        .init(id: "grasshopper", emoji: "🦗", name: "Кузнечик", onomatopoeia: "Ц-ц-ц", soundFamily: "Ц"),
        // Шипящие
        .init(id: "leaves", emoji: "🍃", name: "Листья", onomatopoeia: "Ш-ш-ш", soundFamily: "Ш"),
        .init(id: "bee",   emoji: "🐝", name: "Пчела",  onomatopoeia: "Ж-ж-ж", soundFamily: "Ж"),
        .init(id: "train", emoji: "🚂", name: "Поезд",  onomatopoeia: "Чух-чух", soundFamily: "Ч"),
        .init(id: "broom", emoji: "🧹", name: "Щётка",  onomatopoeia: "Щ-щ-щ", soundFamily: "Щ"),
        // Соноры
        .init(id: "tiger", emoji: "🐯", name: "Тигр",   onomatopoeia: "Р-р-р", soundFamily: "Р"),
        .init(id: "plane", emoji: "✈️", name: "Самолёт", onomatopoeia: "Л-л-л", soundFamily: "Л"),
        .init(id: "song",  emoji: "🎵", name: "Песенка", onomatopoeia: "Ля-ля-ля", soundFamily: "Л"),
        // Заднеязычные
        .init(id: "hen",   emoji: "🐔", name: "Курочка", onomatopoeia: "Ко-ко", soundFamily: "К"),
        .init(id: "goose", emoji: "🪿", name: "Гусь",    onomatopoeia: "Га-га", soundFamily: "Г"),
        .init(id: "laugh", emoji: "😄", name: "Смех",    onomatopoeia: "Ха-ха", soundFamily: "Х")
    ]

    /// Образцы под рабочие звуки ребёнка (с добором), не более `count`.
    static func samples(
        forTargetSounds targets: [String],
        count: Int = 6
    ) -> [ImitationLabModels.SoundSample] {
        let families = Set(targets.map { String($0.prefix(1)).uppercased() })
        let matched = all.filter { families.contains($0.soundFamily.uppercased()) }
        let rest = all.filter { !matched.contains($0) }
        // Без рабочих звуков — стартуем со свистящих.
        let primary = matched.isEmpty
            ? all.filter { ["С", "З", "Ц"].contains($0.soundFamily) }
            : matched
        let secondary = matched.isEmpty
            ? all.filter { !["С", "З", "Ц"].contains($0.soundFamily) }
            : rest
        let ordered = (primary + secondary).prefix(max(1, count))
        return ordered.map {
            ImitationLabModels.SoundSample(
                id: $0.id,
                emoji: $0.emoji,
                name: $0.name,
                onomatopoeia: $0.onomatopoeia,
                soundFamily: $0.soundFamily,
                isPlayed: false,
                isPracticed: false
            )
        }
    }
}

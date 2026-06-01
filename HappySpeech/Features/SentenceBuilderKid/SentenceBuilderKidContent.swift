import Foundation

// MARK: - SentenceBuilderKidContent

/// Курируемый каталог коротких предложений для игры «Собери предложение».
///
/// Предложения сгруппированы по рабочему звуку и насыщены им (автоматизация
/// звука во фразе — этап «фразы/предложения» русской логопедии). Это
/// методический контент, единый источник правды. Игра отбирает предложения под
/// рабочие звуки ребёнка.
enum SentenceBuilderKidContent {

    /// Одно предложение: слова по порядку + рабочий звук.
    struct Sentence: Hashable {
        let sound: String
        let words: [String]
    }

    /// Полный каталог по группам звуков (4–5 слов на фразу — посильно 5–8 лет).
    static let all: [Sentence] = [
        // Свистящие (С, З, Ц)
        .init(sound: "С", words: ["Соня", "несёт", "сок", "и", "сумку"]),
        .init(sound: "С", words: ["Сова", "сидит", "на", "сосне"]),
        .init(sound: "З", words: ["Зоя", "взяла", "зелёный", "зонт"]),
        .init(sound: "Ц", words: ["Цыплёнок", "клюёт", "цветок"]),
        // Шипящие (Ш, Ж, Ч, Щ)
        .init(sound: "Ш", words: ["Маша", "нашла", "большую", "шишку"]),
        .init(sound: "Ж", words: ["Жук", "жужжит", "на", "лужайке"]),
        .init(sound: "Ч", words: ["Девочка", "качает", "мячик"]),
        .init(sound: "Щ", words: ["Щенок", "ищет", "щётку"]),
        // Соноры (Р, Л)
        .init(sound: "Р", words: ["Рома", "рисует", "красивую", "розу"]),
        .init(sound: "Р", words: ["Рыбак", "поймал", "рыбу"]),
        .init(sound: "Л", words: ["Лиса", "бежит", "по", "лесу"]),
        .init(sound: "Л", words: ["Лола", "лепит", "лёгкий", "пластилин"]),
        // Заднеязычные (К, Г, Х)
        .init(sound: "К", words: ["Кот", "катает", "клубок"]),
        .init(sound: "Г", words: ["Гуси", "гогочут", "у", "горки"]),
        .init(sound: "Х", words: ["Хомяк", "хрустит", "хлебом"])
    ]

    /// Резервное предложение, если каталог по какой-то причине пуст.
    static let fallback = Sentence(sound: "Л", words: ["Лиса", "бежит", "по", "лесу"])

    /// Предложения под рабочий звук ребёнка (с добором остальных), не более `count`.
    static func sentences(for sound: String, count: Int = 4) -> [Sentence] {
        let family = String(sound.prefix(1)).uppercased()
        let matched = all.filter { $0.sound.uppercased() == family }
        let rest = all.filter { $0.sound.uppercased() != family }
        let ordered = matched + rest
        let result = Array(ordered.prefix(max(1, count)))
        return result.isEmpty ? [fallback] : result
    }
}

import Foundation

// MARK: - PhonemicListeningCorpus
//
// v29 Фаза 8, Функция 12 «Слушай внимательно».
//
// Корпус слов с полной звуковой разметкой для операций фонематического
// анализа. Лексика — частотная, возрастная (6–8 лет), односложные и
// двусложные слова без сложных стечений согласных (методически верно для
// начала анализа: Ткаченко, Каше).
//
// Звуковая разметка `sounds` отражает звуковой, а не буквенный состав
// (например «ёж» → [«й», «о», «ш»]). Полностью offline / on-device.

enum PhonemicListeningCorpus {

    /// Сколько раундов в одной сессии (8–12 мин, антифатиговое правило).
    static let roundsPerSession = 9

    /// Слова для операции «позиция звука» — целевой звук в начале/середине/конце.
    static let positionWords: [PhonemicWord] = [
        .init(id: "pos-sok", text: "сок", targetSound: "С",
              position: .start, sounds: ["с", "о", "к"]),
        .init(id: "pos-osa", text: "оса", targetSound: "С",
              position: .middle, sounds: ["о", "с", "а"]),
        .init(id: "pos-nos", text: "нос", targetSound: "С",
              position: .end, sounds: ["н", "о", "с"]),
        .init(id: "pos-rak", text: "рак", targetSound: "Р",
              position: .start, sounds: ["р", "а", "к"]),
        .init(id: "pos-gora", text: "гора", targetSound: "Р",
              position: .middle, sounds: ["г", "о", "р", "а"]),
        .init(id: "pos-shar", text: "шар", targetSound: "Р",
              position: .end, sounds: ["ш", "а", "р"]),
        .init(id: "pos-luk", text: "лук", targetSound: "Л",
              position: .start, sounds: ["л", "у", "к"]),
        .init(id: "pos-pila", text: "пила", targetSound: "Л",
              position: .middle, sounds: ["п", "и", "л", "а"]),
        .init(id: "pos-stol", text: "стол", targetSound: "Л",
              position: .end, sounds: ["с", "т", "о", "л"]),
        .init(id: "pos-zub", text: "зуб", targetSound: "З",
              position: .start, sounds: ["з", "у", "п"]),
        .init(id: "pos-koza", text: "коза", targetSound: "З",
              position: .middle, sounds: ["к", "о", "з", "а"]),
        .init(id: "pos-shum", text: "шум", targetSound: "Ш",
              position: .start, sounds: ["ш", "у", "м"])
    ]

    /// Слова для операции «количество звуков».
    static let countWords: [PhonemicWord] = [
        .init(id: "cnt-dom", text: "дом", targetSound: "Д",
              position: .start, sounds: ["д", "о", "м"]),
        .init(id: "cnt-mak", text: "мак", targetSound: "М",
              position: .start, sounds: ["м", "а", "к"]),
        .init(id: "cnt-kit", text: "кит", targetSound: "К",
              position: .start, sounds: ["к", "и", "т"]),
        .init(id: "cnt-luna", text: "луна", targetSound: "Л",
              position: .start, sounds: ["л", "у", "н", "а"]),
        .init(id: "cnt-roza", text: "роза", targetSound: "Р",
              position: .start, sounds: ["р", "о", "з", "а"]),
        .init(id: "cnt-kosa", text: "коса", targetSound: "К",
              position: .start, sounds: ["к", "о", "с", "а"]),
        .init(id: "cnt-ruka", text: "рука", targetSound: "Р",
              position: .start, sounds: ["р", "у", "к", "а"]),
        .init(id: "cnt-vata", text: "вата", targetSound: "В",
              position: .start, sounds: ["в", "а", "т", "а"]),
        .init(id: "cnt-syr", text: "сыр", targetSound: "С",
              position: .start, sounds: ["с", "ы", "р"])
    ]

    /// Слова для операции «синтез слова из звуков».
    static let synthesisWords: [PhonemicWord] = [
        .init(id: "syn-sok", text: "сок", targetSound: "С",
              position: .start, sounds: ["с", "о", "к"]),
        .init(id: "syn-kot", text: "кот", targetSound: "К",
              position: .start, sounds: ["к", "о", "т"]),
        .init(id: "syn-mak", text: "мак", targetSound: "М",
              position: .start, sounds: ["м", "а", "к"]),
        .init(id: "syn-dom", text: "дом", targetSound: "Д",
              position: .start, sounds: ["д", "о", "м"]),
        .init(id: "syn-luk", text: "лук", targetSound: "Л",
              position: .start, sounds: ["л", "у", "к"]),
        .init(id: "syn-syr", text: "сыр", targetSound: "С",
              position: .start, sounds: ["с", "ы", "р"]),
        .init(id: "syn-nos", text: "нос", targetSound: "Н",
              position: .start, sounds: ["н", "о", "с"]),
        .init(id: "syn-kit", text: "кит", targetSound: "К",
              position: .start, sounds: ["к", "и", "т"]),
        .init(id: "syn-rak", text: "рак", targetSound: "Р",
              position: .start, sounds: ["р", "а", "к"])
    ]

    /// Все слова корпуса (для покрытия тестами / отладки).
    static var allWords: [PhonemicWord] {
        positionWords + countWords + synthesisWords
    }

    /// Подбирает слова для операции, отдавая приоритет целевым звукам ребёнка.
    /// Для `position` целевой звук подсветит знакомую ребёнку фонему.
    static func words(
        for operation: PhonemeOperation,
        targetSounds: [String]
    ) -> [PhonemicWord] {
        let pool: [PhonemicWord]
        switch operation {
        case .position:  pool = positionWords
        case .count:     pool = countWords
        case .synthesis: pool = synthesisWords
        }
        guard !targetSounds.isEmpty else { return pool }
        let normalized = Set(targetSounds.map { $0.uppercased() })
        let preferred = pool.filter { normalized.contains($0.targetSound.uppercased()) }
        // Если по целевым звукам слов мало — дополняем общим пулом.
        if preferred.count >= roundsPerSession / 3 {
            return preferred + pool.filter { !preferred.contains($0) }
        }
        return pool
    }
}

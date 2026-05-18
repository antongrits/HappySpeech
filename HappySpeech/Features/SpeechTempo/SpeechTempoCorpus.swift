import Foundation

// MARK: - SpeechTempoCorpus
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Корпус считалок, потешек и коротких чистоговорок с разметкой слогового
// рисунка. Фольклорная и частотная лексика — онтогенетически естественна
// для ритмизации речи (5–8 лет). Полностью offline / on-device.
//
// Слоговая разметка отражает естественное послоговое деление при медленном
// проговаривании — основа ритмизованной речи.

enum SpeechTempoCorpus {

    /// Сколько чистоговорок в одной сессии (8–10 мин, антифатиговое правило).
    static let rhymesPerSession = 5

    /// Все считалки и чистоговорки корпуса.
    static let rhymes: [TempoRhyme] = [
        .init(id: "rhy-soroka",
              text: "Со-ро-ка-бе-ло-бо-ка",
              syllables: ["со", "ро", "ка", "бе", "ло", "бо", "ка"]),
        .init(id: "rhy-vodichka",
              text: "Во-ди-чка-во-ди-чка",
              syllables: ["во", "ди", "чка", "во", "ди", "чка"]),
        .init(id: "rhy-sa-sa-sa",
              text: "Са-са-са — ле-тит о-са",
              syllables: ["са", "са", "са", "ле", "тит", "о", "са"]),
        .init(id: "rhy-shi-shi-shi",
              text: "Ши-ши-ши — что-то ма-лы-ши",
              syllables: ["ши", "ши", "ши", "что", "то", "ма", "лы", "ши"]),
        .init(id: "rhy-ra-ra-ra",
              text: "Ра-ра-ра — вы-со-ка-я го-ра",
              syllables: ["ра", "ра", "ра", "вы", "со", "ка", "я", "го", "ра"]),
        .init(id: "rhy-lu-lu-lu",
              text: "Лу-лу-лу — то-чу я пи-лу",
              syllables: ["лу", "лу", "лу", "то", "чу", "я", "пи", "лу"]),
        .init(id: "rhy-zaika",
              text: "За-инь-ка-за-инь-ка",
              syllables: ["за", "инь", "ка", "за", "инь", "ка"]),
        .init(id: "rhy-tili-bom",
              text: "Ти-ли-бом-ти-ли-бом",
              syllables: ["ти", "ли", "бом", "ти", "ли", "бом"]),
        .init(id: "rhy-doshchik",
              text: "До-ждик-до-ждик-по-ли-вай",
              syllables: ["до", "ждик", "до", "ждик", "по", "ли", "вай"]),
        .init(id: "rhy-ko-ko-ko",
              text: "Ко-ко-ко — мо-ло-ко да-ле-ко",
              syllables: ["ко", "ко", "ко", "мо", "ло", "ко", "да", "ле", "ко"])
    ]

    /// Подбирает чистоговорки для сессии. Если у ребёнка есть целевые звуки —
    /// в начало ставятся чистоговорки с этими звуками.
    static func session(for targetSounds: [String]) -> [TempoRhyme] {
        guard !targetSounds.isEmpty else {
            return Array(rhymes.shuffled().prefix(rhymesPerSession))
        }
        let normalized = targetSounds.map { $0.lowercased() }
        let preferred = rhymes.filter { rhyme in
            normalized.contains { sound in rhyme.text.lowercased().contains(sound) }
        }
        let rest = rhymes.filter { !preferred.contains($0) }
        return Array((preferred.shuffled() + rest.shuffled()).prefix(rhymesPerSession))
    }
}

import Foundation
import OSLog

// MARK: - SpeechTempoCorpus
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Корпус считалок, потешек и коротких чистоговорок с разметкой слогового
// рисунка. Фольклорная и частотная лексика — онтогенетически естественна
// для ритмизации речи (5–8 лет).
//
// Контент загружается из бандл-ресурса `pack_tempo.json` (~70 чистоговорок).
// Слоговая разметка отражает естественное послоговое деление при медленном
// проговаривании — основа ритмизованной речи. Полностью offline / on-device.

enum SpeechTempoCorpus {

    /// Сколько чистоговорок в одной сессии (8–10 мин, антифатиговое правило).
    static let rhymesPerSession = SpeechTempoPackLoader.shared.rhymesPerSession

    /// Все считалки и чистоговорки корпуса.
    static let rhymes: [TempoRhyme] = SpeechTempoPackLoader.shared.rhymes

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

// MARK: - SpeechTempoPackLoader
//
// Разбирает `pack_tempo.json` один раз. При отказе бандла возвращает
// безопасный минимальный набор, чтобы модуль оставался рабочим.

struct SpeechTempoPackLoader {

    static let shared = SpeechTempoPackLoader()

    let rhymesPerSession: Int
    let rhymes: [TempoRhyme]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechTempo.PackLoader"
    )

    private struct Pack: Decodable {
        let rhymesPerSession: Int
        let rhymes: [RhymeDTO]
    }

    private struct RhymeDTO: Decodable {
        let id: String
        let text: String
        let syllables: [String]
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "pack_tempo", withExtension: "json") else {
            Self.logger.error("pack_tempo.json not found in bundle — using fallback")
            rhymesPerSession = 5
            rhymes = SpeechTempoPackLoader.fallbackRhymes
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            rhymesPerSession = pack.rhymesPerSession
            rhymes = pack.rhymes.map { dto in
                TempoRhyme(id: dto.id, text: dto.text, syllables: dto.syllables)
            }
        } catch {
            Self.logger.error(
                "pack_tempo.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            rhymesPerSession = 5
            rhymes = SpeechTempoPackLoader.fallbackRhymes
        }
    }

    /// Минимальный безопасный набор на случай отказа бандла.
    private static let fallbackRhymes: [TempoRhyme] = [
        .init(id: "rhy-soroka", text: "Со-ро-ка-бе-ло-бо-ка",
              syllables: ["со", "ро", "ка", "бе", "ло", "бо", "ка"]),
        .init(id: "rhy-sa-sa-sa", text: "Са-са-са — ле-тит о-са",
              syllables: ["са", "са", "са", "ле", "тит", "о", "са"]),
        .init(id: "rhy-ra-ra-ra", text: "Ра-ра-ра — вы-со-ка-я го-ра",
              syllables: ["ра", "ра", "ра", "вы", "со", "ка", "я", "го", "ра"]),
        .init(id: "rhy-lu-lu-lu", text: "Лу-лу-лу — то-чу я пи-лу",
              syllables: ["лу", "лу", "лу", "то", "чу", "я", "пи", "лу"]),
        .init(id: "rhy-tili-bom", text: "Ти-ли-бом-ти-ли-бом",
              syllables: ["ти", "ли", "бом", "ти", "ли", "бом"])
    ]
}

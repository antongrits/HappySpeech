import Foundation
import OSLog

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
// (оглушение согласных в конце слова, без мягкого знака как отдельного
// звука). Контент загружается из `pack_phonemic_analysis.json` (~200 слов).
// Полностью offline / on-device.

enum PhonemicListeningCorpus {

    /// Сколько раундов в одной сессии (8–12 мин, антифатиговое правило).
    static let roundsPerSession = PhonemicListeningPackLoader.shared.roundsPerSession

    /// Слова для операции «позиция звука».
    static let positionWords: [PhonemicWord] = PhonemicListeningPackLoader.shared.positionWords

    /// Слова для операции «количество звуков».
    static let countWords: [PhonemicWord] = PhonemicListeningPackLoader.shared.countWords

    /// Слова для операции «синтез слова из звуков».
    static let synthesisWords: [PhonemicWord] = PhonemicListeningPackLoader.shared.synthesisWords

    /// Все слова корпуса (для покрытия тестами / отладки).
    static var allWords: [PhonemicWord] {
        positionWords + countWords + synthesisWords
    }

    /// Подбирает слова для операции, отдавая приоритет целевым звукам ребёнка.
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
        if preferred.count >= roundsPerSession / 3 {
            return preferred + pool.filter { !preferred.contains($0) }
        }
        return pool
    }
}

// MARK: - PhonemicListeningPackLoader
//
// Разбирает `pack_phonemic_analysis.json` один раз. При отказе бандла
// возвращает безопасный минимальный набор, чтобы модуль оставался рабочим.

struct PhonemicListeningPackLoader {

    static let shared = PhonemicListeningPackLoader()

    let roundsPerSession: Int
    let positionWords: [PhonemicWord]
    let countWords: [PhonemicWord]
    let synthesisWords: [PhonemicWord]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemicListening.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let positionWords: [WordDTO]
        let countWords: [WordDTO]
        let synthesisWords: [WordDTO]
    }

    private struct WordDTO: Decodable {
        let id: String
        let text: String
        let targetSound: String
        let position: String
        let sounds: [String]
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_phonemic_analysis", withExtension: "json"
        ) else {
            Self.logger.error("pack_phonemic_analysis.json not found in bundle — using fallback")
            roundsPerSession = 9
            positionWords = PhonemicListeningPackLoader.fallbackPosition
            countWords = PhonemicListeningPackLoader.fallbackCount
            synthesisWords = PhonemicListeningPackLoader.fallbackSynthesis
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = pack.roundsPerSession
            positionWords = pack.positionWords.compactMap(Self.makeWord)
            countWords = pack.countWords.compactMap(Self.makeWord)
            synthesisWords = pack.synthesisWords.compactMap(Self.makeWord)
        } catch {
            Self.logger.error(
                "pack_phonemic_analysis.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 9
            positionWords = PhonemicListeningPackLoader.fallbackPosition
            countWords = PhonemicListeningPackLoader.fallbackCount
            synthesisWords = PhonemicListeningPackLoader.fallbackSynthesis
        }
    }

    private static func makeWord(_ dto: WordDTO) -> PhonemicWord? {
        guard let position = PhonemePosition(rawValue: dto.position) else {
            logger.error("Unknown position: \(dto.position, privacy: .public)")
            return nil
        }
        return PhonemicWord(
            id: dto.id,
            text: dto.text,
            targetSound: dto.targetSound,
            position: position,
            sounds: dto.sounds
        )
    }

    // MARK: Fallback

    private static let fallbackPosition: [PhonemicWord] = [
        .init(id: "pos-sok", text: "сок", targetSound: "С",
              position: .start, sounds: ["с", "о", "к"]),
        .init(id: "pos-osa", text: "оса", targetSound: "С",
              position: .middle, sounds: ["о", "с", "а"]),
        .init(id: "pos-nos", text: "нос", targetSound: "С",
              position: .end, sounds: ["н", "о", "с"]),
        .init(id: "pos-rak", text: "рак", targetSound: "Р",
              position: .start, sounds: ["р", "а", "к"]),
        .init(id: "pos-luk", text: "лук", targetSound: "Л",
              position: .start, sounds: ["л", "у", "к"])
    ]

    private static let fallbackCount: [PhonemicWord] = [
        .init(id: "cnt-dom", text: "дом", targetSound: "Д",
              position: .start, sounds: ["д", "о", "м"]),
        .init(id: "cnt-mak", text: "мак", targetSound: "М",
              position: .start, sounds: ["м", "а", "к"]),
        .init(id: "cnt-kit", text: "кит", targetSound: "К",
              position: .start, sounds: ["к", "и", "т"]),
        .init(id: "cnt-luna", text: "луна", targetSound: "Л",
              position: .start, sounds: ["л", "у", "н", "а"]),
        .init(id: "cnt-roza", text: "роза", targetSound: "Р",
              position: .start, sounds: ["р", "о", "з", "а"])
    ]

    private static let fallbackSynthesis: [PhonemicWord] = [
        .init(id: "syn-sok", text: "сок", targetSound: "С",
              position: .start, sounds: ["с", "о", "к"]),
        .init(id: "syn-kot", text: "кот", targetSound: "К",
              position: .start, sounds: ["к", "о", "т"]),
        .init(id: "syn-mak", text: "мак", targetSound: "М",
              position: .start, sounds: ["м", "а", "к"]),
        .init(id: "syn-dom", text: "дом", targetSound: "Д",
              position: .start, sounds: ["д", "о", "м"]),
        .init(id: "syn-luk", text: "лук", targetSound: "Л",
              position: .start, sounds: ["л", "у", "к"])
    ]
}

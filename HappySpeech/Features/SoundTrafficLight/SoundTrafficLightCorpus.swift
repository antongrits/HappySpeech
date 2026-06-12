import Foundation
import OSLog

// MARK: - SoundTrafficLightCorpus
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Корпус пар дифференцируемых звуков, по ~30 слов на звук (60+ единиц на
// пару). Лексика — частотная, возрастная (5–8 лет), без сложных кластеров.
// Методическая основа: дифференциация акустически близких пар на этапе
// автоматизации ([[correction-stages]], Ткаченко).
//
// Контент загружается из бандл-ресурса `pack_differentiation.json`.
// Полностью offline / on-device.

enum SoundTrafficLightCorpus {

    /// Все пары дифференциации (из `pack_differentiation.json`).
    static let pairs: [DifferentiationPair] = SoundTrafficLightPackLoader.shared.pairs

    /// Размер раунда игры (число слов на сессию уровня СЛОВО).
    static let roundsPerSession = SoundTrafficLightPackLoader.shared.roundsPerSession

    /// Число слогов на сессию уровня СЛОГ.
    static let syllablesPerSession = SoundTrafficLightPackLoader.shared.syllablesPerSession

    /// Возвращает пару по идентификатору.
    static func pair(forId id: String) -> DifferentiationPair? {
        pairs.first { $0.id == id }
    }

    /// Подбирает пару, релевантную целевым звукам ребёнка.
    /// Если соответствия нет — возвращает первую пару (С–Ш как базовую).
    static func recommendedPair(for targetSounds: [String]) -> DifferentiationPair {
        let target = Set(targetSounds)
        let match = pairs.first { pair in
            target.contains(pair.soundA) || target.contains(pair.soundB)
        }
        return match ?? pairs.first ?? SoundTrafficLightPackLoader.fallbackPairs[0]
    }
}

// MARK: - SoundTrafficLightPackLoader
//
// Разбирает `pack_differentiation.json` один раз. При отказе бандла
// возвращает безопасный минимальный набор, чтобы модуль оставался рабочим.

struct SoundTrafficLightPackLoader {

    static let shared = SoundTrafficLightPackLoader()

    let roundsPerSession: Int
    /// Число слогов в одной сессии уровня СЛОГ.
    let syllablesPerSession: Int
    let pairs: [DifferentiationPair]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let syllablesPerSession: Int?
        let pairs: [PairDTO]
    }

    private struct PairDTO: Decodable {
        let id: String
        let soundA: String
        let soundB: String
        let syllablesA: [String]?
        let syllablesB: [String]?
        let wordsA: [String]
        let wordsB: [String]
        let phrases: [PhraseDTO]?
        let texts: [TextDTO]?
    }

    private struct PhraseDTO: Decodable {
        let text: String
        let sound: String
        let wordsA: [String]
        let wordsB: [String]
    }

    private struct TextDTO: Decodable {
        let title: String
        let lines: [String]
        let countA: Int
        let countB: Int
        let source: String
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_differentiation", withExtension: "json"
        ) else {
            Self.logger.error("pack_differentiation.json not found in bundle — using fallback")
            roundsPerSession = 8
            syllablesPerSession = 6
            pairs = SoundTrafficLightPackLoader.fallbackPairs
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = pack.roundsPerSession
            syllablesPerSession = pack.syllablesPerSession ?? 6
            pairs = pack.pairs.map(Self.makePair)
        } catch {
            Self.logger.error(
                "pack_differentiation.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 8
            syllablesPerSession = 6
            pairs = SoundTrafficLightPackLoader.fallbackPairs
        }
    }

    /// Преобразует DTO пары в доменную модель, сохраняя стабильные id для
    /// фраз/текстов (id-схема `<pairId>-phrase-N` / `<pairId>-text-N`).
    private static func makePair(_ dto: PairDTO) -> DifferentiationPair {
        let phrases = (dto.phrases ?? []).enumerated().map { index, phrase in
            TrafficLightPhrase(
                id: "\(dto.id)-phrase-\(index)",
                text: phrase.text,
                dominant: TrafficLightPhrase.Dominant(rawValue: phrase.sound) ?? .both,
                wordsA: phrase.wordsA,
                wordsB: phrase.wordsB
            )
        }
        let texts = (dto.texts ?? []).enumerated().map { index, text in
            TrafficLightText(
                id: "\(dto.id)-text-\(index)",
                title: text.title,
                lines: text.lines,
                countA: text.countA,
                countB: text.countB,
                source: text.source
            )
        }
        return DifferentiationPair(
            id: dto.id,
            soundA: dto.soundA,
            soundB: dto.soundB,
            syllablesA: dto.syllablesA ?? [],
            syllablesB: dto.syllablesB ?? [],
            wordsA: dto.wordsA,
            wordsB: dto.wordsB,
            phrases: phrases,
            texts: texts
        )
    }

    /// Минимальный безопасный набор на случай отказа бандла.
    static let fallbackPairs: [DifferentiationPair] = [
        .init(id: "pair-s-sh", soundA: "С", soundB: "Ш",
              wordsA: ["санки", "сова", "суп", "сок", "сыр", "сумка",
                       "собака", "стол", "сапоги", "снег", "слон", "сани"],
              wordsB: ["шапка", "шуба", "шар", "шкаф", "шум", "шина",
                       "шишка", "шмель", "шорты", "школа", "шахматы", "шалаш"]),
        .init(id: "pair-r-l", soundA: "Р", soundB: "Л",
              wordsA: ["рыба", "рак", "роза", "ракета", "рука", "радуга",
                       "ручка", "рысь", "ромашка", "робот", "рубашка", "ворота"],
              wordsB: ["лампа", "лук", "лиса", "лодка", "лимон", "лопата",
                       "лужа", "ложка", "лестница", "лето", "молоко", "пила"])
    ]
}

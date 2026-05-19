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

    /// Размер раунда игры (число слов на сессию).
    static let roundsPerSession = SoundTrafficLightPackLoader.shared.roundsPerSession

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
    let pairs: [DifferentiationPair]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let pairs: [PairDTO]
    }

    private struct PairDTO: Decodable {
        let id: String
        let soundA: String
        let soundB: String
        let wordsA: [String]
        let wordsB: [String]
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_differentiation", withExtension: "json"
        ) else {
            Self.logger.error("pack_differentiation.json not found in bundle — using fallback")
            roundsPerSession = 8
            pairs = SoundTrafficLightPackLoader.fallbackPairs
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = pack.roundsPerSession
            pairs = pack.pairs.map { dto in
                DifferentiationPair(
                    id: dto.id,
                    soundA: dto.soundA,
                    soundB: dto.soundB,
                    wordsA: dto.wordsA,
                    wordsB: dto.wordsB
                )
            }
        } catch {
            Self.logger.error(
                "pack_differentiation.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 8
            pairs = SoundTrafficLightPackLoader.fallbackPairs
        }
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

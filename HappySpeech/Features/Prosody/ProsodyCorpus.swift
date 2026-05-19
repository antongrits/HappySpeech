import Foundation
import OSLog

// MARK: - ProsodyCorpus
//
// v29 Фаза 8, Функция 1 «Голосовые краски».
//
// Корпус коротких фраз, размеченных по типу интонации (повествование /
// вопрос / восклицание) и привязанных к лексическим темам. Лексика —
// частотная, возрастная (6–8 лет), короткие фразы 2–5 слов (методически
// верно для работы над мелодикой: Лопатина).
//
// Контент загружается из бандл-ресурса `pack_prosody.json` (~150 фраз).
// Полностью offline / on-device.

enum ProsodyCorpus {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Prosody.Corpus"
    )

    /// Сколько раундов в одной сессии (8–12 мин, антифатиговое правило).
    static let roundsPerSession = ProsodyPackLoader.shared.roundsPerSession

    // MARK: - Phrases

    /// Полный размеченный корпус фраз (из `pack_prosody.json`).
    static let phrases: [ProsodyPhrase] = ProsodyPackLoader.shared.phrases

    // MARK: - Queries

    /// Все фразы данного типа интонации.
    static func phrases(of type: IntonationType) -> [ProsodyPhrase] {
        phrases.filter { $0.intonation == type }
    }

    /// Собирает методически упорядоченную сессию: на каждом этапе берётся
    /// сбалансированный набор фраз всех трёх типов интонации.
    static func sessionPhrases() -> [ProsodyPhrase] {
        var pool: [ProsodyPhrase] = []
        for type in IntonationType.allCases {
            pool.append(contentsOf: phrases(of: type).shuffled().prefix(3))
        }
        return pool
    }
}

// MARK: - ProsodyPackLoader
//
// Разбирает `pack_prosody.json` один раз при старте. При отказе бандла —
// возвращает безопасный минимальный набор, чтобы модуль оставался рабочим.

struct ProsodyPackLoader {

    static let shared = ProsodyPackLoader()

    let roundsPerSession: Int
    let phrases: [ProsodyPhrase]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Prosody.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let phrases: [PhraseDTO]
    }

    private struct PhraseDTO: Decodable {
        let id: String
        let text: String
        let intonation: String
        let theme: String
    }

    private init() {
        guard let url = Bundle.main.url(forResource: "pack_prosody", withExtension: "json") else {
            Self.logger.error("pack_prosody.json not found in bundle — using fallback")
            roundsPerSession = 9
            phrases = ProsodyPackLoader.fallbackPhrases
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = pack.roundsPerSession
            phrases = pack.phrases.compactMap { dto in
                guard let intonation = IntonationType(rawValue: dto.intonation) else {
                    Self.logger.error("Unknown intonation: \(dto.intonation, privacy: .public)")
                    return nil
                }
                return ProsodyPhrase(
                    id: dto.id,
                    text: dto.text,
                    intonation: intonation,
                    theme: dto.theme
                )
            }
        } catch {
            Self.logger.error(
                "pack_prosody.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 9
            phrases = ProsodyPackLoader.fallbackPhrases
        }
    }

    /// Минимальный безопасный набор на случай отказа бандла.
    private static let fallbackPhrases: [ProsodyPhrase] = [
        .init(id: "dec-1", text: "Кошка спит на коврике.",
              intonation: .declarative, theme: "Домашние животные"),
        .init(id: "dec-2", text: "На улице идёт дождь.",
              intonation: .declarative, theme: "Времена года"),
        .init(id: "dec-3", text: "Мама готовит вкусный суп.",
              intonation: .declarative, theme: "Семья"),
        .init(id: "int-1", text: "Ты любишь мороженое?",
              intonation: .interrogative, theme: "Еда"),
        .init(id: "int-2", text: "Где живёт медведь?",
              intonation: .interrogative, theme: "Дикие животные"),
        .init(id: "int-3", text: "Куда поехал автобус?",
              intonation: .interrogative, theme: "Транспорт"),
        .init(id: "exc-1", text: "Какой красивый закат!",
              intonation: .exclamatory, theme: "Времена года"),
        .init(id: "exc-2", text: "Ура, наступило лето!",
              intonation: .exclamatory, theme: "Времена года"),
        .init(id: "exc-3", text: "Смотри, какая радуга!",
              intonation: .exclamatory, theme: "Времена года")
    ]
}

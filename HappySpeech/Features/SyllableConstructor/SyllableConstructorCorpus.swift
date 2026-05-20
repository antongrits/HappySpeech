import Foundation
import OSLog

// MARK: - SyllableConstructorCorpus
//
// v31 Волна B, Функция Ф.1 «Слог-конструктор».
//
// Загрузчик корпуса слогового материала из bundled JSON
// `Content/Seed/pack_syllables.json`. Содержит 80+ слов, разбитых на 4
// уровня по классам Марковой. Полностью offline / on-device.

public enum SyllableConstructorCorpus {

    // MARK: - Public API

    /// Все слова корпуса (загружаются один раз, кэшируются).
    public static var allWords: [SyllableWord] {
        loadOnce()
    }

    /// Возвращает слова заданного уровня сложности.
    public static func words(for tier: SyllableTier) -> [SyllableWord] {
        allWords.filter { $0.tier == tier }
    }

    /// Возвращает массив всех уровней, для которых в корпусе есть хотя бы одно слово.
    public static var availableTiers: [SyllableTier] {
        let present = Set(allWords.map(\.tier))
        return SyllableTier.allCases.filter { present.contains($0) }
    }

    // MARK: - Private state

    private nonisolated(unsafe) static var cached: [SyllableWord] = []
    private nonisolated(unsafe) static var didLoad = false
    private static let cacheLock = NSLock()

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableConstructor.Corpus"
    )

    private static func loadOnce() -> [SyllableWord] {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        if didLoad { return cached }
        didLoad = true
        cached = decodeBundledPack()
        logger.info("SyllableCorpus loaded: \(cached.count, privacy: .public) words")
        return cached
    }

    private static func decodeBundledPack() -> [SyllableWord] {
        guard let url = Bundle.main.url(forResource: "pack_syllables", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            logger.warning("pack_syllables.json не найден в bundle — корпус пуст")
            return []
        }
        do {
            let pack = try JSONDecoder().decode(SyllablePackDTO.self, from: data)
            return pack.tiers.flatMap { tierDTO in
                tierDTO.words.compactMap { wordDTO in
                    guard let tier = SyllableTier(rawValue: tierDTO.tier) else { return nil }
                    return SyllableWord(
                        id: wordDTO.id,
                        word: wordDTO.word,
                        syllables: wordDTO.syllables,
                        tier: tier,
                        symbolName: wordDTO.symbol,
                        audioPhraseId: wordDTO.audioPhraseId
                    )
                }
            }
        } catch {
            logger.error("pack_syllables.json decode error: \(error.localizedDescription, privacy: .public)")
            return []
        }
    }
}

// MARK: - JSON DTOs

private struct SyllablePackDTO: Decodable {
    let tiers: [TierDTO]

    struct TierDTO: Decodable {
        let tier: Int
        let words: [WordDTO]
    }

    struct WordDTO: Decodable {
        let id: String
        let word: String
        let syllables: [String]
        let symbol: String?
        let audioPhraseId: String?
    }
}

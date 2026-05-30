import Foundation
import OSLog

// MARK: - SyllableSnailCorpus
//
// F2-003 «Слоговая улитка» (Wave 2).
//
// Корпус слов со слоговой разметкой, картинкой, классом Марковой, по-слоговой
// озвучкой и преднабором перестановки. Загружается из
// `pack_syllable_snail.json` (своя схема — НЕ ломает существующий
// `pack_syllables.json`). Все `imageAsset` проверены по `word_manifest.json`.
// Полностью offline / on-device.

enum SyllableSnailCorpus {

    /// Сколько раундов в одной сессии (9–12, антифатиговое правило).
    static var roundsPerSession: Int { SyllableSnailPackLoader.shared.roundsPerSession }

    /// Все слова корпуса.
    static var allWords: [SnailWord] { SyllableSnailPackLoader.shared.words }

    /// Слова заданного уровня сложности.
    static func words(for tier: SyllableTier) -> [SnailWord] {
        allWords.filter { $0.tier == tier }
    }

    /// Уровни, для которых в корпусе есть хотя бы одно слово.
    static var availableTiers: [SyllableTier] {
        let present = Set(allWords.map(\.tier))
        return SyllableTier.allCases.filter { present.contains($0) }
    }

    /// Слова, пригодные для режима. Режим A (clap) работает на словах с ≥ 1
    /// слогом (любых); B/C требуют ≥ 2 слогов (нечего собирать/чинить из
    /// одного слога — для tier 4 односложных слов это означает их пропуск в
    /// build/fix; worker добивает многосложными).
    static func words(for tier: SyllableTier, mode: SnailMode) -> [SnailWord] {
        let pool = words(for: tier)
        switch mode {
        case .clap:
            return pool
        case .build, .fix:
            return pool.filter { $0.syllables.count >= 2 }
        }
    }
}

// MARK: - SyllableSnailPackLoader
//
// Разбирает `pack_syllable_snail.json` один раз. При отказе бандла возвращает
// безопасный минимальный набор, чтобы модуль оставался рабочим.

struct SyllableSnailPackLoader {

    static let shared = SyllableSnailPackLoader()

    let roundsPerSession: Int
    let words: [SnailWord]

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableSnail.PackLoader"
    )

    private struct Pack: Decodable {
        let roundsPerSession: Int
        let tiers: [TierDTO]
    }

    private struct TierDTO: Decodable {
        let tier: Int
        let words: [WordDTO]
    }

    private struct WordDTO: Decodable {
        let id: String
        let word: String
        let syllables: [String]
        let tier: Int
        let imageAsset: String
        let markovaClass: Int
        let audioSyllables: [String]?
        let scrambledHints: [String]?
    }

    private init() {
        guard let url = Bundle.main.url(
            forResource: "pack_syllable_snail", withExtension: "json"
        ) else {
            Self.logger.error("pack_syllable_snail.json not found in bundle — using fallback")
            roundsPerSession = 10
            words = SyllableSnailPackLoader.fallbackWords
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let pack = try JSONDecoder().decode(Pack.self, from: data)
            roundsPerSession = max(6, pack.roundsPerSession)
            let decoded = pack.tiers.flatMap { tierDTO in
                tierDTO.words.compactMap(Self.makeWord)
            }
            words = decoded.isEmpty ? SyllableSnailPackLoader.fallbackWords : decoded
        } catch {
            Self.logger.error(
                "pack_syllable_snail.json decode error: \(error.localizedDescription, privacy: .public)"
            )
            roundsPerSession = 10
            words = SyllableSnailPackLoader.fallbackWords
        }
    }

    private static func makeWord(_ dto: WordDTO) -> SnailWord? {
        guard let tier = SyllableTier(rawValue: dto.tier) else {
            logger.error("Unknown tier: \(dto.tier, privacy: .public)")
            return nil
        }
        let base = SyllableWord(
            id: dto.id,
            word: dto.word,
            syllables: dto.syllables,
            tier: tier
        )
        return SnailWord(
            base: base,
            imageAsset: dto.imageAsset,
            markovaClass: dto.markovaClass,
            audioSyllables: dto.audioSyllables ?? dto.syllables,
            scrambledHints: dto.scrambledHints ?? []
        )
    }

    // MARK: Fallback (минимальный рабочий набор по тирам)

    /// Декларативное описание fallback-слова (разворачивается в `SnailWord`).
    private struct FallbackSeed {
        let id: String
        let word: String
        let syllables: [String]
        let tier: SyllableTier
        let asset: String
        let markova: Int
        let audio: [String]
        let scrambled: [String]
    }

    private static let fallbackSeeds: [FallbackSeed] = [
        FallbackSeed(id: "sn-fb-luna", word: "луна", syllables: ["лу", "на"],
                     tier: .twoSyllablesOpen, asset: "word_moon", markova: 1,
                     audio: ["lu", "na"], scrambled: ["на", "лу"]),
        FallbackSeed(id: "sn-fb-vagon", word: "вагон", syllables: ["ва", "гон"],
                     tier: .twoSyllablesOpen, asset: "word_vagon", markova: 3,
                     audio: ["va", "gon"], scrambled: ["гон", "ва"]),
        FallbackSeed(id: "sn-fb-mashina", word: "машина", syllables: ["ма", "ши", "на"],
                     tier: .threeSyllablesWithClosed, asset: "word_car", markova: 6,
                     audio: ["ma", "shi", "na"], scrambled: ["ши", "на", "ма"]),
        FallbackSeed(id: "sn-fb-pomidor", word: "помидор", syllables: ["по", "ми", "дор"],
                     tier: .threeSyllablesWithClosed, asset: "word_pomidor", markova: 8,
                     audio: ["po", "mi", "dor"], scrambled: ["ми", "дор", "по"]),
        FallbackSeed(id: "sn-fb-kniga", word: "книга", syllables: ["кни", "га"],
                     tier: .consonantCluster, asset: "word_book", markova: 11,
                     audio: ["kni", "ga"], scrambled: ["га", "кни"]),
        FallbackSeed(id: "sn-fb-stol", word: "стол", syllables: ["стол"],
                     tier: .consonantCluster, asset: "word_stol", markova: 9,
                     audio: ["stol"], scrambled: [])
    ]

    private static let fallbackWords: [SnailWord] = fallbackSeeds.map { seed in
        SnailWord(
            base: SyllableWord(id: seed.id, word: seed.word, syllables: seed.syllables, tier: seed.tier),
            imageAsset: seed.asset,
            markovaClass: seed.markova,
            audioSyllables: seed.audio,
            scrambledHints: seed.scrambled
        )
    }
}

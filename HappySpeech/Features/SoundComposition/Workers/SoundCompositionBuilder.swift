import Foundation
import OSLog

// MARK: - SoundCompositionBuilder
//
// Worker «Мастерской звукового состава». Две задачи:
//   1. Загрузка контент-пака `pack_sound_analysis.json` → `[SoundCompositionWord]`.
//   2. Генерация эльконинской цветовой схемы из фонемной транскрипции
//      (`classify(letters:)`) — чистая методическая логика (тестируема).
//
// Классификация (Д. Б. Эльконин, Л. Е. Журова, Г. А. Каше):
//   • гласный  — буква-звук из {А,О,У,Ы,Э,Я,Ё,Ю,Е,И} → .vowel (красный);
//   • всегда твёрдые — {Ж,Ш,Ц} → .hard (синий);
//   • всегда мягкие  — {Ч,Щ,Й} → .soft (зелёный);
//   • парный согласный — мягкий, если СЛЕДУЮЩАЯ буква-звук смягчающая
//     {И,Е,Ё,Ю,Я,Ь}, иначе твёрдый.
//
// Замечание: транскрипция в паке — звуковая (не буквенная): мягкий знак как
// отдельный звук не выделяется, оглушение/озвончение уже учтено в данных пака.
// `classify` — резерв и валидатор: если у звука в паке нет явного `type`,
// строитель выводит его правилом; в юнит-тестах правило проверяется на словах.

@MainActor
final class SoundCompositionBuilder {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SoundCompositionBuilder")

    // MARK: - Public: pack loading

    /// Загружает слова из `pack_sound_analysis.json`. Если пак не найден или
    /// повреждён — возвращает встроенный fallback-набор (тоже реальные слова),
    /// чтобы игра никогда не оставалась пустой.
    func loadWords() -> [SoundCompositionWord] {
        guard let raw = Self.loadPack() else {
            logger.warning("pack_sound_analysis.json missing — using built-in fallback set")
            return Self.fallbackWords()
        }
        var words = raw.words.compactMap { Self.makeWord(from: $0, chains: raw.chains) }
        // Слова-базы цепочек (мак, кот) тоже делаем анализируемыми и наделяем
        // их бонус-цепочкой замены первого звука.
        let chainWords = raw.chains.compactMap { Self.makeChainBaseWord(from: $0) }
        let existing = Set(words.map { $0.text.lowercased() })
        words.append(contentsOf: chainWords.filter { !existing.contains($0.text.lowercased()) })
        guard !words.isEmpty else {
            logger.warning("pack_sound_analysis.json produced 0 words — using fallback")
            return Self.fallbackWords()
        }
        logger.info("loaded \(words.count, privacy: .public) sound-analysis words")
        return words
    }

    /// Подбирает до `count` слов для сессии: для младших — короткие (easy),
    /// для старших — добавляет medium. Чередует звуковую структуру и гарантирует,
    /// что слово с бонус-цепочкой стоит последним (для финального бонуса).
    func buildSession(from words: [SoundCompositionWord], age: Int, count: Int) -> [SoundCompositionWord] {
        guard !words.isEmpty else { return [] }
        // 6–7 лет — только 3–4 звука; 7–8 — можно 5.
        let maxSounds = age >= 7 ? 5 : 4
        let eligible = words.filter { $0.soundCount <= maxSounds }
        let pool = eligible.isEmpty ? words : eligible

        // Антифатиговое чередование: не два одинаковых по числу звуков подряд.
        var ordered: [SoundCompositionWord] = []
        var remaining = pool
        var lastCount = -1
        while ordered.count < count, !remaining.isEmpty {
            if let idx = remaining.firstIndex(where: { $0.soundCount != lastCount }) ?? remaining.indices.first {
                let picked = remaining.remove(at: idx)
                ordered.append(picked)
                lastCount = picked.soundCount
            } else {
                break
            }
        }

        // Если слов с цепочкой есть — поставим одно в конец для бонуса.
        if let chainIdx = ordered.lastIndex(where: { $0.chain != nil }), chainIdx != ordered.count - 1 {
            let item = ordered.remove(at: chainIdx)
            ordered.append(item)
        } else if !ordered.contains(where: { $0.chain != nil }),
                  let chained = pool.first(where: { $0.chain != nil }) {
            if ordered.count == count { ordered.removeLast() }
            ordered.append(chained)
        }

        return Array(ordered.prefix(count))
    }

    // MARK: - Pure: Эльконинская классификация

    private static let vowelLetters: Set<Character> = ["А", "О", "У", "Ы", "Э", "Я", "Ё", "Ю", "Е", "И"]
    private static let alwaysHard: Set<Character> = ["Ж", "Ш", "Ц"]
    private static let alwaysSoft: Set<Character> = ["Ч", "Щ", "Й"]
    private static let softeningNext: Set<Character> = ["И", "Е", "Ё", "Ю", "Я", "Ь"]

    /// Классифицирует звук по позиции в последовательности букв-звуков.
    /// `letters` — массив заглавных односимвольных строк звуковой транскрипции.
    static func classify(letters: [String], at index: Int) -> SoundType {
        guard letters.indices.contains(index),
              let ch = letters[index].uppercased().first else {
            return .hard
        }
        if vowelLetters.contains(ch) { return .vowel }
        if alwaysHard.contains(ch) { return .hard }
        if alwaysSoft.contains(ch) { return .soft }
        // Парный согласный: смотрим на следующий звук.
        if index + 1 < letters.count,
           let next = letters[index + 1].uppercased().first,
           softeningNext.contains(next) {
            return .soft
        }
        return .hard
    }

    /// Строит цветовую схему (массив типов) для заданной звуковой транскрипции.
    static func colorScheme(for letters: [String]) -> [SoundType] {
        (0..<letters.count).map { classify(letters: letters, at: $0) }
    }

    // MARK: - Pure: mapping pack → domain

    private static func makeWord(from rw: RawWord, chains: [RawChain]) -> SoundCompositionWord? {
        guard !rw.sounds.isEmpty, !rw.text.isEmpty else { return nil }
        let letters = rw.sounds.map { $0.letter }
        let sounds: [SoundUnit] = rw.sounds.enumerated().map { idx, s in
            // Доверяем явному type из пака; если он отсутствует/некорректен —
            // выводим правилом (resilience).
            let type = SoundType(rawValue: s.type) ?? classify(letters: letters, at: idx)
            return SoundUnit(letter: s.letter.uppercased(), type: type)
        }
        let chain = rw.chainId.flatMap { id in chains.first(where: { $0.id == id }) }.map(Self.makeChain)
        return SoundCompositionWord(
            id: rw.id,
            text: rw.text,
            imageAsset: rw.asset,
            stressIndex: max(1, min(rw.stressIndex, sounds.count)),
            syllables: rw.syllables,
            sounds: sounds,
            chain: chain
        )
    }

    private static func makeChain(_ rc: RawChain) -> SoundChain {
        SoundChain(
            baseText: rc.base.text,
            baseAsset: rc.base.asset,
            variants: rc.variants.map {
                SoundChain.Variant(swapTo: $0.swapTo.uppercased(), text: $0.text, asset: $0.asset)
            }
        )
    }

    /// Делает анализируемое слово из базы цепочки (мак, кот) с привязанным
    /// бонус-заданием замены первого звука.
    private static func makeChainBaseWord(from rc: RawChain) -> SoundCompositionWord? {
        guard !rc.sounds.isEmpty else { return nil }
        let letters = rc.sounds.map { $0.letter }
        let sounds: [SoundUnit] = rc.sounds.enumerated().map { idx, s in
            let type = SoundType(rawValue: s.type) ?? classify(letters: letters, at: idx)
            return SoundUnit(letter: s.letter.uppercased(), type: type)
        }
        return SoundCompositionWord(
            id: rc.id,
            text: rc.base.text,
            imageAsset: rc.base.asset,
            stressIndex: max(1, min(rc.stressIndex, sounds.count)),
            syllables: rc.syllables,
            sounds: sounds,
            chain: makeChain(rc)
        )
    }

    // MARK: - Pack DTOs

    private struct RawPack: Decodable {
        let words: [RawWord]
        let chains: [RawChain]
    }
    private struct RawWord: Decodable {
        let id: String
        let text: String
        let asset: String
        let stressIndex: Int
        let syllables: [String]
        let sounds: [RawSound]
        /// Слово может ссылаться на цепочку по её id; в текущем паке цепочки
        /// автономны, поэтому поле опционально (привязка по совпадению id).
        let chainId: String?

        enum CodingKeys: String, CodingKey {
            case id, text, asset, stressIndex, syllables, sounds, chainId
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            text = try c.decode(String.self, forKey: .text)
            asset = try c.decode(String.self, forKey: .asset)
            stressIndex = (try? c.decode(Int.self, forKey: .stressIndex)) ?? 1
            syllables = (try? c.decode([String].self, forKey: .syllables)) ?? []
            sounds = try c.decode([RawSound].self, forKey: .sounds)
            chainId = try? c.decode(String.self, forKey: .chainId)
        }
    }
    private struct RawSound: Decodable {
        let letter: String
        let type: String
    }
    private struct RawChain: Decodable {
        let id: String
        let base: RawChainWord
        let variants: [RawChainVariant]
        let stressIndex: Int
        let syllables: [String]
        let sounds: [RawSound]

        enum CodingKeys: String, CodingKey {
            case id, base, variants, stressIndex, syllables, sounds
        }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(String.self, forKey: .id)
            base = try c.decode(RawChainWord.self, forKey: .base)
            variants = try c.decode([RawChainVariant].self, forKey: .variants)
            stressIndex = (try? c.decode(Int.self, forKey: .stressIndex)) ?? 1
            syllables = (try? c.decode([String].self, forKey: .syllables)) ?? []
            sounds = (try? c.decode([RawSound].self, forKey: .sounds)) ?? []
        }
    }
    private struct RawChainWord: Decodable {
        let text: String
        let asset: String
    }
    private struct RawChainVariant: Decodable {
        let swapTo: String
        let text: String
        let asset: String
    }

    // MARK: - Pack IO

    private static func loadPack() -> RawPack? {
        guard let url = Bundle.main.url(forResource: "pack_sound_analysis", withExtension: "json")
            ?? Bundle.main.url(
                forResource: "pack_sound_analysis",
                withExtension: "json",
                subdirectory: "Seed"
            ),
            let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(RawPack.self, from: data)
    }

    // MARK: - Fallback

    /// Минимальный встроенный набор реальных слов с верифицированными ассетами —
    /// на случай отсутствия пака в бандле. Никаких пустых экранов.
    static func fallbackWords() -> [SoundCompositionWord] {
        func u(_ letter: String, _ t: SoundType) -> SoundUnit { SoundUnit(letter: letter, type: t) }
        return [
            SoundCompositionWord(
                id: "fb-kit", text: "кит", imageAsset: "word_kit",
                stressIndex: 2, syllables: ["кит"],
                sounds: [u("К", .soft), u("И", .vowel), u("Т", .hard)], chain: nil
            ),
            SoundCompositionWord(
                id: "fb-osa", text: "оса", imageAsset: "word_wasp",
                stressIndex: 3, syllables: ["о", "са"],
                sounds: [u("О", .vowel), u("С", .hard), u("А", .vowel)], chain: nil
            ),
            SoundCompositionWord(
                id: "fb-mak", text: "мак", imageAsset: "word_mak",
                stressIndex: 2, syllables: ["мак"],
                sounds: [u("М", .hard), u("А", .vowel), u("К", .hard)],
                chain: SoundChain(
                    baseText: "мак", baseAsset: "word_mak",
                    variants: [
                        SoundChain.Variant(swapTo: "Р", text: "рак", asset: "word_rak"),
                        SoundChain.Variant(swapTo: "Л", text: "лак", asset: "word_lak")
                    ]
                )
            )
        ]
    }
}

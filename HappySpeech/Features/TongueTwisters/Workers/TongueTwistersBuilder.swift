import Foundation
import OSLog

// MARK: - TongueTwistersBuilder
//
// Изолированный воркер: загружает корпус чистоговорок из
// `pack_tongue_phrases.json`, собирает сессию по возрасту ребёнка и строит
// детерминированно-перемешанные варианты-ответы для строки-рифмы.
//
// Детерминизм: порядок вариантов и отбор чистоговорок зависят только от
// `childId` (стабильный seed) — одинаковая сессия при повторном входе того же
// ребёнка, разная между детьми. Никакого `Int.random` в проде.

@MainActor
final class TongueTwistersBuilder {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "TongueTwisters.Builder"
    )

    // MARK: - Public API

    /// Загружает все чистоговорки из пака (или fallback при отсутствии бандл-файла).
    func loadPhrases() -> [TonguePhrase] {
        guard let raw = Self.loadPack(), !raw.phrases.isEmpty else {
            Self.logger.warning("pack_tongue_phrases.json отсутствует — fallback-корпус")
            return Self.fallbackPhrases()
        }
        return raw.phrases.map { Self.makePhrase(from: $0, seed: 0) }
    }

    /// Собирает сессию: отбирает по возрасту, перемешивает варианты под seed
    /// ребёнка, ограничивает длину. Чередует группы звуков (антифатиговое
    /// правило — не две подряд из одной группы, если возможно).
    func buildSession(from all: [TonguePhrase], age: Int, count: Int, childId: String) -> [TonguePhrase] {
        let seed = Self.seed(for: childId)
        let eligible = all.filter { age >= $0.minAge }
        let pool = eligible.isEmpty ? all : eligible

        // Детерминированная перестановка пула под seed ребёнка.
        var shuffled = Self.deterministicShuffle(pool, seed: seed)
        shuffled = Self.alternateGroups(shuffled)

        let limited = Array(shuffled.prefix(max(1, count)))
        // Пересобираем варианты-ответы под seed+индекс (стабильный порядок картинок).
        return limited.enumerated().map { idx, phrase in
            Self.reshuffleAnswers(phrase, seed: seed &+ UInt64(idx))
        }
    }

    // MARK: - Raw decoding

    private struct RawPack: Decodable {
        let phrases: [RawPhrase]
    }

    private struct RawPhrase: Decodable {
        let id: String
        let targetSound: String
        let group: String
        let minAge: Int
        let warmupSyllable: String
        let warmupBeats: Int
        let linePrefix: String
        let lineSuffix: String
        let answerWord: String
        let answerAsset: String
        let distractors: [RawAnswer]
        let wagons: [RawWagon]
    }

    private struct RawAnswer: Decodable {
        let word: String
        let asset: String
    }

    private struct RawWagon: Decodable {
        let text: String
        let isSyllable: Bool
    }

    // MARK: - Mapping

    private static func makePhrase(from raw: RawPhrase, seed: UInt64) -> TonguePhrase {
        let correct = RhymeAnswer(
            id: raw.id + "-correct",
            word: raw.answerWord,
            imageAsset: raw.answerAsset,
            isCorrect: true
        )
        let distractors = raw.distractors.enumerated().map { idx, d in
            RhymeAnswer(
                id: raw.id + "-d\(idx)",
                word: d.word,
                imageAsset: d.asset,
                isCorrect: false
            )
        }
        let answers = deterministicShuffle([correct] + distractors, seed: seed)
        let wagons = raw.wagons.enumerated().map { idx, w in
            WagonStep(id: idx, text: w.text, isSyllable: w.isSyllable)
        }
        return TonguePhrase(
            id: raw.id,
            targetSound: raw.targetSound,
            group: raw.group,
            minAge: raw.minAge,
            warmupSyllable: raw.warmupSyllable,
            warmupBeats: max(1, raw.warmupBeats),
            linePrefix: raw.linePrefix,
            lineSuffix: raw.lineSuffix,
            answerWord: raw.answerWord,
            answerAsset: raw.answerAsset,
            answers: answers,
            wagons: wagons
        )
    }

    /// Пересобирает порядок вариантов-ответов под новый seed (стабильный на сессию).
    private static func reshuffleAnswers(_ phrase: TonguePhrase, seed: UInt64) -> TonguePhrase {
        TonguePhrase(
            id: phrase.id,
            targetSound: phrase.targetSound,
            group: phrase.group,
            minAge: phrase.minAge,
            warmupSyllable: phrase.warmupSyllable,
            warmupBeats: phrase.warmupBeats,
            linePrefix: phrase.linePrefix,
            lineSuffix: phrase.lineSuffix,
            answerWord: phrase.answerWord,
            answerAsset: phrase.answerAsset,
            answers: deterministicShuffle(phrase.answers, seed: seed),
            wagons: phrase.wagons
        )
    }

    // MARK: - Group alternation (anti-fatigue)

    /// Переставляет так, чтобы соседние чистоговорки по возможности были из разных
    /// групп звуков (свистящие/шипящие/соноры). Жадный проход, детерминированный.
    private static func alternateGroups(_ phrases: [TonguePhrase]) -> [TonguePhrase] {
        guard phrases.count > 2 else { return phrases }
        var remaining = phrases
        var result: [TonguePhrase] = []
        var lastGroup: String?
        while !remaining.isEmpty {
            let idx = remaining.firstIndex(where: { $0.group != lastGroup }) ?? 0
            let picked = remaining.remove(at: idx)
            lastGroup = picked.group
            result.append(picked)
        }
        return result
    }

    // MARK: - Deterministic shuffle (SplitMix64)

    /// Детерминированная перестановка (Fisher–Yates на SplitMix64). Стабильна для
    /// одного seed, не использует глобальный генератор — повторимый порядок.
    static func deterministicShuffle<T>(_ array: [T], seed: UInt64) -> [T] {
        guard array.count > 1 else { return array }
        var result = array
        var state = seed &+ 0x9E37_79B9_7F4A_7C15
        func next() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
        for i in stride(from: result.count - 1, to: 0, by: -1) {
            let j = Int(next() % UInt64(i + 1))
            result.swapAt(i, j)
        }
        return result
    }

    /// Стабильный seed из childId (sum of unicode scalars). Без хеш-рандомизации
    /// между запусками (Swift `hashValue` солится per-process).
    static func seed(for childId: String) -> UInt64 {
        var hash: UInt64 = 1_469_598_103_934_665_603 // FNV-1a offset
        for byte in childId.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1_099_511_628_211
        }
        return hash
    }

    // MARK: - Pack IO

    private static func loadPack() -> RawPack? {
        guard let url = Bundle.main.url(forResource: "pack_tongue_phrases", withExtension: "json")
            ?? Bundle.main.url(
                forResource: "pack_tongue_phrases",
                withExtension: "json",
                subdirectory: "Seed"
            ),
            let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(RawPack.self, from: data)
    }

    // MARK: - Fallback

    /// Минимальный встроенный набор с верифицированными ассетами — на случай
    /// отсутствия пака в бандле. Без пустых экранов и фабрикации.
    static func fallbackPhrases() -> [TonguePhrase] {
        func answer(_ id: String, _ word: String, _ asset: String, _ correct: Bool) -> RhymeAnswer {
            RhymeAnswer(id: id, word: word, imageAsset: asset, isCorrect: correct)
        }
        func wagons(_ items: [(String, Bool)]) -> [WagonStep] {
            items.enumerated().map { WagonStep(id: $0.offset, text: $0.element.0, isSyllable: $0.element.1) }
        }
        return [
            TonguePhrase(
                id: "fb-s-osa", targetSound: "С", group: "свистящие", minAge: 5,
                warmupSyllable: "Са", warmupBeats: 3,
                linePrefix: "Са-са-са —", lineSuffix: "вот летит",
                answerWord: "оса", answerAsset: "word_wasp",
                answers: [
                    answer("fb-s-correct", "оса", "word_wasp", true),
                    answer("fb-s-d0", "лиса", "word_fox", false),
                    answer("fb-s-d1", "коса", "word_kosa", false)
                ],
                wagons: wagons([("Са", true), ("Са-са-са", true),
                                ("вот летит оса", false), ("Са-са-са — вот летит оса", false)])
            ),
            TonguePhrase(
                id: "fb-l-pila", targetSound: "Л", group: "соноры", minAge: 5,
                warmupSyllable: "Ла", warmupBeats: 3,
                linePrefix: "Ла-ла-ла —", lineSuffix: "острая",
                answerWord: "пила", answerAsset: "word_pila",
                answers: [
                    answer("fb-l-correct", "пила", "word_pila", true),
                    answer("fb-l-d0", "юла", "word_yula", false),
                    answer("fb-l-d1", "метла", "word_metla", false)
                ],
                wagons: wagons([("Ла", true), ("Ла-ла-ла", true),
                                ("острая пила", false), ("Ла-ла-ла — острая пила", false)])
            )
        ]
    }
}

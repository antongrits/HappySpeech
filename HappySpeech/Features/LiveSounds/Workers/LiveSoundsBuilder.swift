import Foundation
import OSLog

// MARK: - LiveSoundsBuilder
//
// Worker «Живых звуков». Задачи:
//   1. Загрузка контент-пака `pack_live_sounds.json` → `[LiveSoundsRound]`.
//   2. Сборка сессии: подбор слов по возрасту, чередование режимов
//      (collect / bench — никогда два одинаковых подряд, антифатиговое правило)
//      и сборка «скамейки» человечков для bench-раунда.
//
// Классификация звука (vowel/consonant) берётся из пака; если у звука нет явного
// `type` — выводится правилом `classify` (резерв/валидатор, проверяется в тестах).

@MainActor
final class LiveSoundsBuilder {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "LiveSoundsBuilder")

    // MARK: - Public: pack loading

    /// Загружает раунды из `pack_live_sounds.json`. Если пак не найден или
    /// повреждён — встроенный fallback (тоже реальные слова с проверенными
    /// ассетами), чтобы игра никогда не оставалась пустой.
    func loadRounds() -> [LiveSoundsRound] {
        guard let raw = Self.loadPack() else {
            logger.warning("pack_live_sounds.json missing — using built-in fallback set")
            return Self.fallbackRounds()
        }
        let rounds = raw.words.compactMap { Self.makeRound(from: $0) }
        guard !rounds.isEmpty else {
            logger.warning("pack_live_sounds.json produced 0 rounds — using fallback")
            return Self.fallbackRounds()
        }
        logger.info("loaded \(rounds.count, privacy: .public) live-sounds rounds")
        return rounds
    }

    /// Подбирает до `count` раундов сессии. Младшим (6–7) — короткие слова
    /// (3 звука); старшим (7–8) — до 5 звуков. Чередует режимы collect/bench и
    /// число звуков (не два одинаковых подряд — антифатиговое правило).
    func buildSession(from rounds: [LiveSoundsRound], age: Int, count: Int) -> [LiveSoundsRound] {
        guard !rounds.isEmpty else { return [] }
        let maxSounds = age >= 7 ? 5 : 3
        let eligible = rounds.filter { $0.soundCount <= maxSounds }
        let pool = eligible.isEmpty ? rounds : eligible

        var ordered: [LiveSoundsRound] = []
        var remaining = pool
        var lastCount = -1
        var nextMode: LiveSoundsMode = .collect

        while ordered.count < count, !remaining.isEmpty {
            // Предпочитаем слово с другим числом звуков, чем предыдущее.
            let idx = remaining.firstIndex(where: { $0.soundCount != lastCount }) ?? 0
            var picked = remaining.remove(at: idx)
            // Чередуем режим: collect → bench → collect …
            picked.mode = nextMode
            ordered.append(picked)
            lastCount = picked.soundCount
            nextMode = nextMode == .collect ? .bench : .collect
        }
        return Array(ordered.prefix(count))
    }

    // MARK: - Pure: классификация (резерв)

    private static let vowelLetters: Set<Character> = ["А", "О", "У", "Ы", "Э", "Я", "Ё", "Ю", "Е", "И"]

    /// Гласный, если буква-звук входит в множество гласных, иначе согласный.
    static func classify(_ letter: String) -> LiveSoundType {
        guard let ch = letter.uppercased().first else { return .consonant }
        return vowelLetters.contains(ch) ? .vowel : .consonant
    }

    // MARK: - Pure: mapping pack → domain

    private static func makeRound(from rw: RawWord) -> LiveSoundsRound? {
        guard !rw.sounds.isEmpty, !rw.text.isEmpty, !rw.asset.isEmpty else { return nil }
        let sounds: [LiveSoundUnit] = rw.sounds.enumerated().map { idx, s in
            let type = LiveSoundType(rawValue: s.type) ?? classify(s.letter)
            return LiveSoundUnit(letter: s.letter.uppercased(), type: type, position: idx)
        }

        // 4-картиночная сетка: правильное слово + до 3 дистракторов.
        var options: [PictureOption] = [
            PictureOption(id: 0, word: rw.text, imageAsset: rw.asset, isCorrect: true)
        ]
        let distractorAssets = rw.distractors ?? []
        let distractorWords = rw.distractorWords ?? []
        for (i, asset) in distractorAssets.prefix(3).enumerated() {
            let word = i < distractorWords.count ? distractorWords[i] : ""
            options.append(PictureOption(
                id: options.count,
                word: word,
                imageAsset: asset,
                isCorrect: false
            ))
        }
        // Детерминированное перемешивание позиции правильного ответа по id слова
        // (стабильно между прогонами — без random в проде).
        options = stableShuffle(options, seed: rw.id)
        // Перенумеровываем id под позицию в сетке.
        options = options.enumerated().map { idx, opt in
            PictureOption(id: idx, word: opt.word, imageAsset: opt.imageAsset, isCorrect: opt.isCorrect)
        }

        // «Скамейка» человечков: все звуки слова + 1 отвлекающий, перемешанные.
        let bench = makeBench(for: sounds, distractorAssets: distractorAssets, seed: rw.id)

        return LiveSoundsRound(
            id: rw.id,
            word: rw.text,
            imageAsset: rw.asset,
            sounds: sounds,
            options: options,
            benchLetters: bench,
            mode: .collect
        )
    }

    /// Собирает «скамейку» человечков для bench-раунда: верные звуки слова +
    /// один отвлекающий звук (из буквы дистрактора, которого нет в слове),
    /// детерминированно перемешанные.
    private static func makeBench(
        for sounds: [LiveSoundUnit],
        distractorAssets: [String],
        seed: String
    ) -> [LiveSoundUnit] {
        var bench = sounds
        let used = Set(sounds.map { $0.letter })
        // Отвлекающий звук — первая буква первого дистрактор-ассета (word_xxx),
        // если её удаётся транслитерировать в звук, которого нет в слове.
        if let extra = distractorSound(from: distractorAssets, excluding: used, basePosition: sounds.count) {
            bench.append(extra)
        }
        return stableShuffle(bench, seed: seed + "·bench")
    }

    /// Пытается извлечь отвлекающий звук из ассета дистрактора. Берёт первую
    /// букву РУССКОГО слова-дистрактора недоступна здесь (ассет латиницей),
    /// поэтому используем безопасный набор согласных, которых нет в слове.
    private static func distractorSound(
        from distractorAssets: [String],
        excluding used: Set<String>,
        basePosition: Int
    ) -> LiveSoundUnit? {
        let candidates = ["П", "Т", "К", "М", "Н", "Л", "Р", "С", "Б", "Д"]
        guard let letter = candidates.first(where: { !used.contains($0) }) else { return nil }
        return LiveSoundUnit(letter: letter, type: .consonant, position: basePosition)
    }

    /// Детерминированное перемешивание массива по строковому seed (FNV-1a hash).
    /// Без random — стабильно между прогонами (тестируемо, не «выдуманные» данные).
    static func stableShuffle<T>(_ array: [T], seed: String) -> [T] {
        guard array.count > 1 else { return array }
        var items = array
        var state = fnv1a(seed)
        // Fisher–Yates с детерминированным LCG.
        var i = items.count - 1
        while i > 0 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let j = Int(state >> 33) % (i + 1)
            items.swapAt(i, j)
            i -= 1
        }
        return items
    }

    private static func fnv1a(_ s: String) -> UInt64 {
        var hash: UInt64 = 14695981039346656037
        for byte in s.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return hash
    }

    // MARK: - Pack DTOs

    private struct RawPack: Decodable {
        let words: [RawWord]
    }
    private struct RawWord: Decodable {
        let id: String
        let text: String
        let asset: String
        let sounds: [RawSound]
        let distractors: [String]?
        let distractorWords: [String]?
    }
    private struct RawSound: Decodable {
        let letter: String
        let type: String
    }

    // MARK: - Pack IO

    private static func loadPack() -> RawPack? {
        guard let url = Bundle.main.url(forResource: "pack_live_sounds", withExtension: "json")
            ?? Bundle.main.url(
                forResource: "pack_live_sounds",
                withExtension: "json",
                subdirectory: "Seed"
            ),
            let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(RawPack.self, from: data)
    }

    // MARK: - Fallback

    /// Минимальный встроенный набор реальных слов с проверенными ассетами —
    /// на случай отсутствия пака. Никаких пустых экранов.
    static func fallbackRounds() -> [LiveSoundsRound] {
        func unit(_ letter: String, _ t: LiveSoundType, _ p: Int) -> LiveSoundUnit {
            LiveSoundUnit(letter: letter, type: t, position: p)
        }
        func round(
            _ id: String, _ word: String, _ asset: String,
            _ sounds: [LiveSoundUnit],
            _ distractors: [(String, String)]
        ) -> LiveSoundsRound {
            var opts: [PictureOption] = [PictureOption(id: 0, word: word, imageAsset: asset, isCorrect: true)]
            for (w, a) in distractors {
                opts.append(PictureOption(id: opts.count, word: w, imageAsset: a, isCorrect: false))
            }
            opts = stableShuffle(opts, seed: id).enumerated().map { idx, option in
                PictureOption(id: idx, word: option.word, imageAsset: option.imageAsset, isCorrect: option.isCorrect)
            }
            let bench = makeBench(for: sounds, distractorAssets: distractors.map { $0.1 }, seed: id)
            return LiveSoundsRound(
                id: id, word: word, imageAsset: asset,
                sounds: sounds, options: opts, benchLetters: bench, mode: .collect
            )
        }
        return [
            round("fb-kot", "кот", "word_kot",
                  [unit("К", .consonant, 0), unit("О", .vowel, 1), unit("Т", .consonant, 2)],
                  [("пёс", "word_dog"), ("рот", "word_rot"), ("кит", "word_kit")]),
            round("fb-dom", "дом", "word_dom",
                  [unit("Д", .consonant, 0), unit("О", .vowel, 1), unit("М", .consonant, 2)],
                  [("сом", "word_som"), ("кот", "word_kot"), ("нос", "word_nos")]),
            round("fb-mak", "мак", "word_mak",
                  [unit("М", .consonant, 0), unit("А", .vowel, 1), unit("К", .consonant, 2)],
                  [("рак", "word_rak"), ("лак", "word_lak"), ("кот", "word_kot")])
        ]
    }
}

import Foundation
import OSLog

// MARK: - SyllableSnailWorkerProtocol

@MainActor
protocol SyllableSnailWorkerProtocol: AnyObject {
    /// Собирает сессию «улитки» по режиму. Режим и уровень — предпочтительные
    /// (из истории) либо подобранные ротацией / по возрасту.
    func buildSession(
        childId: String,
        mode: SnailMode?,
        preferredTier: SyllableTier?
    ) async -> SyllableSnailModels.Start.Response

    /// Перемешанные плитки слова с уникальными id (для build).
    func makeTiles(from word: SnailWord) -> [SyllableTile]

    /// Преднабор перестановки для режима C: использует `scrambledHints` из
    /// корпуса (типовая НСС-ошибка), иначе детерминированная перестановка.
    func makeScrambledTiles(from word: SnailWord) -> [SyllableTile]

    /// По-слоговое проговаривание слова голосом Ляли (режим A — с паузами).
    func voiceSyllables(_ word: SnailWord, slowed: Bool) async
}

// MARK: - SyllableSnailWorker (Clean Swift: Worker)
//
// F2-003 «Слоговая улитка» (Wave 2).
//
// Формирует сессию по режиму (clap/build/fix) и уровню:
//   • уровень — предпочтительный либо по возрасту (возрастной гейт);
//   • ретро-старт: первые 2 раунда — на лёгком уровне (tier 1), F1-015;
//   • антифатиговое чередование: соседние раунды не повторяют слово;
//   • для fix — преднабор перестановки из корпуса (типовая ошибка НСС).
// Offline / on-device — корпус локальный. RNG инжектируется (детерминизм тестов).

@MainActor
final class SyllableSnailWorker: SyllableSnailWorkerProtocol {

    private let childRepository: any ChildRepository
    private let randomSource: () -> Double

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SyllableSnail.Worker"
    )

    init(
        childRepository: any ChildRepository,
        randomSource: @escaping () -> Double = { Double.random(in: 0..<1) }
    ) {
        self.childRepository = childRepository
        self.randomSource = randomSource
    }

    // MARK: - Session building

    func buildSession(
        childId: String,
        mode: SnailMode?,
        preferredTier: SyllableTier?
    ) async -> SyllableSnailModels.Start.Response {
        var age = 6
        do {
            let child = try await childRepository.fetch(id: childId)
            age = child.age
        } catch {
            Self.logger.error(
                "Failed to read child, using defaults: \(error.localizedDescription, privacy: .public)"
            )
        }

        let resolvedMode = mode ?? .clap
        let tier = Self.resolveTier(preferredTier: preferredTier, age: age)
        let rounds = makeRounds(mode: resolvedMode, tier: tier)

        Self.logger.debug(
            "Built syllable-snail session: mode=\(resolvedMode.rawValue, privacy: .public), tier=\(tier.rawValue), rounds=\(rounds.count)"
        )
        return .init(mode: resolvedMode, tier: tier, rounds: rounds)
    }

    // MARK: - Tier resolution (возрастной гейт)

    /// Подбирает уровень: предпочтительный, но не выше возрастного гейта.
    static func resolveTier(preferredTier: SyllableTier?, age: Int) -> SyllableTier {
        let cap = ageAllowedTier(age: age)
        guard let preferred = preferredTier else { return cap }
        return SyllableTier(rawValue: min(preferred.rawValue, cap.rawValue)) ?? cap
    }

    /// Максимально допустимый уровень для возраста.
    /// Классы 1–2 (tier 1) — с 5; 3–8 (tier 2–3) — 6–7; стечения (tier 4) — 7–8.
    static func ageAllowedTier(age: Int) -> SyllableTier {
        switch age {
        case ...5: return .oneSyllableOpen
        case 6:    return .threeSyllablesWithClosed
        default:   return .consonantCluster
        }
    }

    // MARK: - Round building

    /// Раунды: ретро-старт (2 лёгких tier-1 раунда) + основной уровень.
    /// Антифатиговое правило: соседние раунды не повторяют слово.
    func makeRounds(mode: SnailMode, tier: SyllableTier) -> [SnailRound] {
        let total = SyllableSnailCorpus.roundsPerSession
        var rounds: [SnailRound] = []

        // Ретро-старт: первые 2 раунда на лёгком уровне (tier 1), если основной
        // уровень сложнее (F1-015).
        if tier != .oneSyllableOpen {
            let retro = SyllableSnailCorpus.words(for: .oneSyllableOpen, mode: mode)
            appendRounds(from: shuffledWords(retro), mode: mode, count: 2, into: &rounds)
        }

        // Основная часть на целевом уровне.
        let main = SyllableSnailCorpus.words(for: tier, mode: mode)
        let remaining = max(0, total - rounds.count)
        appendRounds(from: shuffledWords(main), mode: mode, count: remaining, into: &rounds)

        // Гарантия непустой сессии (на отказ корпуса).
        if rounds.isEmpty {
            let fallback = SyllableSnailCorpus.words(for: tier, mode: mode)
            appendRounds(from: fallback, mode: mode, count: max(1, total), into: &rounds)
        }
        return rounds
    }

    /// Добавляет до `count` раундов, избегая двух одинаковых слов подряд.
    private func appendRounds(
        from pool: [SnailWord],
        mode: SnailMode,
        count: Int,
        into rounds: inout [SnailRound]
    ) {
        guard count > 0, !pool.isEmpty else { return }
        var available = pool
        var added = 0
        while added < count {
            if available.isEmpty {
                // Пул исчерпан — циклически перезаполняем (длинная сессия).
                available = pool
            }
            let lastId = rounds.last?.word.id
            let pickIndex = available.firstIndex { $0.id != lastId } ?? 0
            let word = available.remove(at: pickIndex)
            let tiles = tiles(for: word, mode: mode)
            rounds.append(
                SnailRound(
                    id: "\(mode.rawValue)-\(word.id)-\(rounds.count)",
                    word: word,
                    mode: mode,
                    tiles: tiles
                )
            )
            added += 1
        }
    }

    private func tiles(for word: SnailWord, mode: SnailMode) -> [SyllableTile] {
        switch mode {
        case .clap:  return []
        case .build: return makeTiles(from: word)
        case .fix:   return makeScrambledTiles(from: word)
        }
    }

    // MARK: - Tiles

    func makeTiles(from word: SnailWord) -> [SyllableTile] {
        let indexed = word.syllables.enumerated().map { offset, syllable in
            SyllableTile(id: "\(word.id)-\(offset)-\(syllable)", text: syllable)
        }
        return shuffledTiles(indexed)
    }

    func makeScrambledTiles(from word: SnailWord) -> [SyllableTile] {
        // Стабильные id привязаны к правильному порядку слогов (по индексу
        // первого совпадения текста) — чтобы сравнение собранного с эталоном
        // шло по тексту, а не по id.
        let canonical = word.syllables.enumerated().map { offset, syllable in
            SyllableTile(id: "\(word.id)-\(offset)-\(syllable)", text: syllable)
        }
        // Целевой «перепутанный» порядок: преднабор из корпуса (типовая
        // НСС-ошибка) либо детерминированная перестановка.
        let scrambledTexts: [String]
        if !word.scrambledHints.isEmpty,
           word.scrambledHints.sorted() == word.syllables.sorted(),
           word.scrambledHints != word.syllables {
            scrambledTexts = word.scrambledHints
        } else {
            scrambledTexts = nonIdentityScramble(word.syllables)
        }
        // Раскладываем canonical-плитки в порядке scrambledTexts (каждая
        // плитка переиспользуется один раз — корректно при повторяющихся слогах).
        return arrange(canonical, byTextOrder: scrambledTexts)
    }

    /// Перестраивает плитки так, чтобы их тексты шли в порядке `order`.
    private func arrange(_ tiles: [SyllableTile], byTextOrder order: [String]) -> [SyllableTile] {
        var remaining = tiles
        var result: [SyllableTile] = []
        for text in order {
            if let idx = remaining.firstIndex(where: { $0.text == text }) {
                result.append(remaining.remove(at: idx))
            }
        }
        // Если что-то не сматчилось (рассинхрон) — добиваем оставшимися.
        result.append(contentsOf: remaining)
        return result
    }

    /// Детерминированная перестановка, гарантированно отличная от исходной.
    private func nonIdentityScramble(_ syllables: [String]) -> [String] {
        guard syllables.count >= 2 else { return syllables }
        if syllables.count == 2 { return [syllables[1], syllables[0]] }
        // Циклический сдвиг — простая типовая перестановка.
        return Array(syllables[1...]) + [syllables[0]]
    }

    /// Fisher–Yates с инжектируемым RNG (детерминизм тестов).
    private func shuffledTiles(_ tiles: [SyllableTile]) -> [SyllableTile] {
        var array = tiles
        guard array.count > 1 else { return array }
        for index in stride(from: array.count - 1, through: 1, by: -1) {
            let randIndex = Int(randomSource() * Double(index + 1))
            let clamped = max(0, min(index, randIndex))
            array.swapAt(index, clamped)
        }
        // Ребёнок не должен получить «уже собранное» слово.
        if array.count >= 2, array.map(\.text) == tiles.map(\.text) {
            array.swapAt(0, 1)
        }
        return array
    }

    private func shuffledWords(_ words: [SnailWord]) -> [SnailWord] {
        var array = words
        guard array.count > 1 else { return array }
        for index in stride(from: array.count - 1, through: 1, by: -1) {
            let randIndex = Int(randomSource() * Double(index + 1))
            let clamped = max(0, min(index, randIndex))
            array.swapAt(index, clamped)
        }
        return array
    }

    // MARK: - Voice

    func voiceSyllables(_ word: SnailWord, slowed: Bool) async {
        // По-слоговое проговаривание с паузами — методически обязательно для
        // ритмико-слогового анализа (режим A). Темп замедляется в retry.
        await LessonVoiceWorker.shared.speak(
            word.syllables.joined(separator: " "),
            lessonType: "syllable-snail",
            rate: slowed ? 0.7 : 1.0
        )
    }
}

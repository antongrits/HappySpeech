import Foundation

// MARK: - SyllableConstructorWorkerProtocol

@MainActor
public protocol SyllableConstructorWorkerProtocol: AnyObject {

    /// Подбирает слово для уровня сложности с учётом уже сыгранных id.
    func nextWord(for tier: SyllableTier, exclude playedIds: Set<String>) -> SyllableWord?

    /// Доступные уровни сложности корпуса.
    func availableTiers() -> [SyllableTier]

    /// Размер корпуса для уровня.
    func count(for tier: SyllableTier) -> Int

    /// Возвращает перемешанные плитки для слова (с уникальными id).
    func makeTiles(from word: SyllableWord) -> [SyllableTile]

    /// Озвучивает слово голосом Ляли (или Siri TTS как fallback).
    func voiceWord(_ word: SyllableWord) async
}

// MARK: - SyllableConstructorWorker (Clean Swift: Worker)

@MainActor
final class SyllableConstructorWorker: SyllableConstructorWorkerProtocol {

    private let randomSource: () -> Double

    /// Базовый init использует системный RNG; тестируемый init принимает seed
    /// для детерминированных перестановок.
    init(randomSource: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.randomSource = randomSource
    }

    // MARK: - Corpus

    func nextWord(for tier: SyllableTier, exclude playedIds: Set<String>) -> SyllableWord? {
        let pool = SyllableConstructorCorpus.words(for: tier)
        let remaining = pool.filter { !playedIds.contains($0.id) }
        if let pick = remaining.randomElement() { return pick }
        // Если уровень исчерпан — возвращаем любое слово уровня (циклически).
        return pool.randomElement()
    }

    func availableTiers() -> [SyllableTier] {
        SyllableConstructorCorpus.availableTiers
    }

    func count(for tier: SyllableTier) -> Int {
        SyllableConstructorCorpus.words(for: tier).count
    }

    // MARK: - Tiles

    func makeTiles(from word: SyllableWord) -> [SyllableTile] {
        let indexed = word.syllables.enumerated().map { offset, syllable in
            SyllableTile(id: "\(word.id)-\(offset)-\(syllable)", text: syllable)
        }
        return shuffled(indexed)
    }

    /// Простая Fisher–Yates с инжектируемым источником случайности (для тестов).
    private func shuffled(_ tiles: [SyllableTile]) -> [SyllableTile] {
        var array = tiles
        guard array.count > 1 else { return array }
        for index in stride(from: array.count - 1, through: 1, by: -1) {
            let randIndex = Int(randomSource() * Double(index + 1))
            let clamped = max(0, min(index, randIndex))
            array.swapAt(index, clamped)
        }
        // Если после shuffle порядок совпал с исходным (например, тестовый
        // RNG отдаёт 0.999…), переставим первые две плитки, чтобы child
        // никогда не получал «уже собранное» слово.
        if array.count >= 2,
           array.map(\.text) == tiles.map(\.text) {
            array.swapAt(0, 1)
        }
        return array
    }

    // MARK: - Voice

    func voiceWord(_ word: SyllableWord) async {
        await LessonVoiceWorker.shared.speak(
            word.word,
            lessonType: "syllable-constructor",
            rate: 1.0,
            enableSystemTTSFallback: true
        )
    }
}

import Foundation
import OSLog

// MARK: - AudioMemoryGameInteractor

/// Бизнес-логика «Звукового мемори».
///
/// Колода собирается из реальных слов рабочих звуков ребёнка
/// (`KidWordContentProvider` через `ChildRepository`). Каждая собранная пара
/// фиксируется в интервальном планировщике повторов, по завершении —
/// итоговый SM-2 результат и рекорд звёзд (`KidGameScoreStore`). Без репозитория
/// (Preview/тесты) используется стартовый набор слов.
@MainActor
@Observable
final class AudioMemoryGameInteractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "AudioMemoryGame"
    )

    let childId: String
    var tiles: [AudioMemoryGameModels.Tile] = []
    var firstPickIndex: Int?
    var moves: Int = 0
    var matchedCount: Int = 0
    var pairCount: Int = AudioMemoryGameModels.pairCount
    var mismatches: Int = 0
    var bestStars: Int = 0
    var isResolving: Bool = false
    var isLoaded: Bool = false

    private let childRepository: (any ChildRepository)?
    private let adaptivePlanner: (any AdaptivePlannerService)?
    private let scoreStore: KidGameScoreStore

    init(
        childId: String,
        childRepository: (any ChildRepository)? = nil,
        adaptivePlanner: (any AdaptivePlannerService)? = nil
    ) {
        self.childId = childId
        self.childRepository = childRepository
        self.adaptivePlanner = adaptivePlanner
        self.scoreStore = KidGameScoreStore(gameKey: "audioMemory", childId: childId)
    }

    var isComplete: Bool {
        pairCount > 0 && matchedCount == pairCount
    }

    /// Собирает колоду под рабочие звуки ребёнка.
    func load() async {
        var targets: [String] = []
        if let childRepository, !childId.isEmpty {
            do {
                targets = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        let words = Self.words(forTargetSounds: targets)
        tiles = AudioMemoryGameModels.makeDeck(words: words)
        pairCount = tiles.count / 2
        bestStars = scoreStore.bestStars
        firstPickIndex = nil
        moves = 0
        matchedCount = 0
        mismatches = 0
        isResolving = false
        isLoaded = true
        Self.logger.info("loaded \(self.pairCount, privacy: .public) pairs")
    }

    /// Слова для колоды: рабочие группы звуков → достаточно слов; перемешиваем.
    static func words(forTargetSounds targets: [String]) -> [KidWordContentProvider.GameWord] {
        let groups = KidWordContentProvider.groups(forTargetSounds: targets)
        var pool: [KidWordContentProvider.GameWord] = []
        for group in groups {
            pool.append(contentsOf: KidWordContentProvider.words(in: group, limit: 20))
        }
        var seen = Set<String>()
        let unique = pool.filter { seen.insert($0.text.lowercased()).inserted }.shuffled()
        if unique.count >= AudioMemoryGameModels.pairCount { return unique }
        return unique + fallbackWords
    }

    /// Резервные слова на случай недоступности манифеста (Preview/тесты).
    static let fallbackWords: [KidWordContentProvider.GameWord] = [
        .init(id: "f-sova", text: "Сова", asset: "word_sova", soundFamily: "С"),
        .init(id: "f-slon", text: "Слон", asset: "word_slon", soundFamily: "С"),
        .init(id: "f-ryba", text: "Рыба", asset: "word_ryba", soundFamily: "Р"),
        .init(id: "f-rak", text: "Рак", asset: "word_rak", soundFamily: "Р"),
        .init(id: "f-zayac", text: "Заяц", asset: "word_zayats", soundFamily: "З"),
        .init(id: "f-koshka", text: "Кошка", asset: "word_koshka", soundFamily: "К")
    ]

    func tap(at index: Int) {
        guard isLoaded, !isResolving,
              index < tiles.count,
              !tiles[index].isFlipped,
              !tiles[index].isMatched else { return }

        tiles[index].isFlipped = true

        // Звуковое мемори: при открытии карточки реально проигрываем слово
        // голосом Ляли (`LessonVoiceWorker` — семейная запись → m4a). Игра «на
        // слух»: ребёнок ищет пару по услышанному слову, а не только по тексту.
        playCardAudio(tiles[index].pairKey)

        if let first = firstPickIndex {
            moves += 1
            if tiles[first].pairKey == tiles[index].pairKey {
                tiles[first].isMatched = true
                tiles[index].isMatched = true
                matchedCount += 1
                firstPickIndex = nil
                recordOutcome(tile: tiles[index], correct: true)
                Self.logger.info("Matched \(self.tiles[index].pairKey, privacy: .public)")
                if isComplete { finish() }
            } else {
                mismatches += 1
                recordOutcome(tile: tiles[index], correct: false)
                isResolving = true
                Task { [weak self] in
                    try? await Task.sleep(for: .milliseconds(700))
                    await MainActor.run {
                        guard let self else { return }
                        self.tiles[first].isFlipped = false
                        self.tiles[index].isFlipped = false
                        self.firstPickIndex = nil
                        self.isResolving = false
                    }
                }
            }
        } else {
            firstPickIndex = index
        }
    }

    func restart() {
        Task { [weak self] in await self?.load() }
    }

    /// Проигрывает слово карточки голосом Ляли (реальный аудио-эталон).
    private func playCardAudio(_ word: String) {
        guard !word.isEmpty else { return }
        Task { @MainActor in
            await LessonVoiceWorker.shared.speak(word, lessonType: "audio_memory")
        }
    }

    // MARK: - Persistence

    /// Точность по парам: верные совпадения от всех попыток сопоставления.
    var accuracy: Double {
        let attempts = matchedCount + mismatches
        return attempts > 0 ? Double(matchedCount) / Double(attempts) : 0
    }

    /// Звёзды 0–3 по эффективности (меньше промахов — больше звёзд).
    var stars: Int {
        guard isComplete else { return 0 }
        switch accuracy {
        case 0.66...: return 3
        case 0.45..<0.66: return 2
        default: return 1
        }
    }

    private func recordOutcome(tile: AudioMemoryGameModels.Tile, correct: Bool) {
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        Task { [weak self] in
            guard let self else { return }
            await planner.recordItemOutcome(
                childId: self.childId,
                itemId: "memory-\(tile.pairKey)",
                sound: tile.soundFamily,
                correct: correct
            )
        }
    }

    private func finish() {
        let starsEarned = stars
        if scoreStore.recordCompletion(stars: starsEarned) {
            bestStars = starsEarned
        }
        guard let planner = adaptivePlanner, !childId.isEmpty else { return }
        let quality = SM2Quality.fromSuccessRate(accuracy)
        let sound = tiles.first?.soundFamily ?? "С"
        Task { [weak self] in
            guard let self else { return }
            do {
                try await planner.recordSessionResult(
                    childId: self.childId,
                    soundTarget: sound,
                    qualityScore: quality
                )
            } catch {
                Self.logger.error("recordSession failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

import Foundation
import OSLog

// MARK: - ListenAndChooseBusinessLogic

@MainActor
protocol ListenAndChooseBusinessLogic: AnyObject {
    func loadRound(_ request: ListenAndChooseModels.LoadRound.Request) async
    func submitAttempt(_ request: ListenAndChooseModels.SubmitAttempt.Request)
}

// MARK: - ListenAndChooseInteractor

/// Business logic for a single "Listen and choose" round. Holds attempts counter and
/// applies a progressive scoring curve: first-try = 1.0, second = 0.66, third = 0.33,
/// and reveals the answer after the third wrong attempt.
@MainActor
final class ListenAndChooseInteractor: ListenAndChooseBusinessLogic {

    var presenter: (any ListenAndChoosePresentationLogic)?

    private let contentService: any ContentService
    private let logger = Logger(subsystem: "ru.happyspeech", category: "ListenAndChoose")
    private let maxAttempts: Int = 3

    init(contentService: any ContentService) {
        self.contentService = contentService
    }

    // MARK: ListenAndChooseBusinessLogic

    func loadRound(_ request: ListenAndChooseModels.LoadRound.Request) async {
        let candidates = await fetchCandidates(for: request.soundTarget)
        let (target, options, correctIndex) = Self.buildRound(
            from: candidates,
            difficulty: request.difficulty
        )

        let response = ListenAndChooseModels.LoadRound.Response(
            targetWord: target.word,
            options: options,
            correctIndex: correctIndex,
            audioAsset: target.audioAsset
        )
        presenter?.presentLoadRound(response)
    }

    func submitAttempt(_ request: ListenAndChooseModels.SubmitAttempt.Request) {
        let isCorrect = request.selectedIndex == request.correctIndex
        let attempts = max(request.attemptsUsed, 1)
        let shouldReveal = !isCorrect && attempts >= maxAttempts

        // Progressive scoring curve
        let score: Float
        if isCorrect {
            switch attempts {
            case 1:  score = 1.0
            case 2:  score = 0.66
            default: score = 0.33
            }
        } else if shouldReveal {
            score = 0.0
        } else {
            score = 0.0 // interim — not the final score yet
        }

        let response = ListenAndChooseModels.SubmitAttempt.Response(
            isCorrect: isCorrect,
            isFinalAttempt: shouldReveal || isCorrect,
            score: score,
            shouldRevealAnswer: shouldReveal,
            correctIndex: request.correctIndex
        )
        logger.debug("Attempt idx=\(request.selectedIndex) correct=\(isCorrect) attempts=\(attempts) score=\(score)")
        presenter?.presentSubmitAttempt(response)
    }

    // MARK: Private

    private func fetchCandidates(for sound: String) async -> [ContentItem] {
        // ContentService exposes `loadPack(id:)`. We try a canonical id and
        // fall back to local mock data if the pack is unavailable.
        let packId = Self.canonicalPackId(for: sound)
        do {
            let pack = try await contentService.loadPack(id: packId)
            if !pack.items.isEmpty { return pack.items }
        } catch {
            logger.notice("Pack \(packId) unavailable, falling back to defaults: \(error.localizedDescription)")
        }
        return Self.defaultItems(for: sound)
    }

    private static func canonicalPackId(for sound: String) -> String {
        let latin: String
        switch sound.lowercased() {
        case "с", "s":  latin = "s"
        case "ш", "sh": latin = "sh"
        case "р", "r":  latin = "r"
        case "л", "l":  latin = "l"
        case "к", "k":  latin = "k"
        default:        latin = "s"
        }
        return "sound_\(latin)_v1"
    }

    private static func defaultItems(for sound: String) -> [ContentItem] {
        let words: [String]
        switch sound.lowercased() {
        case "с", "s":  words = ["сок", "сумка", "сад", "сова", "санки"]
        case "ш", "sh": words = ["шар", "шуба", "шапка", "школа", "шкаф"]
        case "р", "r":  words = ["рак", "роза", "рыба", "радуга", "ракета"]
        case "л", "l":  words = ["лак", "лодка", "ложка", "луна", "лампа"]
        case "к", "k":  words = ["кот", "кубик", "книга", "куст", "кольцо"]
        default:        words = ["мама", "папа", "дом", "мир", "свет"]
        }
        return words.enumerated().map { idx, w in
            ContentItem(
                id: "default-\(sound)-\(idx)",
                word: w,
                imageAsset: nil,
                audioAsset: nil,
                hint: nil,
                stage: .wordInit,
                difficulty: 1
            )
        }
    }

    private static func buildRound(
        from items: [ContentItem],
        difficulty: Int
    ) -> (ContentItem, [ListenAndChooseModels.LoadRound.OptionItem], Int) {
        let pool = items.isEmpty ? Self.defaultItems(for: "") : items
        let optionCount = max(2, min(4, 2 + difficulty))
        var shuffled = pool.shuffled()
        if shuffled.count < optionCount {
            // Repeat items deterministically if the pack is small
            while shuffled.count < optionCount, let first = pool.first {
                shuffled.append(first)
            }
        }
        let picks = Array(shuffled.prefix(optionCount))
        let correctIndex = Int.random(in: 0..<picks.count)
        let target = picks[correctIndex]
        let options = picks.map {
            ListenAndChooseModels.LoadRound.OptionItem(
                id: $0.id, word: $0.word, imageAsset: $0.imageAsset
            )
        }
        return (target, options, correctIndex)
    }
}

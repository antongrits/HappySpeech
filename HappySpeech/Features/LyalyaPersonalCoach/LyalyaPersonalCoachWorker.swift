import Foundation
import OSLog

// MARK: - LyalyaPersonalCoachWorkerProtocol

@MainActor
protocol LyalyaPersonalCoachWorkerProtocol: AnyObject {
    /// Собирает персонализированные раунды коуча под рабочие звуки ребёнка.
    func buildRounds(childId: String) async -> [LyalyaPersonalCoachModels.Round]
}

// MARK: - LyalyaPersonalCoachWorker (Clean Swift: Worker)
//
// Персонализирует мини-викторину Ляли под рабочие звуки ребёнка: вопросы
// «какой первый звук в слове X» строятся из реальных слов рабочих групп звуков
// (LessonContentMap), варианты — буквы из этих слов. Offline / on-device.

@MainActor
final class LyalyaPersonalCoachWorker: LyalyaPersonalCoachWorkerProtocol {

    static let roundsPerSession = 5

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LyalyaPersonalCoach.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildRounds(childId: String) async -> [LyalyaPersonalCoachModels.Round] {
        var targetSounds: [String] = []
        if !childId.isEmpty {
            do {
                targetSounds = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        let groups = KidWordContentProvider.groups(forTargetSounds: targetSounds)
        var pool: [KidWordContentProvider.GameWord] = []
        for group in groups {
            pool.append(contentsOf: KidWordContentProvider.words(in: group))
        }
        pool.shuffle()

        var rounds: [LyalyaPersonalCoachModels.Round] = []
        var usedWords = Set<String>()
        for word in pool {
            guard rounds.count < Self.roundsPerSession else { break }
            guard usedWords.insert(word.text.lowercased()).inserted else { continue }
            if let round = Self.makeFirstSoundRound(word: word.text, id: rounds.count + 1) {
                rounds.append(round)
            }
        }
        Self.logger.debug("built \(rounds.count) personalized rounds")
        return rounds
    }

    /// Раунд «какой первый звук в слове X»: правильный вариант — первая буква,
    /// дистракторы — другие буквы того же слова.
    static func makeFirstSoundRound(word: String, id: Int) -> LyalyaPersonalCoachModels.Round? {
        let letters = Array(word.uppercased()).filter { $0.isLetter }.map(String.init)
        guard let first = letters.first, letters.count >= 3 else { return nil }

        var distractors: [String] = []
        var seen = Set<String>([first])
        for letter in letters.dropFirst() where seen.insert(letter).inserted {
            distractors.append(letter)
            if distractors.count >= 3 { break }
        }
        guard distractors.count >= 2 else { return nil }

        var options = [first] + distractors.prefix(3)
        options.shuffle()
        guard let correctIndex = options.firstIndex(of: first) else { return nil }

        return LyalyaPersonalCoachModels.Round(
            id: id,
            question: String(format: String(localized: "lyalyaCoach.q.firstSound %@"), word),
            options: options,
            correctIndex: correctIndex
        )
    }
}

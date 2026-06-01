import Foundation
import OSLog

// MARK: - SpeechRiddlesWorkerProtocol

@MainActor
protocol SpeechRiddlesWorkerProtocol: AnyObject {
    /// Собирает загадки «что начинается на букву X» из реального словаря,
    /// сфокусированные на рабочих звуках ребёнка.
    func buildRiddles(childId: String) async -> [SpeechRiddlesModels.Riddle]
}

// MARK: - SpeechRiddlesWorker (Clean Swift: Worker)
//
// Формирует загадки на начальный звук из bundled-манифеста (`LessonContentMap`):
//   • целевые буквы — рабочие звуки ребёнка (+ добор из остальных групп);
//   • правильный вариант — реальное слово на целевую букву;
//   • дистракторы — реальные слова на другие буквы.
// Offline / on-device.

@MainActor
final class SpeechRiddlesWorker: SpeechRiddlesWorkerProtocol {

    static let riddlesPerSession = 5
    static let optionsPerRiddle = 4

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechRiddles.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildRiddles(childId: String) async -> [SpeechRiddlesModels.Riddle] {
        var targetSounds: [String] = []
        if !childId.isEmpty {
            do {
                targetSounds = try await childRepository.fetch(id: childId).targetSounds
            } catch {
                Self.logger.error("child fetch failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        // Кандидаты-буквы: рабочие звуки ребёнка + базовые группы для добора.
        var letters = targetSounds.filter { $0.count == 1 }
        if letters.count < Self.riddlesPerSession {
            letters.append(contentsOf: ["С", "Ш", "Р", "Л", "К", "З", "Ж", "Г"])
        }
        // Уникализируем, сохраняя порядок.
        var seenLetter = Set<String>()
        letters = letters.filter { seenLetter.insert($0).inserted }

        var riddles: [SpeechRiddlesModels.Riddle] = []
        for letter in letters {
            guard riddles.count < Self.riddlesPerSession else { break }
            if let riddle = Self.makeRiddle(targetLetter: letter, index: riddles.count) {
                riddles.append(riddle)
            }
        }
        Self.logger.debug("built \(riddles.count) riddles")
        return riddles
    }

    // MARK: - Pure riddle building

    static func makeRiddle(targetLetter: String, index: Int) -> SpeechRiddlesModels.Riddle? {
        let correctPool = KidWordContentProvider
            .words(soundFamily: targetLetter)
            .filter { $0.text.uppercased().hasPrefix(targetLetter.uppercased()) }
            .shuffled()
        guard let correct = correctPool.first else { return nil }

        // Дистракторы — слова с другой начальной буквой.
        let distractorPool = KidWordContentProvider.allFamilies
            .filter { $0 != targetLetter }
            .flatMap { KidWordContentProvider.words(soundFamily: $0) }
            .filter { !$0.text.uppercased().hasPrefix(targetLetter.uppercased()) }
            .shuffled()

        // Уникализируем дистракторы по первой букве, чтобы варианты не путали.
        var usedFirst = Set<String>([targetLetter.uppercased()])
        var distractors: [KidWordContentProvider.GameWord] = []
        for word in distractorPool {
            let first = String(word.text.prefix(1)).uppercased()
            guard usedFirst.insert(first).inserted else { continue }
            distractors.append(word)
            if distractors.count >= optionsPerRiddle - 1 { break }
        }
        guard distractors.count == optionsPerRiddle - 1 else { return nil }

        var options: [SpeechRiddlesModels.Option] = [
            SpeechRiddlesModels.Option(
                id: "opt-correct",
                asset: correct.asset,
                label: correct.text,
                startsWith: String(correct.text.prefix(1)).uppercased()
            )
        ]
        options += distractors.enumerated().map { idx, word in
            SpeechRiddlesModels.Option(
                id: "opt-d\(idx)",
                asset: word.asset,
                label: word.text,
                startsWith: String(word.text.prefix(1)).uppercased()
            )
        }
        options.shuffle()

        return SpeechRiddlesModels.Riddle(
            id: "riddle-\(targetLetter)-\(index)",
            prompt: String(
                format: String(localized: "speechRiddles.prompt %@"),
                targetLetter
            ),
            targetLetter: targetLetter,
            options: options,
            correctOptionId: "opt-correct"
        )
    }
}

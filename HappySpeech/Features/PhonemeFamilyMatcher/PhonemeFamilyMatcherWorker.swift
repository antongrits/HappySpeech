import Foundation
import OSLog

// MARK: - PhonemeFamilyMatcherWorkerProtocol

@MainActor
protocol PhonemeFamilyMatcherWorkerProtocol: AnyObject {
    /// Подбирает слова для сортировки по группам звуков из реального словаря.
    func buildWords(childId: String) async -> [PhonemeFamilyMatcherModels.Word]
}

// MARK: - PhonemeFamilyMatcherWorker (Clean Swift: Worker)
//
// Формирует набор слов для игры «разложи по семьям звуков» из bundled-манифеста
// (`LessonContentMap`): по 3 реальных слова на каждую из 4 групп звуков.
// Offline / on-device.

@MainActor
final class PhonemeFamilyMatcherWorker: PhonemeFamilyMatcherWorkerProtocol {

    static let wordsPerFamily = 3

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemeFamilyMatcher.Worker"
    )

    init() {}

    func buildWords(childId: String) async -> [PhonemeFamilyMatcherModels.Word] {
        var result: [PhonemeFamilyMatcherModels.Word] = []
        for family in PhonemeFamilyMatcherModels.Family.allCases {
            let group = Self.group(for: family)
            let words = KidWordContentProvider
                .words(in: group)
                .shuffled()
                .prefix(Self.wordsPerFamily)
            for word in words {
                result.append(
                    PhonemeFamilyMatcherModels.Word(
                        id: word.id,
                        text: word.text,
                        family: family,
                        assignedFamily: nil
                    )
                )
            }
        }
        result.shuffle()
        Self.logger.debug("built \(result.count) words")
        return result
    }

    static func group(for family: PhonemeFamilyMatcherModels.Family) -> KidWordContentProvider.SoundGroup {
        switch family {
        case .whistling: return .whistling
        case .hissing:   return .hissing
        case .sonorant:  return .sonorant
        case .velar:     return .velar
        }
    }
}

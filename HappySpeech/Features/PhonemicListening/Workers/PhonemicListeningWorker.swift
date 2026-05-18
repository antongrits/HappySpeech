import Foundation
import OSLog

// MARK: - PhonemicListeningWorkerProtocol

@MainActor
protocol PhonemicListeningWorkerProtocol: AnyObject {
    /// Собирает сессию упражнений фонематического анализа для ребёнка.
    func buildSession(childId: String) async -> PhonemicListeningModels.Start.Response
}

// MARK: - PhonemicListeningWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 12 «Слушай внимательно».
//
// Формирует сбалансированную сессию из трёх операций анализа (позиция,
// количество, синтез), отдавая приоритет целевым звукам ребёнка.
// Offline / on-device — корпус локальный.

@MainActor
final class PhonemicListeningWorker: PhonemicListeningWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "PhonemicListening.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(childId: String) async -> PhonemicListeningModels.Start.Response {
        let targetSounds: [String]
        do {
            let child = try await childRepository.fetch(id: childId)
            targetSounds = child.targetSounds
        } catch {
            Self.logger.error(
                "Failed to read child sounds, using full corpus: \(error.localizedDescription, privacy: .public)"
            )
            targetSounds = []
        }

        let rounds = Self.makeRounds(targetSounds: targetSounds)
        Self.logger.debug("Built phonemic-listening session: \(rounds.count) rounds")
        return .init(rounds: rounds)
    }

    /// Раунды идут от простого к сложному: позиция → количество → синтез
    /// (методическая прогрессия фонематического анализа).
    private static func makeRounds(targetSounds: [String]) -> [PhonemicRound] {
        let perOperation = PhonemicListeningCorpus.roundsPerSession / 3
        var rounds: [PhonemicRound] = []

        for operation in [PhonemeOperation.position, .count, .synthesis] {
            let words = PhonemicListeningCorpus
                .words(for: operation, targetSounds: targetSounds)
                .shuffled()
                .prefix(perOperation)
            for word in words {
                rounds.append(
                    PhonemicRound(
                        id: "\(operation.rawValue)-\(word.id)",
                        operation: operation,
                        word: word
                    )
                )
            }
        }
        return rounds
    }
}

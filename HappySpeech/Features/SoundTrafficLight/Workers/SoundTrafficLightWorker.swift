import Foundation
import OSLog

// MARK: - SoundTrafficLightWorkerProtocol

@MainActor
protocol SoundTrafficLightWorkerProtocol: AnyObject {
    /// Подбирает пару дифференциации и собирает раунды сессии для ребёнка.
    func buildSession(childId: String) async -> SoundTrafficLightModels.Start.Response
}

// MARK: - SoundTrafficLightWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Подбирает релевантную пару дифференциации по целевым звукам ребёнка
// и формирует перемешанный набор раундов из корпуса. Offline / on-device.

@MainActor
final class SoundTrafficLightWorker: SoundTrafficLightWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(childId: String) async -> SoundTrafficLightModels.Start.Response {
        let targetSounds: [String]
        do {
            let child = try await childRepository.fetch(id: childId)
            targetSounds = child.targetSounds
        } catch {
            Self.logger.error(
                "Failed to read child sounds, using default pair: \(error.localizedDescription, privacy: .public)"
            )
            targetSounds = []
        }

        let pair = SoundTrafficLightCorpus.recommendedPair(for: targetSounds)
        let rounds = Self.makeRounds(from: pair)
        Self.logger.debug(
            "Built traffic-light session: pair \(pair.id, privacy: .public), \(rounds.count) rounds"
        )
        return .init(pair: pair, rounds: rounds)
    }

    /// Формирует сбалансированный перемешанный набор раундов.
    private static func makeRounds(from pair: DifferentiationPair) -> [TrafficLightRound] {
        let half = SoundTrafficLightCorpus.roundsPerSession / 2

        let fromA = pair.wordsA.shuffled().prefix(half).map { word in
            TrafficLightRound(id: "a-\(word)", word: word, belongsToA: true)
        }
        let fromB = pair.wordsB.shuffled().prefix(half).map { word in
            TrafficLightRound(id: "b-\(word)", word: word, belongsToA: false)
        }
        return (fromA + fromB).shuffled()
    }
}

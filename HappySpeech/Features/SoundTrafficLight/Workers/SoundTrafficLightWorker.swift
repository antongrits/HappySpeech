import Foundation
import OSLog

// MARK: - SoundTrafficLightWorkerProtocol

@MainActor
protocol SoundTrafficLightWorkerProtocol: AnyObject {
    /// Подбирает пару дифференциации и собирает сессию текущего уровня лестницы
    /// (слог / слово / фраза / текст) для ребёнка.
    func buildSession(childId: String) async -> SoundTrafficLightModels.Start.Response
}

// MARK: - SoundTrafficLightWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 5 «Звуковой светофор».
//
// Подбирает релевантную пару дифференциации по целевым звукам ребёнка,
// определяет текущий уровень лестницы из сохранённого прогресса и формирует
// материал сессии: сбалансированный набор слогов/слов, фразы или тексты.
// Offline / on-device.

@MainActor
final class SoundTrafficLightWorker: SoundTrafficLightWorkerProtocol {

    private let childRepository: any ChildRepository
    private let progressStore: any DifferentiationProgressStoring

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundTrafficLight.Worker"
    )

    init(
        childRepository: any ChildRepository,
        progressStore: any DifferentiationProgressStoring = UserDefaultsDifferentiationProgressStore()
    ) {
        self.childRepository = childRepository
        self.progressStore = progressStore
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
        let stored = progressStore.progress(childId: childId, pairId: pair.id)
        let level = SoundTrafficLightCriteria.resolveStartLevel(
            stored: stored.level,
            availableLevels: pair.availableLevels
        )

        Self.logger.debug(
            "Built traffic-light session: pair \(pair.id, privacy: .public), level \(level.rawValue, privacy: .public)"
        )
        return Self.makeSession(pair: pair, level: level)
    }

    /// Формирует материал сессии для конкретного уровня лестницы.
    static func makeSession(
        pair: DifferentiationPair,
        level: DifferentiationLevel
    ) -> SoundTrafficLightModels.Start.Response {
        switch level {
        case .syllable:
            return .init(
                pair: pair,
                level: .syllable,
                rounds: makeRounds(
                    fromA: pair.syllablesA,
                    fromB: pair.syllablesB,
                    perSession: SoundTrafficLightCorpus.syllablesPerSession
                )
            )
        case .word:
            return .init(
                pair: pair,
                level: .word,
                rounds: makeRounds(
                    fromA: pair.wordsA,
                    fromB: pair.wordsB,
                    perSession: SoundTrafficLightCorpus.roundsPerSession
                )
            )
        case .phrase:
            return .init(pair: pair, level: .phrase, phrases: pair.phrases.shuffled())
        case .text:
            return .init(pair: pair, level: .text, texts: pair.texts)
        }
    }

    /// Формирует сбалансированный перемешанный набор раундов (слоги или слова).
    private static func makeRounds(
        fromA itemsA: [String],
        fromB itemsB: [String],
        perSession: Int
    ) -> [TrafficLightRound] {
        let half = max(1, perSession / 2)

        let roundsA = itemsA.shuffled().prefix(half).map { item in
            TrafficLightRound(id: "a-\(item)", word: item, belongsToA: true)
        }
        let roundsB = itemsB.shuffled().prefix(half).map { item in
            TrafficLightRound(id: "b-\(item)", word: item, belongsToA: false)
        }
        return (roundsA + roundsB).shuffled()
    }
}

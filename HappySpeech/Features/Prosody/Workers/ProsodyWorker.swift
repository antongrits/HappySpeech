import Foundation
import OSLog

// MARK: - ProsodyWorkerProtocol

@MainActor
protocol ProsodyWorkerProtocol: AnyObject {
    /// Собирает сессию упражнений просодии для ребёнка.
    func buildSession(childId: String) async -> ProsodyModels.Start.Response
}

// MARK: - ProsodyWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 1 «Голосовые краски».
//
// Формирует сессию по методической прогрессии: различение интонации на слух →
// повтор по эталону → самостоятельное продуцирование. Offline / on-device.

@MainActor
final class ProsodyWorker: ProsodyWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "Prosody.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(childId: String) async -> ProsodyModels.Start.Response {
        // Возраст влияет на длину сессии: 6 лет — короче, 7–8 — стандартная.
        let age: Int
        do {
            let child = try await childRepository.fetch(id: childId)
            age = child.age
        } catch {
            Self.logger.error(
                "Failed to read child age, using default: \(error.localizedDescription, privacy: .public)"
            )
            age = 7
        }

        let rounds = Self.makeRounds(age: age)
        Self.logger.debug("Built prosody session: \(rounds.count) rounds")
        return .init(rounds: rounds)
    }

    /// Раунды идут по этапам: различение → повтор → продуцирование.
    private static func makeRounds(age: Int) -> [ProsodyRound] {
        let total = age <= 6
            ? ProsodyCorpus.roundsPerSession - 3
            : ProsodyCorpus.roundsPerSession
        let perStage = max(1, total / 3)
        let phrases = ProsodyCorpus.sessionPhrases()
        var rounds: [ProsodyRound] = []
        var phraseIndex = 0

        for stage in ProsodyStage.allCases {
            for _ in 0..<perStage where phraseIndex < phrases.count {
                let phrase = phrases[phraseIndex]
                phraseIndex += 1
                rounds.append(
                    ProsodyRound(
                        id: "\(stage.rawValue)-\(phrase.id)",
                        stage: stage,
                        phrase: phrase
                    )
                )
            }
        }
        return rounds
    }
}

import Foundation
import OSLog

// MARK: - SpeechTempoWorkerProtocol

@MainActor
protocol SpeechTempoWorkerProtocol: AnyObject {
    /// Собирает сессию чистоговорок для работы над темпом.
    func buildSession(childId: String) async -> SpeechTempoModels.Start.Response
}

// MARK: - SpeechTempoWorker (Clean Swift: Worker)
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Подбирает чистоговорки под целевые звуки ребёнка из локального корпуса.
// Offline / on-device.

@MainActor
final class SpeechTempoWorker: SpeechTempoWorkerProtocol {

    private let childRepository: any ChildRepository

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechTempo.Worker"
    )

    init(childRepository: any ChildRepository) {
        self.childRepository = childRepository
    }

    func buildSession(childId: String) async -> SpeechTempoModels.Start.Response {
        let targetSounds: [String]
        do {
            let child = try await childRepository.fetch(id: childId)
            targetSounds = child.targetSounds
        } catch {
            Self.logger.error(
                "Failed to read child sounds, using random rhymes: \(error.localizedDescription, privacy: .public)"
            )
            targetSounds = []
        }
        let rhymes = SpeechTempoCorpus.session(for: targetSounds)
        Self.logger.debug("Built speech-tempo session: \(rhymes.count) rhymes")
        return .init(rhymes: rhymes)
    }
}

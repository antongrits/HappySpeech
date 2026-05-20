import Foundation
import OSLog

// MARK: - SpeechNormsEncyclopediaWorkerProtocol

@MainActor
protocol SpeechNormsEncyclopediaWorkerProtocol: AnyObject {
    /// Возвращает все карточки норм.
    func loadCards() async -> [NormCard]
}

// MARK: - SpeechNormsEncyclopediaWorker (Clean Swift: Worker)
//
// v31 Волна A, Функция Ф10 «Что должно быть в возрасте».
//
// Загружает корпус карточек из бандл-пака. Стейтлесс, без зависимостей —
// отдельный объект сохраняем для тестируемости (мок-инъекция корпуса).

@MainActor
final class SpeechNormsEncyclopediaWorker: SpeechNormsEncyclopediaWorkerProtocol {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechNorms.Worker"
    )

    init() {}

    func loadCards() async -> [NormCard] {
        let cards = SpeechNormsEncyclopediaCorpus.cards
        Self.logger.debug("Loaded \(cards.count) speech norm cards")
        return cards
    }
}

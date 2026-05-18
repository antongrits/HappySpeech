import Foundation
import OSLog

// MARK: - SpeechTempoBusinessLogic

@MainActor
protocol SpeechTempoBusinessLogic: AnyObject {
    func start(request: SpeechTempoModels.Start.Request) async
    func recordBeat(request: SpeechTempoModels.Beat.Request) async
    func finishRhyme(request: SpeechTempoModels.Finish.Request) async
}

// MARK: - SpeechTempoDataStore

@MainActor
protocol SpeechTempoDataStore: AnyObject {
    var childId: String { get set }
    var rhymes: [TempoRhyme] { get set }
    var currentIndex: Int { get set }
    var smoothCount: Int { get set }
    var beats: [TimeInterval] { get set }
}

// MARK: - SpeechTempoInteractor (Clean Swift: Interactor)
//
// v29 Фаза 8, Функция 6 «Темп-дорожка».
//
// Бизнес-логика работы над темпом: накапливает моменты отбитых слогов,
// по завершении чистоговорки оценивает ровность темпа через `TempoAnalyzer`,
// ведёт прогресс по сессии. Без таймеров-соревнований — оценка качественная
// (ровно / немного неровно / неровно), что методически обязательно при
// заикании ([[exercise-templates]]).

@MainActor
final class SpeechTempoInteractor: SpeechTempoBusinessLogic, SpeechTempoDataStore {

    // MARK: - DataStore

    var childId: String
    var rhymes: [TempoRhyme] = []
    var currentIndex: Int = 0
    var smoothCount: Int = 0
    var beats: [TimeInterval] = []

    // MARK: - VIP

    var presenter: (any SpeechTempoPresentationLogic)?

    // MARK: - Deps

    private let worker: any SpeechTempoWorkerProtocol
    private let hapticService: any HapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechTempo.Interactor"
    )

    // MARK: - Init

    init(
        childId: String,
        worker: any SpeechTempoWorkerProtocol,
        hapticService: any HapticService
    ) {
        self.childId = childId
        self.worker = worker
        self.hapticService = hapticService
    }

    // MARK: - Start

    func start(request: SpeechTempoModels.Start.Request) async {
        childId = request.childId
        let response = await worker.buildSession(childId: request.childId)
        rhymes = response.rhymes
        currentIndex = 0
        smoothCount = 0
        beats = []
        Self.logger.debug("Started speech-tempo: \(response.rhymes.count) rhymes")
        await presenter?.presentStart(response: response)
    }

    // MARK: - Beat

    func recordBeat(request: SpeechTempoModels.Beat.Request) async {
        guard currentIndex < rhymes.count else { return }
        beats.append(request.timestamp)
        // Тактильный «такт» — лёгкий отклик на каждый отбитый слог.
        hapticService.impact(.light)
    }

    // MARK: - Finish

    func finishRhyme(request: SpeechTempoModels.Finish.Request) async {
        guard currentIndex < rhymes.count else {
            Self.logger.warning("finishRhyme called after session finished")
            return
        }
        let rhyme = rhymes[currentIndex]
        let coefficient = TempoAnalyzer.variationCoefficient(of: beats)
        let rating = TempoAnalyzer.rating(for: beats)
        if rating == .smooth {
            smoothCount += 1
            hapticService.notification(.success)
        }

        let beatsCounted = beats.count
        beats = []
        currentIndex += 1
        let isFinished = currentIndex >= rhymes.count
        let nextRhyme = isFinished ? nil : rhymes[currentIndex]

        let response = SpeechTempoModels.Finish.Response(
            rating: rating,
            variationCoefficient: coefficient,
            beatsCounted: beatsCounted,
            expectedSyllables: rhyme.syllableCount,
            isFinished: isFinished,
            nextRhyme: nextRhyme,
            nextRhymeIndex: isFinished ? nil : currentIndex,
            smoothCount: smoothCount,
            totalRhymes: rhymes.count
        )
        await presenter?.presentFinish(response: response)
    }
}

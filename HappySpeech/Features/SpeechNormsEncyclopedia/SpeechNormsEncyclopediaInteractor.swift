import Foundation
import OSLog

// MARK: - SpeechNormsEncyclopediaBusinessLogic

@MainActor
protocol SpeechNormsEncyclopediaBusinessLogic: AnyObject {
    func load(request: SpeechNormsEncyclopediaModels.Load.Request) async
    func selectAge(request: SpeechNormsEncyclopediaModels.SelectAge.Request) async
    func search(request: SpeechNormsEncyclopediaModels.Search.Request) async
}

// MARK: - SpeechNormsEncyclopediaInteractor (Clean Swift: Interactor)
//
// v31 Волна A, Функция Ф10 «Что должно быть в возрасте».
//
// Бизнес-логика: фильтрует карточки норм по выбранному возрасту и поисковому
// запросу, сохраняет состояние и пересобирает Response.

@MainActor
final class SpeechNormsEncyclopediaInteractor: SpeechNormsEncyclopediaBusinessLogic {

    // MARK: - VIP

    var presenter: (any SpeechNormsEncyclopediaPresentationLogic)?

    // MARK: - Deps

    private let worker: any SpeechNormsEncyclopediaWorkerProtocol

    // MARK: - State

    private var selectedAge: NormAge = .six
    private var query: String = ""

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SpeechNorms.Interactor"
    )

    init(worker: any SpeechNormsEncyclopediaWorkerProtocol) {
        self.worker = worker
    }

    func load(request: SpeechNormsEncyclopediaModels.Load.Request) async {
        selectedAge = request.initialAge
        query = request.query
        await present()
    }

    func selectAge(request: SpeechNormsEncyclopediaModels.SelectAge.Request) async {
        guard selectedAge != request.age else { return }
        selectedAge = request.age
        await present()
    }

    func search(request: SpeechNormsEncyclopediaModels.Search.Request) async {
        query = request.query
        await present()
    }

    private func present() async {
        let all = await worker.loadCards()
        let forAge = all.filter { $0.age == selectedAge }
        let filtered = SpeechNormsEncyclopediaCorpus.filter(by: query, in: forAge)
        Self.logger.debug(
            "Speech norms: age=\(self.selectedAge.rawValue), query='\(self.query, privacy: .public)', shown=\(filtered.count)/\(all.count)"
        )
        let response = SpeechNormsEncyclopediaModels.Load.Response(
            cards: filtered,
            selectedAge: selectedAge,
            query: query
        )
        await presenter?.presentLoad(response: response)
    }
}

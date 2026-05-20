import Foundation
import OSLog

// MARK: - CustomWordListBusinessLogic

@MainActor
protocol CustomWordListBusinessLogic: AnyObject {
    func load(request: CustomWordListModels.Load.Request) async
    func save(request: CustomWordListModels.Save.Request) async
    func delete(request: CustomWordListModels.Delete.Request) async
    func preview(request: CustomWordListModels.Preview.Request) async
}

// MARK: - CustomWordListDataStore

@MainActor
protocol CustomWordListDataStore: AnyObject {
    var specialistId: String { get set }
    var lists: [CustomWordListData] { get }
}

// MARK: - CustomWordListInteractor (Clean Swift: Interactor)
//
// v31 Волна C Ф.4 «Списки слов специалиста».

@MainActor
final class CustomWordListInteractor: CustomWordListBusinessLogic, CustomWordListDataStore {

    var specialistId: String
    private(set) var lists: [CustomWordListData] = []

    var presenter: (any CustomWordListPresentationLogic)?

    private let worker: any CustomWordListWorkerProtocol

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "CustomWordList.Interactor"
    )

    init(
        specialistId: String,
        worker: any CustomWordListWorkerProtocol
    ) {
        self.specialistId = specialistId
        self.worker = worker
    }

    func load(request: CustomWordListModels.Load.Request) async {
        specialistId = request.specialistId
        lists = await worker.fetchAll(specialistId: specialistId)
        await presenter?.presentLoad(response: .init(lists: lists))
    }

    func save(request: CustomWordListModels.Save.Request) async {
        let trimmedName = request.draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            await presenter?.presentSaveFailure(response: .init(reason: .emptyName))
            return
        }
        let cleanWords = request.draft.words
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleanWords.isEmpty else {
            await presenter?.presentSaveFailure(response: .init(reason: .emptyWords))
            return
        }
        let existing = lists.first(where: { $0.id == request.draft.id })
        let createdAt = existing?.createdAt ?? Date()
        let data = request.draft.toData(
            specialistId: request.specialistId,
            createdAt: createdAt,
            now: Date()
        )
        await worker.save(data)
        lists = await worker.fetchAll(specialistId: specialistId)
        await presenter?.presentSaveSuccess(response: .init(savedId: data.id))
        await presenter?.presentLoad(response: .init(lists: lists))
    }

    func delete(request: CustomWordListModels.Delete.Request) async {
        let removed = await worker.delete(id: request.id)
        guard removed else { return }
        lists.removeAll { $0.id == request.id }
        await presenter?.presentDelete(response: .init(removedId: request.id))
        await presenter?.presentLoad(response: .init(lists: lists))
    }

    func preview(request: CustomWordListModels.Preview.Request) async {
        let exercises = worker.generateExercises(from: request.draft)
        await presenter?.presentPreview(response: .init(exercises: exercises))
    }
}

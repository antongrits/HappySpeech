@testable import HappySpeech
import XCTest

// MARK: - Stub Worker

@MainActor
private final class StubCustomWordListWorker: CustomWordListWorkerProtocol {

    var lists: [CustomWordListData] = []
    private(set) var saveCount = 0
    private(set) var deleteCount = 0
    private(set) var fetchCount = 0
    private(set) var lastSavedId: String?

    func fetchAll(specialistId: String) async -> [CustomWordListData] {
        fetchCount += 1
        return lists.filter { $0.specialistId == specialistId }
    }

    func save(_ data: CustomWordListData) async {
        saveCount += 1
        lastSavedId = data.id
        lists.removeAll { $0.id == data.id }
        lists.append(data)
    }

    func delete(id: String) async -> Bool {
        deleteCount += 1
        guard lists.contains(where: { $0.id == id }) else { return false }
        lists.removeAll { $0.id == id }
        return true
    }

    func generateExercises(from draft: WordListDraft) -> [GeneratedExercise] {
        // Реальную логику тестируем отдельно — здесь возвращаем минимум.
        guard !draft.words.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return []
        }
        return [
            GeneratedExercise(
                id: "\(draft.id)-rep",
                kind: .repeatAfterModel,
                words: draft.words,
                targetSound: draft.targetSound
            )
        ]
    }
}

// MARK: - Spy Presenter

@MainActor
private final class SpyCustomWordListPresenter:
    CustomWordListPresentationLogic, @unchecked Sendable {
    var loadCount = 0
    var saveSuccessCount = 0
    var saveFailureCount = 0
    var deleteCount = 0
    var previewCount = 0
    var lastSaveFailureReason: ValidationError?
    var lastLoadCount: Int = 0
    var lastPreviewCount: Int = 0

    func presentLoad(response: CustomWordListModels.Load.Response) async {
        loadCount += 1
        lastLoadCount = response.lists.count
    }
    func presentSaveSuccess(response: CustomWordListModels.Save.Response) async {
        saveSuccessCount += 1
    }
    func presentSaveFailure(response: CustomWordListModels.Save.FailureResponse) async {
        saveFailureCount += 1
        lastSaveFailureReason = response.reason
    }
    func presentDelete(response: CustomWordListModels.Delete.Response) async {
        deleteCount += 1
    }
    func presentPreview(response: CustomWordListModels.Preview.Response) async {
        previewCount += 1
        lastPreviewCount = response.exercises.count
    }
}

// MARK: - Interactor Tests

@MainActor
final class CustomWordListInteractorTests: XCTestCase {

    private func makeSUT(
        specialistId: String = "spec-1"
    ) -> (CustomWordListInteractor, SpyCustomWordListPresenter, StubCustomWordListWorker) {
        let worker = StubCustomWordListWorker()
        let interactor = CustomWordListInteractor(specialistId: specialistId, worker: worker)
        let spy = SpyCustomWordListPresenter()
        interactor.presenter = spy
        return (interactor, spy, worker)
    }

    func test_load_presentsEmptyList() async {
        let (sut, spy, _) = makeSUT()
        await sut.load(request: .init(specialistId: "spec-1"))
        XCTAssertEqual(spy.loadCount, 1)
        XCTAssertEqual(spy.lastLoadCount, 0)
    }

    func test_save_validDraft_persistsAndReloads() async {
        let (sut, spy, worker) = makeSUT()
        let draft = WordListDraft(name: "Список Р", targetSound: "Р", words: ["рыба", "ракета"])
        await sut.save(request: .init(specialistId: "spec-1", draft: draft))
        XCTAssertEqual(spy.saveSuccessCount, 1)
        XCTAssertEqual(worker.saveCount, 1)
        XCTAssertEqual(spy.lastLoadCount, 1)
    }

    func test_save_emptyName_isRejected() async {
        let (sut, spy, worker) = makeSUT()
        let draft = WordListDraft(name: "  ", targetSound: "Р", words: ["рыба"])
        await sut.save(request: .init(specialistId: "spec-1", draft: draft))
        XCTAssertEqual(spy.saveFailureCount, 1)
        XCTAssertEqual(spy.lastSaveFailureReason, .emptyName)
        XCTAssertEqual(worker.saveCount, 0)
    }

    func test_save_emptyWords_isRejected() async {
        let (sut, spy, worker) = makeSUT()
        let draft = WordListDraft(name: "Список", targetSound: "Р", words: ["  ", ""])
        await sut.save(request: .init(specialistId: "spec-1", draft: draft))
        XCTAssertEqual(spy.saveFailureCount, 1)
        XCTAssertEqual(spy.lastSaveFailureReason, .emptyWords)
        XCTAssertEqual(worker.saveCount, 0)
    }

    func test_save_trimsWordsAndName() async {
        let (sut, _, worker) = makeSUT()
        let draft = WordListDraft(name: "  Имя  ", targetSound: "Ш", words: ["  шапка ", " ", "штаны  "])
        await sut.save(request: .init(specialistId: "spec-1", draft: draft))
        let saved = worker.lists.first
        XCTAssertEqual(saved?.name, "Имя")
        XCTAssertEqual(saved?.words, ["шапка", "штаны"])
    }

    func test_delete_removesById() async {
        let (sut, spy, worker) = makeSUT()
        let draft = WordListDraft(name: "Список", targetSound: "Р", words: ["рыба"])
        await sut.save(request: .init(specialistId: "spec-1", draft: draft))
        let id = worker.lists.first?.id ?? ""
        await sut.delete(request: .init(id: id))
        XCTAssertEqual(spy.deleteCount, 1)
        XCTAssertTrue(worker.lists.isEmpty)
    }

    func test_delete_unknownId_noEvent() async {
        let (sut, spy, _) = makeSUT()
        await sut.delete(request: .init(id: "missing"))
        XCTAssertEqual(spy.deleteCount, 0)
    }

    func test_preview_callsWorker_andPresents() async {
        let (sut, spy, _) = makeSUT()
        let draft = WordListDraft(name: "Х", targetSound: "Р", words: ["a", "b"])
        await sut.preview(request: .init(draft: draft))
        XCTAssertEqual(spy.previewCount, 1)
        XCTAssertEqual(spy.lastPreviewCount, 1)
    }

    func test_save_existingDraft_preservesCreatedAt() async {
        let (sut, _, worker) = makeSUT()
        let draft = WordListDraft(name: "v1", targetSound: "Р", words: ["рыба"])
        await sut.save(request: .init(specialistId: "spec-1", draft: draft))
        await sut.load(request: .init(specialistId: "spec-1"))
        let originalCreatedAt = worker.lists.first?.createdAt

        // Sleep tiny bit so updatedAt differs
        try? await Task.sleep(nanoseconds: 10_000_000)
        let updated = WordListDraft(id: draft.id, name: "v2", targetSound: "Р", words: ["рак"])
        await sut.save(request: .init(specialistId: "spec-1", draft: updated))
        XCTAssertEqual(worker.lists.first?.createdAt, originalCreatedAt)
        XCTAssertEqual(worker.lists.first?.name, "v2")
    }
}

// MARK: - Worker: exercise generation tests

@MainActor
final class CustomWordListWorkerGenerationTests: XCTestCase {

    func test_generation_emptyWords_returnsNoExercises() {
        let worker = LiveCustomWordListWorker(realmActor: RealmActor())
        let exercises = worker.generateExercises(from: WordListDraft(name: "x", targetSound: "Р", words: []))
        XCTAssertTrue(exercises.isEmpty)
    }

    func test_generation_oneWord_yieldsOnlyRepeatAfterModel() {
        let worker = LiveCustomWordListWorker(realmActor: RealmActor())
        let exercises = worker.generateExercises(from: WordListDraft(name: "x", targetSound: "Р", words: ["рыба"]))
        XCTAssertEqual(exercises.count, 1)
        XCTAssertEqual(exercises.first?.kind, .repeatAfterModel)
    }

    func test_generation_fourWords_yieldsAllThreeKinds() {
        let worker = LiveCustomWordListWorker(realmActor: RealmActor())
        let exercises = worker.generateExercises(from:
            WordListDraft(name: "x", targetSound: "Р", words: ["рыба", "ракета", "роза", "рот"])
        )
        XCTAssertEqual(exercises.count, 3)
        let kinds = Set(exercises.map(\.kind))
        XCTAssertEqual(kinds, [.repeatAfterModel, .bingo, .memory])
    }

    func test_generation_trimsAndFiltersBlankWords() {
        let worker = LiveCustomWordListWorker(realmActor: RealmActor())
        let exercises = worker.generateExercises(from:
            WordListDraft(name: "x", targetSound: "Р", words: ["  рыба ", "", " ", "ракета"])
        )
        XCTAssertEqual(exercises.first?.words, ["рыба", "ракета"])
    }
}

// MARK: - Models conversion tests

final class CustomWordListDraftTests: XCTestCase {

    func test_draftToData_roundtrip() {
        let originalDraft = WordListDraft(
            id: "test-id",
            name: " Имя ",
            targetSound: "Р",
            words: ["  рыба ", " ", "ракета"]
        )
        let data = originalDraft.toData(
            specialistId: "spec-1",
            createdAt: Date(timeIntervalSince1970: 0),
            now: Date(timeIntervalSince1970: 100)
        )
        XCTAssertEqual(data.name, "Имя")
        XCTAssertEqual(data.words, ["рыба", "ракета"])
        XCTAssertEqual(data.specialistId, "spec-1")
        XCTAssertEqual(data.createdAt.timeIntervalSince1970, 0)
        XCTAssertEqual(data.updatedAt.timeIntervalSince1970, 100)
    }

    func test_draftFromData_preservesFields() {
        let data = CustomWordListData(
            id: "id-1",
            specialistId: "s",
            name: "Список",
            targetSound: "Ш",
            words: ["шапка"],
            createdAt: Date(),
            updatedAt: Date()
        )
        let draft = WordListDraft.from(data)
        XCTAssertEqual(draft.id, "id-1")
        XCTAssertEqual(draft.name, "Список")
        XCTAssertEqual(draft.targetSound, "Ш")
        XCTAssertEqual(draft.words, ["шапка"])
    }
}

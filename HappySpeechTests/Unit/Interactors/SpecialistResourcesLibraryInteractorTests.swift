@testable import HappySpeech
import XCTest

// MARK: - SpecialistResourcesLibraryInteractorTests
//
// Библиотека ресурсов специалиста: каталог из SpecialistResourcesLibraryContent
// + фильтр по типу/избранному; «прочитано»/«избранное» персистятся в
// SpecialistResourcesLibraryStore. Тесты используют изолированный UserDefaults.

@MainActor
final class SpecialistResourcesLibraryInteractorTests: XCTestCase {

    private typealias Kind = SpecialistResourcesLibraryModels.ResourceKind

    private var defaults: UserDefaults!
    private let suiteName = "test.specResources"

    override func setUp() async throws {
        try await super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        try await super.tearDown()
    }

    private func makeSUT(specialistId: String = "spec-1") -> SpecialistResourcesLibraryInteractor {
        SpecialistResourcesLibraryInteractor(specialistId: specialistId, defaults: defaults)
    }

    // MARK: - Init / seed

    func test_init_storesSpecialistId() {
        let sut = makeSUT(specialistId: "s-55")
        XCTAssertEqual(sut.specialistId, "s-55")
    }

    func test_initialState_filterIsAll() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.filter, .all)
        XCTAssertEqual(sut.state.readCount, 0)
        XCTAssertEqual(sut.state.savedCount, 0)
    }

    func test_initialState_resourcesWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.resources.isEmpty)
        XCTAssertEqual(Set(sut.state.resources.map(\.id)).count, sut.state.resources.count)
        for resource in sut.state.resources {
            XCTAssertFalse(resource.title.isEmpty)
            // Каждый ресурс имеет реальный методический текст для открытия.
            XCTAssertFalse(resource.body.isEmpty)
            XCTAssertNotEqual(resource.kind, .all)
            XCTAssertNotEqual(resource.kind, .saved)
        }
    }

    // MARK: - open / reader

    func test_open_setsOpenedResourceAndMarksRead() {
        let sut = makeSUT()
        let id = sut.state.resources[0].id
        sut.open(id)
        XCTAssertEqual(sut.state.openedResource?.id, id)
        XCTAssertEqual(sut.state.resources.first { $0.id == id }?.isRead, true)
        XCTAssertEqual(sut.state.readCount, 1)
    }

    func test_open_readPersistsAcrossInstances() {
        let sut1 = makeSUT(specialistId: "spec-open")
        let id = sut1.state.resources[0].id
        sut1.open(id)
        let sut2 = makeSUT(specialistId: "spec-open")
        XCTAssertEqual(sut2.state.resources.first { $0.id == id }?.isRead, true)
    }

    func test_closeReader_clearsOpenedResource() {
        let sut = makeSUT()
        sut.open(sut.state.resources[0].id)
        sut.closeReader()
        XCTAssertNil(sut.state.openedResource)
    }

    func test_open_unknownId_noMutation() {
        let sut = makeSUT()
        sut.open("does-not-exist")
        XCTAssertNil(sut.state.openedResource)
        XCTAssertEqual(sut.state.readCount, 0)
    }

    func test_initialState_coversConcreteKinds() {
        let sut = makeSUT()
        let present = Set(sut.state.resources.map(\.kind))
        XCTAssertEqual(present, Set([.pdf, .video, .article]))
    }

    // MARK: - setFilter

    func test_setFilter_updatesFilter() {
        let sut = makeSUT()
        sut.setFilter(.video)
        XCTAssertEqual(sut.state.filter, .video)
    }

    func test_filtered_concreteKind_returnsOnlyThatKind() {
        let sut = makeSUT()
        for kind in [Kind.pdf, .video, .article] {
            sut.setFilter(kind)
            let result = sut.state.filtered
            XCTAssertFalse(result.isEmpty)
            XCTAssertTrue(result.allSatisfy { $0.kind == kind })
        }
    }

    // MARK: - read / saved

    func test_toggleRead_marksAndCounts() {
        let sut = makeSUT()
        let id = sut.state.resources[0].id
        sut.toggleRead(id)
        XCTAssertEqual(sut.state.resources.first { $0.id == id }?.isRead, true)
        XCTAssertEqual(sut.state.readCount, 1)
    }

    func test_toggleSaved_marksAndCounts() {
        let sut = makeSUT()
        let id = sut.state.resources[0].id
        sut.toggleSaved(id)
        XCTAssertEqual(sut.state.resources.first { $0.id == id }?.isSaved, true)
        XCTAssertEqual(sut.state.savedCount, 1)
    }

    func test_savedFilter_showsOnlySaved() {
        let sut = makeSUT()
        let id = sut.state.resources[0].id
        sut.toggleSaved(id)
        sut.setFilter(.saved)
        XCTAssertEqual(sut.state.filtered.count, 1)
        XCTAssertEqual(sut.state.filtered.first?.id, id)
    }

    func test_persistence_readAndSavedSurviveNewInstance() {
        let sut1 = makeSUT(specialistId: "spec-persist")
        let readId = sut1.state.resources[0].id
        let savedId = sut1.state.resources[1].id
        sut1.toggleRead(readId)
        sut1.toggleSaved(savedId)
        let sut2 = makeSUT(specialistId: "spec-persist")
        XCTAssertEqual(sut2.state.resources.first { $0.id == readId }?.isRead, true)
        XCTAssertEqual(sut2.state.resources.first { $0.id == savedId }?.isSaved, true)
    }
}

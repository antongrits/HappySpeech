@testable import HappySpeech
import XCTest

// MARK: - SpecialistResourcesLibraryInteractorTests
//
// SpecialistResourcesLibraryInteractor is a thin VIP MVP variant (@Observable). It
// holds a fixed resource list and a kind filter; setFilter(_:) updates the filter.
// Tests cover the seed, the filter mutation and the `filtered` derive (the .all
// pass-through plus each concrete kind, and consistency between filter and result).
// (ResourceKind.title/.icon maps are purely presentational — intentionally skipped.)

@MainActor
final class SpecialistResourcesLibraryInteractorTests: XCTestCase {

    private typealias Kind = SpecialistResourcesLibraryModels.ResourceKind

    private func makeSUT() -> SpecialistResourcesLibraryInteractor {
        SpecialistResourcesLibraryInteractor(specialistId: "spec-1")
    }

    // MARK: - Init / seed

    func test_init_storesSpecialistId() {
        let sut = SpecialistResourcesLibraryInteractor(specialistId: "s-55")
        XCTAssertEqual(sut.specialistId, "s-55")
    }

    func test_initialState_filterIsAll() {
        let sut = makeSUT()
        XCTAssertEqual(sut.state.filter, .all)
        XCTAssertEqual(sut.state, .initial)
    }

    func test_initialState_resourcesWellFormed() {
        let sut = makeSUT()
        XCTAssertFalse(sut.state.resources.isEmpty)
        XCTAssertEqual(Set(sut.state.resources.map(\.id)).count, sut.state.resources.count)
        for resource in sut.state.resources {
            XCTAssertFalse(resource.title.isEmpty)
            XCTAssertNotEqual(resource.kind, .all)   // resources are concrete kinds
        }
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

    func test_setFilter_doesNotMutateResources() {
        let sut = makeSUT()
        let before = sut.state.resources
        sut.setFilter(.pdf)
        XCTAssertEqual(sut.state.resources, before)
    }

    // MARK: - filtered

    func test_filtered_all_returnsEverything() {
        let sut = makeSUT()
        sut.setFilter(.all)
        XCTAssertEqual(sut.state.filtered, sut.state.resources)
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

    func test_filtered_countsSumToTotal() {
        let sut = makeSUT()
        let pdf = sut.state.resources.filter { $0.kind == .pdf }.count
        let video = sut.state.resources.filter { $0.kind == .video }.count
        let article = sut.state.resources.filter { $0.kind == .article }.count
        XCTAssertEqual(pdf + video + article, sut.state.resources.count)
    }
}

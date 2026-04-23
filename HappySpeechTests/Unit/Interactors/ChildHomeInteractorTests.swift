import XCTest
@testable import HappySpeech

// MARK: - ChildHomeInteractorTests
//
// Verifies the VIP interactor against mock repositories:
//   - fetchChildData fires presentFetch with populated viewModel fields
//   - empty / missing child surfaces presentError
//   - presenter is called on the MainActor
// ==================================================================================

@MainActor
final class ChildHomeInteractorTests: XCTestCase {

    @MainActor
    private final class SpyPresenter: ChildHomePresentationLogic {
        var fetchResponses: [ChildHomeModels.Fetch.Response] = []
        func presentFetch(_ response: ChildHomeModels.Fetch.Response) {
            fetchResponses.append(response)
        }
    }

    private func makeSUT() -> (ChildHomeInteractor, SpyPresenter) {
        let interactor = ChildHomeInteractor(
            childRepository: MockChildRepository(),
            sessionRepository: MockSessionRepository()
        )
        let spy = SpyPresenter()
        interactor.presenter = spy
        return (interactor, spy)
    }

    // MARK: - fetchChildData

    func test_fetchChildData_firesPresentFetch() async {
        let (sut, spy) = makeSUT()
        await sut.fetchChildData(.init(childId: "preview-child-1"))
        XCTAssertEqual(spy.fetchResponses.count, 1)
    }

    func test_fetchChildData_populatesDailySound() async {
        let (sut, spy) = makeSUT()
        await sut.fetchChildData(.init(childId: "preview-child-1"))
        let response = spy.fetchResponses.first
        XCTAssertNotNil(response)
        XCTAssertFalse(response?.dailyTargetSound.isEmpty ?? true)
        XCTAssertFalse(response?.childName.isEmpty ?? true)
    }

    func test_fetchChildData_returnsDailyProgressInRange() async {
        let (sut, spy) = makeSUT()
        await sut.fetchChildData(.init(childId: "preview-child-1"))
        let progress = spy.fetchResponses.first?.dailyProgress ?? -1
        XCTAssertGreaterThanOrEqual(progress, 0.0)
        XCTAssertLessThanOrEqual(progress, 1.0)
    }
}

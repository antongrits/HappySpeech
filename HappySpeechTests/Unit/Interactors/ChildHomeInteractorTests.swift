import XCTest
@testable import HappySpeech

// MARK: - ChildHomeInteractorTests

@MainActor
final class ChildHomeInteractorTests: XCTestCase {

    func testFetchChildDataPopulatesName() async {
        let interactor = ChildHomeInteractor()
        await interactor.fetchChildData(id: "preview-child-1")
        XCTAssertFalse(interactor.viewModel.childName.isEmpty, "Child name должен быть заполнен")
    }

    func testFetchChildDataSetsStreak() async {
        let interactor = ChildHomeInteractor()
        await interactor.fetchChildData(id: "preview-child-1")
        XCTAssertGreaterThanOrEqual(interactor.viewModel.currentStreak, 0)
    }

    func testFetchChildDataHasDailyMission() async {
        let interactor = ChildHomeInteractor()
        await interactor.fetchChildData(id: "preview-child-1")
        XCTAssertFalse(interactor.viewModel.dailyMission.targetSound.isEmpty)
    }

    func testLoadingStateIsFalseAfterFetch() async {
        let interactor = ChildHomeInteractor()
        XCTAssertFalse(interactor.viewModel.isLoading)
        await interactor.fetchChildData(id: "preview-child-1")
        XCTAssertFalse(interactor.viewModel.isLoading, "isLoading должен быть false после загрузки")
    }
}

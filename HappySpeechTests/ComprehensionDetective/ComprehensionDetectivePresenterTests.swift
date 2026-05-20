@testable import HappySpeech
import XCTest

@MainActor
private final class SpyDetectiveDisplay:
    ComprehensionDetectiveDisplayLogic, @unchecked Sendable {
    var startVM: ComprehensionDetectiveModels.Start.ViewModel?
    var pickVM: ComprehensionDetectiveModels.Pick.ViewModel?

    func displayStart(viewModel: ComprehensionDetectiveModels.Start.ViewModel) async {
        startVM = viewModel
    }
    func displayPick(viewModel: ComprehensionDetectiveModels.Pick.ViewModel) async {
        pickVM = viewModel
    }
}

@MainActor
final class ComprehensionDetectivePresenterTests: XCTestCase {

    private func makeResponse() -> ComprehensionDetectiveModels.Start.Response {
        let pictures = [
            DetectivePicture(id: "p1", symbolName: "soccerball", label: "мяч"),
            DetectivePicture(id: "p2", symbolName: "car.fill", label: "машина")
        ]
        return .init(
            tier: .simple,
            item: DetectiveItem(
                id: "i1",
                tier: .simple,
                instruction: "Покажи мяч",
                pictures: pictures,
                correctPictureId: "p1"
            ),
            shuffledPictures: pictures,
            availableTiers: GrammarTier.allCases,
            totalItemsInTier: 30,
            itemIndex: 1
        )
    }

    func test_presentStart_includesInstruction() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentStart(response: makeResponse())
        XCTAssertEqual(spy.startVM?.instruction, "Покажи мяч")
        XCTAssertEqual(spy.startVM?.pictures.count, 2)
    }

    func test_presentStart_includesAllAvailableTiers() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentStart(response: makeResponse())
        XCTAssertEqual(spy.startVM?.availableTiers.count, 4)
        XCTAssertEqual(spy.startVM?.availableTiers.first?.isSelected, true)
    }

    func test_presentPick_correct() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentPick(response: .init(
            isCorrect: true,
            pickedPictureId: "p1",
            correctPictureId: "p1",
            instruction: "Покажи мяч"
        ))
        XCTAssertEqual(spy.pickVM?.isCorrect, true)
    }

    func test_presentPick_wrong() async {
        let spy = SpyDetectiveDisplay()
        let presenter = ComprehensionDetectivePresenter(displayLogic: spy)
        await presenter.presentPick(response: .init(
            isCorrect: false,
            pickedPictureId: "p2",
            correctPictureId: "p1",
            instruction: "Покажи мяч"
        ))
        XCTAssertEqual(spy.pickVM?.isCorrect, false)
        XCTAssertEqual(spy.pickVM?.correctPictureId, "p1")
    }

    func test_localized_returnsKeyIfMissing() {
        let result = ComprehensionDetectivePresenter.localized("missing.key.does.not.exist")
        XCTAssertEqual(result, "missing.key.does.not.exist")
    }
}

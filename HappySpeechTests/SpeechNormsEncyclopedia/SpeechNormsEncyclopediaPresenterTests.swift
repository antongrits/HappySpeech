@testable import HappySpeech
import XCTest

// MARK: - Spy DisplayLogic

@MainActor
private final class SpySpeechNormsDisplay: SpeechNormsEncyclopediaDisplayLogic, @unchecked Sendable {
    var loadVM: SpeechNormsEncyclopediaModels.Load.ViewModel?

    func displayLoad(viewModel: SpeechNormsEncyclopediaModels.Load.ViewModel) async {
        loadVM = viewModel
    }
}

// MARK: - Presenter Tests

@MainActor
final class SpeechNormsEncyclopediaPresenterTests: XCTestCase {

    private func makeSUT() -> (SpeechNormsEncyclopediaPresenter, SpySpeechNormsDisplay) {
        let display = SpySpeechNormsDisplay()
        let sut = SpeechNormsEncyclopediaPresenter(displayLogic: display)
        return (sut, display)
    }

    private func makeCards(age: NormAge = .six, count: Int = 3) -> [NormCard] {
        (0..<count).map { idx in
            NormCard(
                id: "card-\(age.rawValue)-\(idx)",
                age: age,
                axis: .sounds,
                title: "Звуки в \(age.rawValue) лет",
                summary: "Резюме \(idx)",
                body: "Тело текста \(idx)",
                sources: ["Источник \(idx)"]
            )
        }
    }

    func test_presentLoad_buildsAgeTabsForAllFourAges() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: .init(
            cards: makeCards(),
            selectedAge: .six,
            query: ""
        ))
        XCTAssertEqual(display.loadVM?.ageTabs.count, NormAge.allCases.count)
    }

    func test_presentLoad_marksSelectedAgeTab() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: .init(
            cards: makeCards(age: .seven),
            selectedAge: .seven,
            query: ""
        ))
        let selectedTabs = display.loadVM?.ageTabs.filter { $0.isSelected } ?? []
        XCTAssertEqual(selectedTabs.count, 1)
        XCTAssertEqual(selectedTabs.first?.age, .seven)
    }

    func test_presentLoad_groupsCardsByAxis() async {
        let (sut, display) = makeSUT()
        let mixed: [NormCard] = [
            NormCard(id: "a", age: .six, axis: .sounds, title: "Z",
                     summary: "s", body: "b", sources: []),
            NormCard(id: "b", age: .six, axis: .grammar, title: "G",
                     summary: "s", body: "b", sources: []),
            NormCard(id: "c", age: .six, axis: .redflags, title: "R",
                     summary: "s", body: "b", sources: [])
        ]
        await sut.presentLoad(response: .init(
            cards: mixed,
            selectedAge: .six,
            query: ""
        ))
        XCTAssertEqual(display.loadVM?.sections.count, 3)
    }

    func test_presentLoad_redflagsSectionHasIsRedFlagTrue() async {
        let (sut, display) = makeSUT()
        let redflagCard = NormCard(
            id: "rf", age: .six, axis: .redflags, title: "Тревожно",
            summary: "Внимание", body: "Тело", sources: []
        )
        await sut.presentLoad(response: .init(
            cards: [redflagCard],
            selectedAge: .six,
            query: ""
        ))
        let section = display.loadVM?.sections.first
        XCTAssertEqual(section?.isRedFlag, true)
        XCTAssertEqual(section?.cards.first?.isRedFlag, true)
    }

    func test_presentLoad_normalAxisHasIsRedFlagFalse() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: .init(
            cards: makeCards(),
            selectedAge: .six,
            query: ""
        ))
        let section = display.loadVM?.sections.first { $0.axis == .sounds }
        XCTAssertEqual(section?.isRedFlag, false)
        XCTAssertEqual(section?.cards.first?.isRedFlag, false)
    }

    func test_presentLoad_emptyCards_showsIsEmptyTrue() async {
        let (sut, display) = makeSUT()
        await sut.presentLoad(response: .init(
            cards: [],
            selectedAge: .six,
            query: ""
        ))
        XCTAssertEqual(display.loadVM?.isEmpty, true)
        XCTAssertFalse(display.loadVM?.emptyMessage.isEmpty ?? true)
    }

    func test_presentLoad_emptyMessage_changesByQueryPresence() async {
        let (sut, display) = makeSUT()

        await sut.presentLoad(response: .init(cards: [], selectedAge: .six, query: ""))
        let noContentMessage = display.loadVM?.emptyMessage

        await sut.presentLoad(response: .init(cards: [], selectedAge: .six, query: "несуществующее"))
        let noMatchMessage = display.loadVM?.emptyMessage

        XCTAssertNotEqual(noContentMessage, noMatchMessage)
    }

    func test_presentLoad_cardAccessibilityLabel_containsTitleAndSummary() async {
        let (sut, display) = makeSUT()
        let card = NormCard(
            id: "x", age: .six, axis: .sounds,
            title: "Уникальный заголовок", summary: "Уникальное резюме",
            body: "Тело", sources: []
        )
        await sut.presentLoad(response: .init(
            cards: [card],
            selectedAge: .six,
            query: ""
        ))
        let cardVM = display.loadVM?.sections.first?.cards.first
        XCTAssertTrue(cardVM?.accessibilityLabel.contains("Уникальный заголовок") ?? false)
        XCTAssertTrue(cardVM?.accessibilityLabel.contains("Уникальное резюме") ?? false)
    }

    func test_presentLoad_sourcesArePropagated() async {
        let (sut, display) = makeSUT()
        let card = NormCard(
            id: "x", age: .six, axis: .sounds,
            title: "T", summary: "s", body: "b",
            sources: ["Гвоздев А.Н., 1961", "Цейтлин С.Н., 2000"]
        )
        await sut.presentLoad(response: .init(
            cards: [card],
            selectedAge: .six,
            query: ""
        ))
        let cardVM = display.loadVM?.sections.first?.cards.first
        XCTAssertEqual(cardVM?.sources.count, 2)
    }
}

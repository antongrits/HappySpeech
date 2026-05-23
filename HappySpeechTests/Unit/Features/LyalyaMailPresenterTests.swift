@testable import HappySpeech
import XCTest

// MARK: - LyalyaMailPresenterTests

@MainActor
final class LyalyaMailPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: LyalyaMailDisplayLogic {
        var lastLettersVM: LyalyaMailModels.LoadMail.ViewModel?
        var lastOpenedVM: LyalyaMailModels.OpenLetter.ViewModel?
        var lastDeletedId: UUID?

        func displayLetters(viewModel: LyalyaMailModels.LoadMail.ViewModel) async {
            lastLettersVM = viewModel
        }

        func displayOpenedLetter(viewModel: LyalyaMailModels.OpenLetter.ViewModel) async {
            lastOpenedVM = viewModel
        }

        func displayDeleted(removedId: UUID) async {
            lastDeletedId = removedId
        }
    }

    private func makeSUT() -> (LyalyaMailPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = LyalyaMailPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeLetter(
        id: UUID = UUID(),
        kind: LetterKind = .welcome,
        title: String = "Привет!",
        body: String = "Тело письма",
        isRead: Bool = false,
        audioFileName: String? = nil
    ) -> LyalyaLetterDTO {
        LyalyaLetterDTO(
            id: id,
            childId: "child-1",
            kind: kind,
            title: title,
            body: body,
            date: Date(timeIntervalSince1970: 1_716_480_000),
            isRead: isRead,
            audioFileName: audioFileName
        )
    }

    // MARK: - presentLetters

    func test_presentLetters_callsDisplay() async {
        let (sut, spy) = makeSUT()
        let response = LyalyaMailModels.LoadMail.Response(childId: "child-1", letters: [])
        await sut.presentLetters(response: response)
        XCTAssertNotNil(spy.lastLettersVM)
    }

    func test_presentLetters_emptyLetters_isEmptyTrue() async {
        let (sut, spy) = makeSUT()
        let response = LyalyaMailModels.LoadMail.Response(childId: "child-1", letters: [])
        await sut.presentLetters(response: response)
        XCTAssertTrue(spy.lastLettersVM?.isEmpty ?? false)
    }

    func test_presentLetters_unreadCountCountsOnlyUnread() async {
        let (sut, spy) = makeSUT()
        let letters = [
            makeLetter(isRead: false),
            makeLetter(isRead: false),
            makeLetter(isRead: true)
        ]
        let response = LyalyaMailModels.LoadMail.Response(childId: "child-1", letters: letters)
        await sut.presentLetters(response: response)
        XCTAssertEqual(spy.lastLettersVM?.unreadCount, 2)
    }

    func test_presentLetters_unreadSortedFirst() async {
        let (sut, spy) = makeSUT()
        let readLetter = makeLetter(id: UUID(), isRead: true)
        let unreadLetter = makeLetter(id: UUID(), isRead: false)
        let response = LyalyaMailModels.LoadMail.Response(
            childId: "child-1",
            letters: [readLetter, unreadLetter]
        )
        await sut.presentLetters(response: response)
        XCTAssertFalse(spy.lastLettersVM?.rows.first?.isRead ?? true)
    }

    func test_presentLetters_longBodyTruncatedWithEllipsis() async {
        let (sut, spy) = makeSUT()
        let longBody = String(repeating: "А", count: 120)
        let letter = makeLetter(body: longBody)
        let response = LyalyaMailModels.LoadMail.Response(childId: "child-1", letters: [letter])
        await sut.presentLetters(response: response)
        let preview = spy.lastLettersVM?.rows.first?.preview ?? ""
        XCTAssertTrue(preview.hasSuffix("…"))
        XCTAssertLessThanOrEqual(preview.count, 85) // 80 + "…"
    }

    func test_presentLetters_shortBodyNotTruncated() async {
        let (sut, spy) = makeSUT()
        let shortBody = "Короткое письмо"
        let letter = makeLetter(body: shortBody)
        let response = LyalyaMailModels.LoadMail.Response(childId: "child-1", letters: [letter])
        await sut.presentLetters(response: response)
        XCTAssertFalse(spy.lastLettersVM?.rows.first?.preview.hasSuffix("…") ?? true)
    }

    func test_presentLetters_accessibilitySummaryNonEmpty() async {
        let (sut, spy) = makeSUT()
        let response = LyalyaMailModels.LoadMail.Response(
            childId: "child-1",
            letters: [makeLetter()]
        )
        await sut.presentLetters(response: response)
        XCTAssertFalse(spy.lastLettersVM?.accessibilitySummary.isEmpty ?? true)
    }

    // MARK: - presentOpenedLetter

    func test_presentOpenedLetter_setsTitle() async {
        let (sut, spy) = makeSUT()
        let letter = makeLetter(title: "Ура! Три дня подряд!")
        await sut.presentOpenedLetter(response: .init(letter: letter))
        XCTAssertEqual(spy.lastOpenedVM?.title, "Ура! Три дня подряд!")
    }

    func test_presentOpenedLetter_noAudio_hasAudioFalse() async {
        let (sut, spy) = makeSUT()
        let letter = makeLetter(audioFileName: nil)
        await sut.presentOpenedLetter(response: .init(letter: letter))
        XCTAssertFalse(spy.lastOpenedVM?.hasAudio ?? true)
    }

    func test_presentOpenedLetter_withAudio_hasAudioTrue() async {
        let (sut, spy) = makeSUT()
        let letter = makeLetter(audioFileName: "lyalya_welcome.m4a")
        await sut.presentOpenedLetter(response: .init(letter: letter))
        XCTAssertTrue(spy.lastOpenedVM?.hasAudio ?? false)
        XCTAssertEqual(spy.lastOpenedVM?.audioFileName, "lyalya_welcome.m4a")
    }

    func test_presentOpenedLetter_mascotStateMatchesKind() async {
        let (sut, spy) = makeSUT()
        let letter = makeLetter(kind: .streak)
        await sut.presentOpenedLetter(response: .init(letter: letter))
        XCTAssertEqual(spy.lastOpenedVM?.mascotState, LetterKind.streak.mascotState)
    }

    // MARK: - presentDeleted

    func test_presentDeleted_passesRemovedId() async {
        let (sut, spy) = makeSUT()
        let id = UUID()
        await sut.presentDeleted(response: .init(removedId: id))
        XCTAssertEqual(spy.lastDeletedId, id)
    }
}

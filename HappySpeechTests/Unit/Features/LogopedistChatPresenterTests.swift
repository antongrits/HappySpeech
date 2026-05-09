@testable import HappySpeech
import XCTest

// MARK: - LogopedistChatPresenterTests
//
// Block V v18 — покрытие LogopedistChatPresenter (7 тестов).
// Тестируются все три метода presentationLogic через DisplaySpy.

@MainActor
final class LogopedistChatPresenterTests: XCTestCase {

    // MARK: - Display Spy

    @MainActor
    private final class DisplaySpy: LogopedistChatDisplayLogic {
        var loadVM: LogopedistChatModels.Load.ViewModel?
        var sendVM: LogopedistChatModels.Send.ViewModel?
        var attachAudioVM: LogopedistChatModels.AttachAudio.ViewModel?

        func displayLoad(viewModel: LogopedistChatModels.Load.ViewModel) async {
            loadVM = viewModel
        }
        func displaySend(viewModel: LogopedistChatModels.Send.ViewModel) async {
            sendVM = viewModel
        }
        func displayAttachAudio(viewModel: LogopedistChatModels.AttachAudio.ViewModel) async {
            attachAudioVM = viewModel
        }
    }

    private func makeSUT() -> (LogopedistChatPresenter, DisplaySpy) {
        let spy = DisplaySpy()
        let presenter = LogopedistChatPresenter(displayLogic: spy)
        return (presenter, spy)
    }

    private func makeMessage(
        id: String = UUID().uuidString,
        sender: MessageSender = .parent,
        text: String = "Добрый день",
        status: MessageStatus = .sent,
        attachment: MessageAttachment? = nil
    ) -> ChatMessage {
        ChatMessage(
            id: id,
            sender: sender,
            text: text,
            createdAt: Date(),
            status: status,
            attachment: attachment
        )
    }

    // MARK: - presentLoad

    func test_presentLoad_withSpecialist_setsSpecialistName() async {
        let (sut, spy) = makeSUT()
        let specialist = SpecialistInfo(
            displayName: "Иванова Мария",
            credentialsKey: "specialist.credentials.logopedist",
            isOnline: true,
            lastSeenAt: nil
        )
        let response = LogopedistChatModels.Load.Response(
            specialist: specialist,
            messages: [],
            isConnected: true
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.specialistName, "Иванова Мария")
        XCTAssertTrue(spy.loadVM?.isOnline ?? false)
    }

    func test_presentLoad_noSpecialist_setsComposerDisabled() async {
        let (sut, spy) = makeSUT()
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: [],
            isConnected: false
        )
        await sut.presentLoad(response: response)
        XCTAssertFalse(spy.loadVM?.composerEnabled ?? true)
    }

    func test_presentLoad_offline_setsConnectionHint() async {
        let (sut, spy) = makeSUT()
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: [],
            isConnected: false
        )
        await sut.presentLoad(response: response)
        XCTAssertNotNil(spy.loadVM?.connectionHint)
    }

    func test_presentLoad_withMessages_mapsAllRows() async {
        let (sut, spy) = makeSUT()
        let messages = [
            makeMessage(sender: .parent),
            makeMessage(sender: .specialist, text: "Здравствуйте!")
        ]
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: messages,
            isConnected: true
        )
        await sut.presentLoad(response: response)
        XCTAssertEqual(spy.loadVM?.messages.count, 2)
    }

    func test_presentLoad_parentMessage_isFromParentTrue() async {
        let (sut, spy) = makeSUT()
        let response = LogopedistChatModels.Load.Response(
            specialist: nil,
            messages: [makeMessage(sender: .parent)],
            isConnected: true
        )
        await sut.presentLoad(response: response)
        XCTAssertTrue(spy.loadVM?.messages.first?.isFromParent ?? false)
    }

    // MARK: - presentSend

    func test_presentSend_callsDisplaySend_withConfirmation() async {
        let (sut, spy) = makeSUT()
        let msg = makeMessage()
        let response = LogopedistChatModels.Send.Response(
            createdMessage: msg,
            appendedMessages: [msg]
        )
        await sut.presentSend(response: response)
        XCTAssertNotNil(spy.sendVM)
        XCTAssertTrue(spy.sendVM?.success ?? false)
        XCTAssertFalse(spy.sendVM?.confirmationMessage.isEmpty ?? true)
    }

    // MARK: - presentAttachAudio

    func test_presentAttachAudio_callsDisplayAttachAudio_withConfirmation() async {
        let (sut, spy) = makeSUT()
        let msg = makeMessage()
        let response = LogopedistChatModels.AttachAudio.Response(createdMessage: msg)
        await sut.presentAttachAudio(response: response)
        XCTAssertNotNil(spy.attachAudioVM)
        XCTAssertFalse(spy.attachAudioVM?.confirmationMessage.isEmpty ?? true)
    }
}

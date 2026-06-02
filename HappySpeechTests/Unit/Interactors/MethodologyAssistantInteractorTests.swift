@testable import HappySpeech
import XCTest

// MARK: - MethodologyAssistantInteractorTests
//
// MethodologyAssistantInteractor вызывает MethodologyAssistantClientProtocol и
// формирует ответы для презентера. Тесты используют MockMethodologyAssistantClient
// и spy-презентер. Проверяют: валидацию длины, успешный ответ, follow-up через
// sessionId, ошибку, reset.

@MainActor
final class MethodologyAssistantInteractorTests: XCTestCase {

    // MARK: - Spy presenter

    private final class PresenterSpy: MethodologyAssistantPresentationLogic {
        var loadingCalls: [MethodologyAssistant.Response.Loading] = []
        var answerCalls: [MethodologyAssistant.Response.Answered] = []
        var failureCalls: [MethodologyAssistant.Response.Failed] = []
        var clearedCalls = 0

        func presentLoading(_ response: MethodologyAssistant.Response.Loading) {
            loadingCalls.append(response)
        }
        func presentAnswer(_ response: MethodologyAssistant.Response.Answered) {
            answerCalls.append(response)
        }
        func presentFailure(_ response: MethodologyAssistant.Response.Failed) {
            failureCalls.append(response)
        }
        func presentCleared(_ response: MethodologyAssistant.Response.Cleared) {
            clearedCalls += 1
        }
    }

    // MARK: - Recording client (captures sessionId for follow-up assertions)

    private final class RecordingClient: MethodologyAssistantClientProtocol, @unchecked Sendable {
        let region = CloudFunctionsRegion.default
        var lastQuestion: String?
        var lastSessionId: String?
        var stubbedSessionId: String? = "sess-1"
        var shouldThrow = false

        func ask(question: String, sessionId: String?) async throws -> MethodologyAnswer {
            lastQuestion = question
            lastSessionId = sessionId
            if shouldThrow {
                throw CloudFunctionsClientError.serverError("boom")
            }
            return MethodologyAnswer(
                answer: "**Звук Р** ставится последним.",
                citations: [MethodologyCitation(title: "Этапы работы", source: "therapy-stages.md")],
                sessionId: stubbedSessionId
            )
        }
    }

    // MARK: - Helpers

    private func makeSUT(
        client: any MethodologyAssistantClientProtocol
    ) -> (MethodologyAssistantInteractor, PresenterSpy) {
        let interactor = MethodologyAssistantInteractor(client: client)
        let spy = PresenterSpy()
        interactor.presenter = spy
        return (interactor, spy)
    }

    /// Ждёт, пока spy получит хотя бы один answer или failure (in-flight Task).
    private func waitForResult(_ spy: PresenterSpy) async {
        for _ in 0..<100 where spy.answerCalls.isEmpty && spy.failureCalls.isEmpty {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    // MARK: - Tests

    func test_ask_tooShort_presentsFailureWithoutNetwork() async {
        let client = RecordingClient()
        let (sut, spy) = makeSUT(client: client)

        sut.ask(.init(question: "Р"))

        XCTAssertEqual(spy.failureCalls.count, 1)
        XCTAssertTrue(spy.loadingCalls.isEmpty)
        XCTAssertNil(client.lastQuestion, "Слишком короткий вопрос не должен уходить в сеть")
    }

    func test_ask_valid_presentsLoadingThenAnswer() async {
        let client = RecordingClient()
        let (sut, spy) = makeSUT(client: client)

        sut.ask(.init(question: "Как поставить звук Р?"))

        XCTAssertEqual(spy.loadingCalls.count, 1)
        XCTAssertEqual(spy.loadingCalls.first?.pendingQuestion, "Как поставить звук Р?")

        await waitForResult(spy)

        XCTAssertEqual(spy.answerCalls.count, 1)
        XCTAssertEqual(client.lastQuestion, "Как поставить звук Р?")
        XCTAssertNil(client.lastSessionId, "Первый вопрос — без sessionId")
        XCTAssertEqual(spy.answerCalls.first?.answer.citations.first?.source, "therapy-stages.md")
    }

    func test_followUp_reusesSessionId() async {
        let client = RecordingClient()
        let (sut, spy) = makeSUT(client: client)

        sut.ask(.init(question: "Как поставить звук Р?"))
        await waitForResult(spy)

        // Второй вопрос должен переиспользовать sessionId из первого ответа.
        sut.ask(.init(question: "А какие упражнения помогут?"))
        for _ in 0..<100 where spy.answerCalls.count < 2 {
            try? await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertEqual(spy.answerCalls.count, 2)
        XCTAssertEqual(client.lastSessionId, "sess-1", "Follow-up должен передавать сохранённый sessionId")
    }

    func test_ask_serverError_presentsFailure() async {
        let client = RecordingClient()
        client.shouldThrow = true
        let (sut, spy) = makeSUT(client: client)

        sut.ask(.init(question: "Как поставить звук Р?"))
        await waitForResult(spy)

        XCTAssertEqual(spy.failureCalls.count, 1)
        XCTAssertTrue(spy.answerCalls.isEmpty)
        XCTAssertFalse(spy.failureCalls.first?.message.isEmpty ?? true)
    }

    func test_reset_clearsSessionAndPresentsCleared() async {
        let client = RecordingClient()
        let (sut, spy) = makeSUT(client: client)

        sut.ask(.init(question: "Как поставить звук Р?"))
        await waitForResult(spy)

        sut.reset(.init())
        XCTAssertEqual(spy.clearedCalls, 1)

        // После reset следующий вопрос снова идёт без sessionId.
        sut.ask(.init(question: "Новый вопрос про звуки"))
        for _ in 0..<100 where spy.answerCalls.count < 2 {
            try? await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNil(client.lastSessionId, "После reset sessionId должен быть сброшен")
    }

    func test_mockClient_returnsStubbedAnswer() async throws {
        let mock = MockMethodologyAssistantClient()
        let answer = try await mock.ask(question: "Как поставить звук Р?")
        XCTAssertFalse(answer.answer.isEmpty)
        XCTAssertFalse(answer.citations.isEmpty)
        XCTAssertEqual(answer.sessionId, "mock-session-0001")
    }
}

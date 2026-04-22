import Foundation
import OSLog

// MARK: - MemoryBusinessLogic

@MainActor
protocol MemoryBusinessLogic: AnyObject {
    func loadSession(_ request: MemoryModels.LoadSession.Request)
    func submitAttempt(_ request: MemoryModels.SubmitAttempt.Request)
}

// MARK: - MemoryInteractor

@MainActor
final class MemoryInteractor: MemoryBusinessLogic {

    var presenter: (any MemoryPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Memory")

    // MARK: - loadSession
    func loadSession(_ request: MemoryModels.LoadSession.Request) {
        let response = MemoryModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: MemoryModels.SubmitAttempt.Request) {
        let response = MemoryModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}

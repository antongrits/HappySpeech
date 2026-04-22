import Foundation
import OSLog

// MARK: - BingoBusinessLogic

@MainActor
protocol BingoBusinessLogic: AnyObject {
    func loadSession(_ request: BingoModels.LoadSession.Request)
    func submitAttempt(_ request: BingoModels.SubmitAttempt.Request)
}

// MARK: - BingoInteractor

@MainActor
final class BingoInteractor: BingoBusinessLogic {

    var presenter: (any BingoPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Bingo")

    // MARK: - loadSession
    func loadSession(_ request: BingoModels.LoadSession.Request) {
        let response = BingoModels.LoadSession.Response()
        presenter?.presentLoadSession(response)
    }

    // MARK: - submitAttempt
    func submitAttempt(_ request: BingoModels.SubmitAttempt.Request) {
        let response = BingoModels.SubmitAttempt.Response()
        presenter?.presentSubmitAttempt(response)
    }
}

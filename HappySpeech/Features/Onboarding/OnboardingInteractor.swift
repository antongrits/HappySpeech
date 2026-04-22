import Foundation
import OSLog

// MARK: - OnboardingBusinessLogic

@MainActor
protocol OnboardingBusinessLogic: AnyObject {
    func fetch(_ request: OnboardingModels.Fetch.Request)
    func update(_ request: OnboardingModels.Update.Request)
}

// MARK: - OnboardingInteractor

@MainActor
final class OnboardingInteractor: OnboardingBusinessLogic {

    var presenter: (any OnboardingPresentationLogic)?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "Onboarding")

    // MARK: - fetch
    func fetch(_ request: OnboardingModels.Fetch.Request) {
        let response = OnboardingModels.Fetch.Response()
        presenter?.presentFetch(response)
    }

    // MARK: - update
    func update(_ request: OnboardingModels.Update.Request) {
        let response = OnboardingModels.Update.Response()
        presenter?.presentUpdate(response)
    }
}

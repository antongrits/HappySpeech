import SwiftUI

// MARK: - OnboardingRoutingLogic

@MainActor
protocol OnboardingRoutingLogic {
    func routeCompleted(profile: OnboardingProfile)
}

// MARK: - OnboardingRouter
//
// View задаёт один колбэк — `onCompleted`. Внешний код (App / координатор)
// решает, куда вести: parent home / role select / child home.

@MainActor
final class OnboardingRouter: OnboardingRoutingLogic {

    var onCompleted: ((OnboardingProfile) -> Void)?

    func routeCompleted(profile: OnboardingProfile) {
        onCompleted?(profile)
    }
}

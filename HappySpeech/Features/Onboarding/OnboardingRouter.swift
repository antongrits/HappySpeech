import SwiftUI

// MARK: - OnboardingRoutingLogic

@MainActor
protocol OnboardingRoutingLogic {
    func routeCompleted(profile: OnboardingProfile)
    func routeToChildHome(childId: String)
    func routeToParentHome()
    func routeToSpecialistHome()
}

// MARK: - OnboardingRouter
//
// Router принимает либо внешний `onCompleted` колбэк (View передаёт его
// при init), либо роутится напрямую через AppCoordinator. По умолчанию
// сценарий: View передаёт closure → OnboardingFlowView интерпретирует роль
// → coordinator.navigate(...). Router здесь нужен для VIP-чистоты:
// Interactor → Presenter → Display → View → Router.

@MainActor
final class OnboardingRouter: OnboardingRoutingLogic {

    // MARK: - Inputs

    var onCompleted: ((OnboardingProfile) -> Void)?
    weak var coordinator: AppCoordinator?

    /// Резолвит реальный профиль активного ребёнка и навигирует в его главную
    /// (или в родительский контур создания, если детей ещё нет). Внедряет View,
    /// владеющая `AppContainer.childRepository`: Router не импортирует Data-слой
    /// напрямую — резолюция отдана View по правилам слоёв.
    var resolveChildHome: (@MainActor () -> Void)?

    // MARK: - Routing

    func routeCompleted(profile: OnboardingProfile) {
        if let onCompleted {
            onCompleted(profile)
            return
        }
        // Default behaviour: использовать AppCoordinator для перехода
        // в нужный home-экран по роли.
        switch profile.role {
        case .child:
            // Онбординг НЕ создаёт ChildProfile в Realm (только OnboardingState +
            // AdaptivePlanner-seed), поэтому литеральный `"primary-child"` указывал
            // на несуществующий профиль → пустая детская главная + сессии-сироты.
            // Резолвим РЕАЛЬНЫЙ id (как RoleSelect): сохранённый/первый профиль,
            // иначе — родительский контур создания. Резолвер внедряет View.
            if let resolveChildHome {
                resolveChildHome()
            } else {
                routeToParentHome()
            }
        case .specialist:
            routeToSpecialistHome()
        case .parent:
            routeToParentHome()
        }
    }

    func routeToChildHome(childId: String) {
        coordinator?.navigate(to: .childHome(childId: childId))
    }

    func routeToParentHome() {
        coordinator?.navigate(to: .parentHome)
    }

    func routeToSpecialistHome() {
        coordinator?.navigate(to: .specialistHome)
    }
}

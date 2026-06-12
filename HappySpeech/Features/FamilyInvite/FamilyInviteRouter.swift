import SwiftUI

// MARK: - FamilyInviteRouter
//
// Поверхности приглашения показываются как sheet'ы из родительского контура,
// поэтому навигация ограничена: закрыть sheet и (для не-аутентифицированного
// приглашённого) увести на экран входа.

@MainActor
final class FamilyInviteRouter {

    private weak var coordinator: AppCoordinator?

    init(coordinator: AppCoordinator) {
        self.coordinator = coordinator
    }

    /// Переход на экран входа из «У меня есть код», если пользователь не вошёл.
    func routeToSignIn() {
        coordinator?.navigate(to: .auth)
    }
}

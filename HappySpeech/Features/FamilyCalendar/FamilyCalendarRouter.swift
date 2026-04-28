import Foundation
import SwiftUI

// MARK: - FamilyCalendarRouter
//
// Навигация из экрана семейного календаря.
// В текущем scope F3: только push на deep-link создания ребёнка.

@MainActor
final class FamilyCalendarRouter {

    weak var coordinator: AppCoordinator?

    func routeToAddChild() {
        coordinator?.navigate(to: .onboarding)
    }
}

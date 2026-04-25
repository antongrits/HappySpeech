import Foundation

// MARK: - ScreeningRouter

/// Navigation glue for Screening. В приложении скрининг показывается как
/// модальный sheet поверх ParentHome (или как шаг онбординга). После завершения
/// router эмитирует:
///   • `onComplete(outcome)` — для тех вызывающих, кто хочет получить outcome
///     (например, чтобы передать его дальше в onboarding-флоу);
///   • `onRouteToParentHome` — целевая навигация в ParentHome через
///     `AppCoordinator.navigate(to: .parentHome)`. Вызывается интерактором
///     после успешного persist'а в Realm.
///   • `onCancel` — пользователь прервал скрининг.
@MainActor
final class ScreeningRouter {

    /// Fired when the screening completes successfully. The caller is expected
    /// to persist `ScreeningOutcome` to the child profile and dismiss the
    /// screening sheet.
    var onComplete: ((ScreeningOutcome) -> Void)?
    /// Fired after `ScreeningOutcomeObject` has been persisted to Realm —
    /// navigation should switch root to ParentHome.
    var onRouteToParentHome: (() -> Void)?
    /// Fired when the user aborts mid-screening.
    var onCancel: (() -> Void)?

    func complete(outcome: ScreeningOutcome) {
        onComplete?(outcome)
    }

    /// Triggered by the interactor after Realm write succeeds.
    func routeToParentHome() {
        onRouteToParentHome?()
    }

    func cancel() {
        onCancel?()
    }
}

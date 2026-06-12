import SwiftUI

// MARK: - PhonemeReportRouter

/// Сборка VIP-цикла экрана «Детальный пофонемный отчёт» (A-09).
/// Возвращает готовый интерактор с подключённым презентером и display-слоем.
@MainActor
enum PhonemeReportRouter {

    /// Собирает VIP-граф из реальных репозиториев контейнера.
    static func makeInteractor(
        container: AppContainer,
        display: any PhonemeReportDisplayLogic
    ) -> PhonemeReportInteractor {
        let presenter = PhonemeReportPresenter()
        presenter.display = display
        let interactor = PhonemeReportInteractor(
            sessionRepository: container.sessionRepository,
            childRepository: container.childRepository,
            phonemeProfileService: container.phonemeProfileService
        )
        interactor.presenter = presenter
        return interactor
    }
}

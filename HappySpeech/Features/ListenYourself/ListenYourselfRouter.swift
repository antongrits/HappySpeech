import Foundation

// MARK: - ListenYourselfRoutingLogic

@MainActor
protocol ListenYourselfRoutingLogic: AnyObject {
    /// Завершение игры — возврат на детскую главную через координатор.
    func routeToExit()
}

// MARK: - ListenYourselfRouter
//
// Навигация модуля «Послушай себя». Игра самодостаточна (2 внутренних экрана —
// «Два дубля» и «Сравни с Лялей» — переключаются внутри View по фазе), наружу
// ведёт только выход на детскую главную через инжектированное `exitGame`.

@MainActor
final class ListenYourselfRouter: ListenYourselfRoutingLogic {

    /// Действие выхода из детской мини-игры (внедряется View из `\.exitGame`).
    private let exitAction: () -> Void

    init(exitAction: @escaping () -> Void) {
        self.exitAction = exitAction
    }

    func routeToExit() {
        exitAction()
    }
}

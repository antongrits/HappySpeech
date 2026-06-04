import SwiftUI

// MARK: - CircuitExitAction
//
// Parent- и specialist-экраны запускаются из своих home-роутеров через
// `AppCoordinator.navigate(to:)`, который ЗАМЕНЯЕТ корневой маршрут
// (`currentRoute`), а не push'ит экран в `NavigationStack`. Поэтому штатный
// `@Environment(\.dismiss)` на корневом крестике такого экрана — no-op
// (нечего «сдвигать» со стека), и кнопка «Закрыть» оставляла пользователя
// в тупике (PROD-BUG: parent/specialist dead-end, аналог детского `exitGame`).
//
// `CircuitExitAction` — единая точка возврата на ПРАВИЛЬНЫЙ home взрослого
// контура: координатор внедряет её в окружение, и она восстанавливает
// корневой маршрут родительской / специалистской главной. Экраны вызывают
// `exitToParentHome()` / `exitToSpecialistHome()` вместо `dismiss()` на
// корневом крестике. Дефолтное значение (no-op) сохраняет работоспособность
// Preview'ев и тестов без координатора.
//
// ВАЖНО: использовать ТОЛЬКО на корневом крестике экрана-маршрута. Вложенные
// `dismiss()` внутри `.sheet { }` / `.fullScreenCover { }` остаются как есть —
// там dismiss легитимен (закрывает презентованный контент, а не маршрут).

struct CircuitExitAction {
    private let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    @MainActor
    func callAsFunction() {
        action()
    }
}

private struct ExitToParentHomeKey: EnvironmentKey {
    static let defaultValue = CircuitExitAction { }
}

private struct ExitToSpecialistHomeKey: EnvironmentKey {
    static let defaultValue = CircuitExitAction { }
}

extension EnvironmentValues {
    /// Возврат из полноэкранного parent-маршрута на корневой `parentHome`.
    /// Координатор внедряет реальное действие; по умолчанию — no-op.
    var exitToParentHome: CircuitExitAction {
        get { self[ExitToParentHomeKey.self] }
        set { self[ExitToParentHomeKey.self] = newValue }
    }

    /// Возврат из полноэкранного specialist-маршрута на корневой `specialistHome`.
    /// Координатор внедряет реальное действие; по умолчанию — no-op.
    var exitToSpecialistHome: CircuitExitAction {
        get { self[ExitToSpecialistHomeKey.self] }
        set { self[ExitToSpecialistHomeKey.self] = newValue }
    }
}

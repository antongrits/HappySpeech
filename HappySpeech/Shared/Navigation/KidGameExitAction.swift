import SwiftUI

// MARK: - KidGameExitAction
//
// Детские мини-игры запускаются из `ChildHomeRouter` через
// `AppCoordinator.navigate(to:)`, который ЗАМЕНЯЕТ корневой маршрут
// (`currentRoute`), а не push'ит экран в `NavigationStack`. Поэтому штатный
// `@Environment(\.dismiss)` внутри такой игры — no-op (нечего «сдвигать» со
// стека), и кнопки «Готово»/«Закрыть» оставляли пользователя в тупике.
//
// `KidGameExitAction` — единая точка выхода: координатор внедряет её в
// окружение для game-маршрутов, и она восстанавливает корневой маршрут детской
// главной. Игры вызывают `exitGame()` вместо `dismiss()` на путях завершения и
// закрытия. Дефолтное значение (no-op) сохраняет работоспособность Preview'ев и
// тестов без координатора.

struct KidGameExitAction {
    private let action: @MainActor () -> Void

    init(_ action: @escaping @MainActor () -> Void) {
        self.action = action
    }

    @MainActor
    func callAsFunction() {
        action()
    }
}

private struct KidGameExitActionKey: EnvironmentKey {
    static let defaultValue = KidGameExitAction { }
}

extension EnvironmentValues {
    /// Возврат из детской мини-игры на корневой маршрут детской главной.
    /// Координатор внедряет реальное действие; по умолчанию — no-op.
    var exitGame: KidGameExitAction {
        get { self[KidGameExitActionKey.self] }
        set { self[KidGameExitActionKey.self] = newValue }
    }
}

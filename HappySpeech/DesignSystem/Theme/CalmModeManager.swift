import Observation
import SwiftUI

// MARK: - CalmModeManager
//
// A-08 «Спокойный режим» — опциональный сенсорно-сниженный UI для детей,
// чувствительных к ярким анимациям, частицам и резким вспышкам цвета.
//
// Это НЕ медицинский/диагностический инструмент. Режим лишь снижает визуальную
// и звуковую стимуляцию детского контура. Флаг по умолчанию ВЫКЛЮЧЕН — при
// выключенном режиме поведение приложения не меняется нигде.
//
// Хранение — `UserDefaults` (по образцу `ThemeManager`). Инжектится как
// `@Observable`-объект в корне дерева; производное Bool-значение пробрасывается
// в `\.calmMode`, чтобы DesignSystem-компоненты могли реагировать реактивно,
// не импортируя AppContainer.

/// Наблюдаемый менеджер «Спокойного режима». Источник истины для флага
/// `calmModeEnabled`; персистится в `UserDefaults`.
@Observable
@MainActor
public final class CalmModeManager {

    /// Ключ персиста. Совпадает с `SettingsKey.calmModeEnabled`, чтобы Settings-VIP
    /// и менеджер читали/писали одно и то же значение.
    private static let key = "hs.settings.calmModeEnabled"

    private let defaults: UserDefaults

    /// Включён ли «Спокойный режим». По умолчанию `false` (ноль регрессий).
    public var isEnabled: Bool {
        didSet {
            guard oldValue != isEnabled else { return }
            defaults.set(isEnabled, forKey: Self.key)
        }
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Отсутствие ключа → false (default OFF). Явный false тоже даёт false.
        self.isEnabled = defaults.bool(forKey: Self.key)
    }
}

// MARK: - CalmMode Environment Key

private struct CalmModeKey: EnvironmentKey {
    /// Default OFF: при отсутствии явной инъекции режим выключен.
    static let defaultValue: Bool = false
}

public extension EnvironmentValues {

    /// Включён ли «Спокойный режим». Пробрасывается из корня дерева на основе
    /// `CalmModeManager.isEnabled`. Компоненты читают через `@Environment(\.calmMode)`.
    ///
    /// Все ветки, меняющие поведение, должны находиться строго под `if calmMode`,
    /// чтобы при выключенном режиме (значение по умолчанию) рендер оставался
    /// идентичным существующему.
    var calmMode: Bool {
        get { self[CalmModeKey.self] }
        set { self[CalmModeKey.self] = newValue }
    }
}

import SwiftUI
import UIKit

// MARK: - HapticServiceKey
//
// Environment key для HapticService.
// Позволяет DesignSystem-компонентам (LyalyaMascotView и др.)
// получать haptic feedback через DI, не импортируя AppContainer.
//
// Паттерн: AppContainer устанавливает значение через .environment(\.hapticService, ...)
// в корне View-дерева. Fallback — FallbackHapticService (UIKit generators).

private struct HapticServiceKey: EnvironmentKey {
    static let defaultValue: any HapticService = FallbackHapticService()
}

// MARK: - EnvironmentValues extension

public extension EnvironmentValues {

    /// Сервис тактильной обратной связи. Устанавливается из AppContainer.
    /// В DesignSystem-компонентах читается через `@Environment(\.hapticService)`.
    var hapticService: any HapticService {
        get { self[HapticServiceKey.self] }
        set { self[HapticServiceKey.self] = newValue }
    }
}

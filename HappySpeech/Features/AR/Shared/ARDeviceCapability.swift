import ARKit
import Foundation

// MARK: - ARDeviceCapability

/// Единая точка проверки готовности устройства к AR face-tracking игре —
/// и честного решения, можно ли запускать упражнение.
///
/// Проблема, которую решает (P1-1): на устройствах без TrueDepth-камеры
/// (`ARFaceTrackingConfiguration.isSupported == false` — например, все iPhone SE)
/// AR-игры раньше запускали `MockARSessionService`, который эмитит
/// СИНТЕТИЧЕСКИЕ blendshapes (sin/cos). Интерактор скорил эти фейк-кадры как
/// реальную мимику ребёнка, и упражнение «проходилось» само, без участия лица.
///
/// Решение: на реальном устройстве без TrueDepth игра НЕ запускается и НЕ
/// скорит синтетику — показывается честный `ARUnsupportedView`. Симулированная
/// AR-сессия (`MockARSessionService`) допускается ТОЛЬКО в SwiftUI-превью и
/// под XCTest-раннером, где она нужна для детерминированной верификации
/// VIP-логики без TrueDepth-железа и никогда не попадает к ребёнку.
enum ARDeviceCapability {

    /// Устройство физически поддерживает face-tracking (есть TrueDepth-камера).
    static var supportsFaceTracking: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    /// Можно ли запускать СИМУЛИРОВАННУЮ AR-сессию (`MockARSessionService`).
    ///
    /// Только в превью/тестах — никогда в production-рантайме на устройстве.
    /// Реальные дети без TrueDepth получают честный `ARUnsupportedView`, а не
    /// синтетический «успех».
    static var allowsSimulatedSession: Bool {
        #if targetEnvironment(simulator)
        // На симуляторе TrueDepth недоступен по определению. Разрешаем симуляцию
        // только если это превью или тест-раннер; обычный запуск приложения на
        // симуляторе тоже показывает честный unsupported-экран.
        return isPreview || ProcessInfo.processInfo.isRunningUnitTests
        #else
        // На реальном железе симуляция запрещена всегда: либо есть TrueDepth и
        // работает Live-сессия, либо честный unsupported-экран.
        return false
        #endif
    }

    /// Запущено ли в контексте SwiftUI-превью Xcode.
    private static var isPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

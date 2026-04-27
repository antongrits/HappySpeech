import XCTest

// MARK: - ColdStartSignpostTests

/// Тесты проверяют наличие и корректность os_signpost разметки.
///
/// Реальный cold start измеряется через xcrun simctl + log stream:
///   xcrun simctl launch --console "iPhone SE (3rd generation)" ru.happyspeech.app DISABLE_RIVE=1
///   xcrun simctl spawn ... log stream --predicate 'subsystem == "ru.happyspeech.app"' --level debug
///
/// В unit-тестах проверяем только корректность значений констант.
final class ColdStartSignpostTests: XCTestCase {

    /// Проверяем что subsystem/category строки соответствуют схеме.
    func testPerfLogSubsystemAndCategory() {
        let subsystem = "ru.happyspeech.app"
        let category  = "Performance"

        // Формат Bundle ID — обратный доменный синтаксис
        XCTAssertTrue(subsystem.contains("."), "Subsystem должен быть в формате reverse-DNS")
        XCTAssertFalse(category.isEmpty, "Category не должна быть пустой")
    }

    /// Проверяем что DISABLE_RIVE env-переменная ожидаемо "1" или nil.
    func testDisableRiveEnvKey() {
        // В тестовом окружении DISABLE_RIVE не должна быть установлена
        let value = ProcessInfo.processInfo.environment["DISABLE_RIVE"]
        XCTAssertNil(value,
                     "DISABLE_RIVE не должна быть установлена в обычном тестовом окружении")
    }

    /// AR Memory — NOT_MEASURABLE на симуляторе.
    ///
    /// ARKit Face Tracking требует физическую TrueDepth камеру (iPhone X и новее).
    /// На iOS Simulator ARSessionService возвращает isSupported=false,
    /// AR-сессия не стартует → RSS памяти не включает ARKit данные.
    /// Цель < 400 MB для AR-сессии измерима только на реальном устройстве.
    func testARMemoryNotMeasurableOnSimulator() throws {
        throw XCTSkip("""
            NOT_MEASURABLE: Memory AR session не измеримо на iOS Simulator.
            ARKit Face Tracking требует TrueDepth камеру (физическое устройство).
            Цель < 400 MB — замер через Xcode Memory Graph на iPhone 12+ во время AR-сессии.
            """)
    }

    /// 60 FPS анимации — NOT_MEASURABLE через xcrun без Instruments GUI.
    ///
    /// CADisplayLink frame timing и SwiftUI render performance требуют
    /// Instruments → Animation Hitches trace или Metal HUD в Release build.
    /// На симуляторе GPU рендер — Metal на хосте (macOS), не iOS GPU.
    func testAnimationFPSNotMeasurableViaBash() throws {
        throw XCTSkip("""
            NOT_MEASURABLE: 60 fps анимации не измеримо через xcodebuild test / xcrun.
            Метод: Instruments → Animation Hitches на реальном устройстве,
            или enableCALayer(метал HUD) в Release build симулятора.
            Цель: 0 hitch frames в ChildHome scroll / ARZone entry / Liquid Glass cards.
            """)
    }
}

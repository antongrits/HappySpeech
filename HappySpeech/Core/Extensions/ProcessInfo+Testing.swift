import Foundation

public extension ProcessInfo {

    /// `true`, когда процесс запущен под XCTest-раннером.
    ///
    /// Используется для отключения тяжёлых side-эффектов (RealityKit `ARView`-рендер,
    /// Spotlight-индексация и т.п.) при выполнении unit-тестов: тестовый хост
    /// загружает бинарь приложения целиком, и нестабильный в симуляторе CoreRE
    /// рендер 3D-маскота приводит к падению test runner-а до установки соединения.
    var isRunningUnitTests: Bool {
        environment.keys.contains("XCTestConfigurationFilePath")
    }
}

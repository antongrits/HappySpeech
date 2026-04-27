import Foundation
import XCTest

// MARK: - SnapshotTestHelper
//
// Общий хелпер для всех snapshot тестов.
//
// Путь к референсам определяется следующим образом (в порядке приоритета):
//  1. Переменная среды SNAPSHOT_REFERENCES_PATH (для CI и второго прогона)
//  2. Bundle(for: ...).bundleURL.deletingLastPathComponent() (для первого прогона на симуляторе)
//
// Чтобы второй прогон находил референсы из первого, задай:
//   SNAPSHOT_REFERENCES_PATH = <путь к HappySpeechTests/__Snapshots__>
//
// В xcodebuild это передаётся через -testenv:
//   xcodebuild test ... SNAPSHOT_REFERENCES_PATH=/path/to/HappySpeechTests/__Snapshots__

enum SnapshotTestHelper {

    /// Базовая директория для хранения всех snapshot-референсов.
    static func baseDir(for testClass: AnyClass) -> URL {
        if let envPath = ProcessInfo.processInfo.environment["SNAPSHOT_REFERENCES_PATH"] {
            return URL(fileURLWithPath: envPath, isDirectory: true)
        }
        return Bundle(for: testClass).bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__")
    }

    /// Возвращает URL для конкретного PNG снапшота.
    /// - Parameters:
    ///   - testClass: класс теста (для Bundle lookup)
    ///   - category: категория (AR, KeyScreens, DynamicType, ...)
    ///   - screen: имя экрана или состояния
    ///   - device: имя устройства
    ///   - appearance: Light или Dark
    static func snapshotURL(
        testClass: AnyClass,
        category: String,
        screen: String,
        device: String,
        appearance: String
    ) -> URL {
        let dir = baseDir(for: testClass)
            .appendingPathComponent(category)
            .appendingPathComponent(screen)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(device)_\(appearance).png")
    }

    /// Вариант без device (только screen + appearance), например для HSMascotView.
    static func snapshotURL(
        testClass: AnyClass,
        category: String,
        name: String,
        appearance: String
    ) -> URL {
        let dir = baseDir(for: testClass)
            .appendingPathComponent(category)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name)_\(appearance).png")
    }
}

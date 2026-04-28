import Foundation
import XCTest

// MARK: - SnapshotTestHelper
//
// Общий хелпер для всех snapshot тестов.
//
// Путь к референсам определяется следующим образом (в порядке приоритета):
//  1. Переменная среды SNAPSHOT_REFERENCES_PATH (для CI)
//  2. Путь относительно SnapshotTestHelper.swift через #file (стандартный паттерн)
//
// __Snapshots__ всегда находится на уровне HappySpeechTests/,
// то есть рядом с папкой Snapshot/ где лежит этот хелпер.
//
// Структура:
//  HappySpeechTests/
//    Snapshot/
//      SnapshotTestHelper.swift  ← #file даёт нам этот путь
//    __Snapshots__/
//      AR/...
//      KeyScreens/...
//      ...

enum SnapshotTestHelper {

    /// Файл, из которого вычисляется путь к __Snapshots__.
    /// #file здесь — compile-time путь к SnapshotTestHelper.swift.
    private static let helperFileURL = URL(
        fileURLWithPath: #filePath,   // абсолютный путь к этому .swift файлу
        isDirectory: false
    )

    /// Базовая директория: HappySpeechTests/__Snapshots__
    static var snapshotsBaseDir: URL {
        if let envPath = ProcessInfo.processInfo.environment["SNAPSHOT_REFERENCES_PATH"] {
            return URL(fileURLWithPath: envPath, isDirectory: true)
        }
        // SnapshotTestHelper.swift лежит в HappySpeechTests/Snapshot/
        // .deletingLastPathComponent() × 2 → HappySpeechTests/
        return helperFileURL
            .deletingLastPathComponent()   // → .../Snapshot/
            .deletingLastPathComponent()   // → .../HappySpeechTests/
            .appendingPathComponent("__Snapshots__")
    }

    /// Возвращает URL для конкретного PNG снапшота.
    static func snapshotURL(
        testClass: AnyClass,
        category: String,
        screen: String,
        device: String,
        appearance: String
    ) -> URL {
        let dir = snapshotsBaseDir
            .appendingPathComponent(category)
            .appendingPathComponent(screen)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(device)_\(appearance).png")
    }

    /// Вариант без device (только name + appearance), например для HSMascotView.
    static func snapshotURL(
        testClass: AnyClass,
        category: String,
        name: String,
        appearance: String
    ) -> URL {
        let dir = snapshotsBaseDir
            .appendingPathComponent(category)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(name)_\(appearance).png")
    }
}

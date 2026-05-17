import Foundation
import UIKit
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
//
// Сравнение: попиксельное через CGImage / rawData.
// maxDiffRatio = 0.05 (5% пикселей могут отличаться — industry standard).

enum SnapshotTestHelper {

    // MARK: - Path resolution

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

    // MARK: - Async settling

    /// Прокручивает главный run loop, давая SwiftUI выполнить отложенные `.task`/`.onAppear`
    /// замыкания перед снятием снапшота.
    ///
    /// Экраны с VIP-bootstrap (`PermissionFlowView` и др.) инициализируют состояние
    /// внутри `.task { await bootstrap() }`. Без прокрутки run loop снапшот ловит
    /// промежуточный кадр (`ProgressView`), что делает тест flaky. Несколько коротких
    /// итераций run loop гарантируют, что синхронная часть `.task` отработала.
    static func settleMainRunLoop(iterations: Int = 12, interval: TimeInterval = 0.02) {
        for _ in 0 ..< iterations {
            RunLoop.main.run(until: Date().addingTimeInterval(interval))
        }
    }

    // MARK: - Pixel comparison

    /// Максимальный допустимый процент отличающихся пикселей (5%).
    static let defaultMaxDiffRatio: Double = 0.05

    /// Сравнивает два UIImage попиксельно.
    /// Возвращает долю отличающихся пикселей [0.0 ... 1.0].
    /// Если изображения разного размера — возвращает 1.0 (полное несоответствие).
    static func pixelDiffRatio(_ lhs: UIImage, _ rhs: UIImage) -> Double {
        guard
            let lhsCG = lhs.cgImage,
            let rhsCG = rhs.cgImage,
            lhsCG.width == rhsCG.width,
            lhsCG.height == rhsCG.height
        else { return 1.0 }

        let width  = lhsCG.width
        let height = lhsCG.height
        let totalPixels = width * height
        guard totalPixels > 0 else { return 0.0 }

        let bytesPerPixel = 4
        let bytesPerRow   = width * bytesPerPixel
        let bufferSize    = bytesPerRow * height

        var lhsBuf = [UInt8](repeating: 0, count: bufferSize)
        var rhsBuf = [UInt8](repeating: 0, count: bufferSize)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard
            let lhsCtx = CGContext(
                data: &lhsBuf, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: colorSpace, bitmapInfo: bitmapInfo.rawValue
            ),
            let rhsCtx = CGContext(
                data: &rhsBuf, width: width, height: height,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: colorSpace, bitmapInfo: bitmapInfo.rawValue
            )
        else { return 1.0 }

        lhsCtx.draw(lhsCG, in: CGRect(x: 0, y: 0, width: width, height: height))
        rhsCtx.draw(rhsCG, in: CGRect(x: 0, y: 0, width: width, height: height))

        var diffPixels = 0
        let tolerance: UInt8 = 3   // субпиксельный шум на симуляторе (±3/255)
        for pixelIdx in 0 ..< totalPixels {
            let base = pixelIdx * bytesPerPixel
            let rDiff = lhsBuf[base    ] > rhsBuf[base    ] ? lhsBuf[base    ] - rhsBuf[base    ] : rhsBuf[base    ] - lhsBuf[base    ]
            let gDiff = lhsBuf[base + 1] > rhsBuf[base + 1] ? lhsBuf[base + 1] - rhsBuf[base + 1] : rhsBuf[base + 1] - lhsBuf[base + 1]
            let bDiff = lhsBuf[base + 2] > rhsBuf[base + 2] ? lhsBuf[base + 2] - rhsBuf[base + 2] : rhsBuf[base + 2] - lhsBuf[base + 2]
            if rDiff > tolerance || gDiff > tolerance || bDiff > tolerance {
                diffPixels += 1
            }
        }

        return Double(diffPixels) / Double(totalPixels)
    }

    // MARK: - Assert helper

    /// Сохраняет PNG-референс при первом запуске; при повторных — делает попиксельное сравнение.
    /// Завершает тест через `XCTFail` если:
    ///   — PNG не удалось закодировать;
    ///   — при первом запуске (записан новый референс);
    ///   — процент отличающихся пикселей > maxDiffRatio.
    static func assertPixelMatch(
        _ image: UIImage,
        referenceURL: URL,
        maxDiffRatio: Double = defaultMaxDiffRatio,
        label: String,
        file: StaticString = #file,
        line: UInt = #line
    ) throws {
        guard let pngData = image.pngData() else {
            XCTFail("PNG encoding failed: \(label)", file: file, line: line)
            return
        }

        guard FileManager.default.fileExists(atPath: referenceURL.path) else {
            // Первый запуск — записываем референс
            try pngData.write(to: referenceURL)
            XCTFail(
                "Записан новый референс '\(referenceURL.lastPathComponent)' для \(label). "
              + "Перезапусти тест для сравнения.",
                file: file, line: line
            )
            return
        }

        // Загружаем существующий референс
        guard
            let refData  = try? Data(contentsOf: referenceURL),
            let refImage = UIImage(data: refData)
        else {
            XCTFail("Не удалось загрузить референс: \(referenceURL.path)", file: file, line: line)
            return
        }

        let diffRatio = pixelDiffRatio(image, refImage)
        XCTAssertLessThanOrEqual(
            diffRatio, maxDiffRatio,
            String(format: "Snapshot изменился (%@): %.2f%% пикселей отличаются (допуск %.0f%%)",
                   label, diffRatio * 100, maxDiffRatio * 100),
            file: file, line: line
        )
    }
}

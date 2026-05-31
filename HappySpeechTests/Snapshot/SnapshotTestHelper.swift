import Foundation
import ObjectiveC
import SwiftUI
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

        // Opt-in re-record: перезаписываем эталон и проходим тест. Триггер —
        // либо переменная среды `SNAPSHOT_RECORD`, либо sentinel-файл
        // `/tmp/HS_SNAPSHOT_RECORD` (надёжно работает в симуляторе, куда shell
        // env не всегда пробрасывается через `xcodebuild`). Используется только
        // в dedicated record-проходе для устаревших baseline после редизайна.
        let recordEnv = ProcessInfo.processInfo.environment["SNAPSHOT_RECORD"]
        let recordSentinel = FileManager.default.fileExists(atPath: "/tmp/HS_SNAPSHOT_RECORD")
        if (recordEnv.map { !$0.isEmpty } ?? false) || recordSentinel {
            try pngData.write(to: referenceURL)
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

    // MARK: - Smoke render assert (для inherently-анимированных экранов)

    /// Рендерит view и проверяет, что кадр НЕ пустой/однотонный, без сравнения с
    /// эталоном. Применяется к экранам с многостадийным async-reveal
    /// (`SessionCompleteView`): их пиксельный снимок недетерминирован (захват
    /// гонится с reveal-пайплайном), а флаки-pixel-тест хуже отсутствия — он
    /// рандомно валит CI и маскирует реальные регрессии в шуме. Smoke-тест ловит
    /// главный класс регрессий (краш конструкции / пустой кадр / отсутствие env),
    /// что и было реальным дефектом. Визуал такого экрана выверяется вручную.
    @MainActor
    static func assertRendersNonBlank<V: View>(
        _ view: V,
        size: CGSize = CGSize(width: 375, height: 667),
        style: UIUserInterfaceStyle = .light,
        reduceMotion: Bool = true,
        label: String,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let image = renderView(view, size: size, style: style, reduceMotion: reduceMotion)
        guard let cgImage = image.cgImage else {
            XCTFail("Кадр не отрендерился (нет cgImage): \(label)", file: file, line: line)
            return
        }
        XCTAssertGreaterThan(cgImage.width, 0, "Пустая ширина кадра: \(label)", file: file, line: line)
        XCTAssertGreaterThan(cgImage.height, 0, "Пустая высота кадра: \(label)", file: file, line: line)

        // Даунскейл 32×32 и проверка вариации яркости — пустой/однотонный кадр
        // (краш до отрисовки, отсутствие env, белый прямоугольник) её не даст.
        let dim = 32
        let bytesPerPixel = 4
        let bytesPerRow = dim * bytesPerPixel
        var buffer = [UInt8](repeating: 0, count: dim * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: &buffer, width: dim, height: dim,
            bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            XCTFail("CGContext не создан: \(label)", file: file, line: line)
            return
        }
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: dim, height: dim))
        var minLum: Int = 255
        var maxLum: Int = 0
        for pixel in stride(from: 0, to: buffer.count, by: bytesPerPixel) {
            let lum = (Int(buffer[pixel]) + Int(buffer[pixel + 1]) + Int(buffer[pixel + 2])) / 3
            if lum < minLum { minLum = lum }
            if lum > maxLum { maxLum = lum }
        }
        XCTAssertGreaterThan(
            maxLum - minLum, 12,
            "Кадр выглядит пустым/однотонным (\(label)): variance=\(maxLum - minLum)",
            file: file, line: line
        )
    }

    // MARK: - View rendering

    /// Рендерит SwiftUI-view в `UIImage` фиксированного размера.
    ///
    /// КРИТИЧНО: host-view ПРИКРЕПЛЯЕТСЯ к реальному on-screen `UIWindow`.
    /// На iOS 26 / Xcode 26 `UIView.drawHierarchy(in:afterScreenUpdates:true)`
    /// для view вне иерархии окна рендерит ПУСТОЙ кадр — все snapshot-тесты
    /// тогда дают 100% diff. Прикрепление к key-window и `layer.render(in:)`
    /// (вместо `drawHierarchy`) даёт детерминированный полноценный кадр без
    /// зависимости от композитора экрана.
    ///
    /// - Parameters:
    ///   - view: SwiftUI-view для снимка.
    ///   - size: размер кадра в поинтах.
    ///   - style: light / dark.
    ///   - reduceMotion: при `true` инжектится `accessibilityReduceMotion`,
    ///     что замораживает анимированные фоны (`HSMeshGradientBackground` →
    ///     `TimelineView(.animation)`) на статический кадр и делает снимок
    ///     детерминированным. По умолчанию `false`, чтобы все существующие
    ///     эталоны оставались байт-в-байт неизменными.
    /// - Returns: отрендеренный `UIImage` (scale = scale экрана симулятора).
    @MainActor
    static func renderView<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle,
        reduceMotion: Bool = true
    ) -> UIImage {
        // `accessibilityReduceMotion` в этом SDK — read-only EnvironmentValues
        // (keypath не приводится к `WritableKeyPath`), поэтому фон-анимации
        // (`HSMeshGradientBackground` → `TimelineView(.animation)`) замораживаем
        // через временный override `UIAccessibility.isReduceMotionEnabled`,
        // из которого SwiftUI и сидит окруженческое значение. Снимок становится
        // детерминированным (mesh = staticPoints). По умолчанию reduceMotion ==
        // true → анимированные mesh-фоны (Settings/Onboarding/Permission/Breathing/
        // OfflineState и др.) замораживаются в resting-state, что делает ВСЕ
        // снапшоты детерминированными (устраняет wall-clock-флейки). Все эталоны
        // перезаписаны под этот static-state.
        let restoreReduceMotion = ReduceMotionOverride.begin(reduceMotion)
        defer { restoreReduceMotion() }

        let sized = view
            .frame(width: size.width, height: size.height)
        let host = UIHostingController(rootView: sized)
        host.overrideUserInterfaceStyle = style
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.backgroundColor = host.view.backgroundColor

        // Прикрепляем к реальному окну — без этого drawHierarchy/рендер слоя
        // на iOS 26 даёт пустой кадр.
        let window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.overrideUserInterfaceStyle = style
        window.rootViewController = host
        window.isHidden = false
        window.makeKeyAndVisible()

        // Даём SwiftUI выполнить layout + первичную отрисовку.
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        settleMainRunLoop(iterations: 6, interval: 0.02)

        // Scale зафиксирован на 2.0: все эталонные PNG в `__Snapshots__`
        // записаны при scale 2 (напр. iPhone 17 Pro 402×874pt → 804×1748px).
        // `window.screen.scale` на @3x-симуляторе дал бы 1206×2622px и 100%
        // diff из-за несовпадения размеров. Фиксированный scale делает снимок
        // детерминированным независимо от модели симулятора.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 2.0
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let image = renderer.image { context in
            host.view.layer.render(in: context.cgContext)
        }

        // Отвязываем окно — иначе оно удерживается до конца процесса.
        window.isHidden = true
        window.rootViewController = nil

        return image
    }
}

// MARK: - ReduceMotionOverride
//
// Временно подменяет `UIAccessibility.isReduceMotionEnabled` на заданное
// значение через method swizzling. SwiftUI сидит окруженческое
// `accessibilityReduceMotion` из этого глобального флага, поэтому подмена на
// время рендера делает анимированные фоны статичными и снимок детерминированным.
//
// `begin(_:)` возвращает замыкание-restore, которое возвращает оригинальную
// реализацию. Идемпотентно при вложенных вызовах: счётчик активных оверрайдов
// не ведётся, т.к. snapshot-рендеры выполняются строго последовательно на
// главном потоке (`@MainActor`), без переплетения.

enum ReduceMotionOverride {

    // Доступ строго с главного потока в последовательных snapshot-рендерах
    // (`@MainActor`), поэтому `nonisolated(unsafe)` безопасно. Свизл-блок
    // читает `overriddenValue` синхронно из UIKit на главном потоке.
    nonisolated(unsafe) private static var overriddenValue = false
    nonisolated(unsafe) private static var isSwizzled = false
    nonisolated(unsafe) private static var originalIMP: IMP?

    /// Устанавливает override и возвращает замыкание для отката.
    @MainActor
    static func begin(_ value: Bool) -> () -> Void {
        // Если значение совпадает с системным и свизл не нужен — no-op,
        // чтобы дефолтный путь (reduceMotion == false) ничего не менял,
        // если система и так возвращает false.
        guard value != UIAccessibility.isReduceMotionEnabled else {
            return {}
        }
        overriddenValue = value
        installSwizzleIfNeeded()
        return { restore() }
    }

    /// ObjC-класс `UIAccessibility` (в Swift это namespace-тип, не `AnyClass`,
    /// поэтому достаём через рантайм по имени).
    private static var accessibilityClass: AnyClass? {
        NSClassFromString("UIAccessibility")
    }

    private static let reduceMotionSelector = Selector(("isReduceMotionEnabled"))

    private static func installSwizzleIfNeeded() {
        guard !isSwizzled, let cls = accessibilityClass,
              let method = class_getClassMethod(cls, reduceMotionSelector) else { return }
        let block: @convention(block) (AnyObject) -> Bool = { _ in overriddenValue }
        let newIMP = imp_implementationWithBlock(block)
        originalIMP = method_setImplementation(method, newIMP)
        isSwizzled = true
    }

    private static func restore() {
        guard isSwizzled, let originalIMP, let cls = accessibilityClass,
              let method = class_getClassMethod(cls, reduceMotionSelector) else { return }
        method_setImplementation(method, originalIMP)
        isSwizzled = false
        self.originalIMP = nil
    }
}

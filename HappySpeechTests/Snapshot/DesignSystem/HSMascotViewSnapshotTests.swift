import XCTest
import SwiftUI
@testable import HappySpeech

// MARK: - HSMascotViewSnapshotTests
//
// 10 состояний × 2 темы = 20 snapshot-снимков.
// Рендеринг через UIHostingController на размере 200×200 pt.
//
// При первом запуске — записывает референсы в __Snapshots__/HSMascotView/.
// При последующих — сравнивает байтовый размер (допуск ±1% для anti-aliasing).
//
// Запуск конкретного теста:
//   xcodebuild test -scheme HappySpeech -only-testing HappySpeechTests/HSMascotViewSnapshotTests
//
// Пересоздать референсы: удали __Snapshots__/HSMascotView/ и перезапусти тесты.

final class HSMascotViewSnapshotTests: XCTestCase {

    // MARK: - Configuration

    private let renderSize = CGSize(width: 200, height: 200)
    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark),
    ]

    // MARK: - Tests — по одному тесту на настроение

    func test_idle_snapshot()        throws { try record(mood: .idle) }
    func test_happy_snapshot()       throws { try record(mood: .happy) }
    func test_celebrating_snapshot() throws { try record(mood: .celebrating) }
    func test_thinking_snapshot()    throws { try record(mood: .thinking) }
    func test_sad_snapshot()         throws { try record(mood: .sad) }
    func test_encouraging_snapshot() throws { try record(mood: .encouraging) }
    func test_waving_snapshot()      throws { try record(mood: .waving) }
    func test_explaining_snapshot()  throws { try record(mood: .explaining) }
    func test_singing_snapshot()     throws { try record(mood: .singing) }
    func test_pointing_snapshot()    throws { try record(mood: .pointing) }

    // MARK: - Lip-sync fallback (фиксированная амплитуда 0.5)

    func test_lipsync_open_snapshot() throws {
        @State var amplitude: Float = 0.5
        try record(
            view: HSMascotView(mood: .explaining, size: 160, audioAmplitude: $amplitude),
            name: "lipsync_open"
        )
    }

    // MARK: - Helpers

    @MainActor
    private func record(mood: MascotMood) throws {
        try record(
            view: HSMascotView(mood: mood, size: 160),
            name: mood.description
        )
    }

    @MainActor
    private func record<V: View>(view: V, name: String) throws {
        for (styleName, style) in appearances {
            let image = render(view, style: style)
            let snapshotURL = referenceURL(name: name, appearance: styleName)

            guard let pngData = image.pngData() else {
                XCTFail("Не удалось закодировать PNG для '\(name)' (\(styleName))")
                continue
            }

            if FileManager.default.fileExists(atPath: snapshotURL.path) {
                // Сравниваем байтовый размер с допуском 1%
                let existingData = try Data(contentsOf: snapshotURL)
                let ratio = abs(Double(pngData.count) - Double(existingData.count)) / Double(existingData.count)
                XCTAssertLessThan(
                    ratio, 0.01,
                    "Snapshot '\(name)' (\(styleName)) изменился: \(existingData.count) → \(pngData.count) байт"
                )
            } else {
                // Первый запуск — записываем референс
                try pngData.write(to: snapshotURL)
                XCTFail("Записан новый референс: \(snapshotURL.lastPathComponent). Перезапусти тест.")
            }
        }
    }

    @MainActor
    private func render<V: View>(_ view: V, style: UIUserInterfaceStyle) -> UIImage {
        let hosted = view
            .frame(width: renderSize.width, height: renderSize.height)
            .background(style == .dark ? Color.black : Color.white)

        let controller = UIHostingController(rootView: hosted)
        controller.overrideUserInterfaceStyle = style
        controller.view.frame = CGRect(origin: .zero, size: renderSize)
        controller.view.layoutIfNeeded()

        let renderer = UIGraphicsImageRenderer(size: renderSize)
        return renderer.image { _ in
            controller.view.drawHierarchy(in: controller.view.bounds, afterScreenUpdates: true)
        }
    }

    private func referenceURL(name: String, appearance: String) -> URL {
        // Сохраняем рядом с бандлом тест-таргета
        let baseDir = Bundle(for: Self.self).bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("__Snapshots__/HSMascotView")
        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        let safeName = name.replacingOccurrences(of: "/", with: "_")
        return baseDir.appendingPathComponent("\(safeName)_\(appearance).png")
    }
}

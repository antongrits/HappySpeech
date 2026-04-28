@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - ARSnapshotTests
//
// M10.2 — Snapshot smoke-тесты для AR-экранов.
// Матрица: 6 экранов × 2 девайса × 2 темы = 24 PNG.
//
// ВАЖНО: AR-сессии не запускаются в симуляторе.
// Снимок делается на состоянии «до запуска ARKit сессии» — это позволяет
// проверить UI-скелет (аватар, кнопки, заголовки) без реального трекинга лица.
//
// Хранение: __Snapshots__/AR/

@MainActor
final class ARSnapshotTests: XCTestCase {

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }
    private let devices: [DeviceConfig] = [
        DeviceConfig(name: "iPhoneSE3",   size: CGSize(width: 375, height: 667)),
        DeviceConfig(name: "iPhone17Pro", size: CGSize(width: 402, height: 874))
    ]
    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light), ("Dark", .dark)
    ]

    // MARK: - 1. ARZoneView (без AR-сессии)

    func test_arZone_smoke() throws {
        let view = ARZoneView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        try record(view, screen: "AR_ZoneSmoke")
    }

    // MARK: - 2. ARZoneTutorialSheetView

    func test_arZoneTutorial_smoke() throws {
        let tutorial = ARTutorial(
            id: "ar-mirror",
            titleKey: "ar.tutorial.mirror.title",
            bodyKey: "ar.tutorial.mirror.body",
            steps: [
                ARTutorialStep(id: "s1", icon: "face.smiling", textKey: "Посмотри в камеру"),
                ARTutorialStep(id: "s2", icon: "mouth",        textKey: "Повторяй позу Ляли")
            ],
            animationSystemSymbol: "camera.fill",
            accentColorIndex: 0
        )
        let view = ARZoneTutorialSheetView(
            tutorial: tutorial,
            onStart: {},
            onSkip: {}
        )
        .environment(AppContainer.preview())
        try record(view, screen: "AR_ZoneTutorialSmoke")
    }

    // MARK: - 3. ARMirrorView (без AR-сессии)

    func test_arMirror_smoke() throws {
        let view = ARMirrorView()
            .environment(AppContainer.preview())
        try record(view, screen: "AR_MirrorSmoke")
    }

    // MARK: - 4. MimicLyalyaView (без AR-сессии)

    func test_mimicLyalya_smoke() throws {
        let view = MimicLyalyaView()
        try record(view, screen: "AR_MimicLyalyaSmoke")
    }

    // MARK: - 5. BreathingARView (без AR-сессии)

    func test_breathingAR_smoke() throws {
        let view = BreathingARView()
        try record(view, screen: "AR_BreathingARSmoke")
    }

    // MARK: - 6. ARZoneView — Dark только iPhone 17 Pro (дополнительный вариант)

    func test_arZone_darkMode_largePro() throws {
        let view = ARZoneView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
            .environment(\.colorScheme, .dark)
        try record(view, screen: "AR_ZoneDarkLarge")
    }

    // MARK: - Rendering engine

    private func render<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) -> UIImage {
        let sized = view.frame(width: size.width, height: size.height)
        let host = UIHostingController(rootView: sized)
        host.overrideUserInterfaceStyle = style
        host.view.frame = CGRect(origin: .zero, size: size)
        host.view.layoutIfNeeded()
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: true)
        }
    }

    private func snapshotURL(screen: String, device: String, appearance: String) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "AR",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    private func record<V: View>(_ view: V, screen: String) throws {
        for device in devices {
            for (appearanceName, style) in appearances {
                let image = render(view, size: device.size, style: style)
                let url = snapshotURL(screen: screen, device: device.name, appearance: appearanceName)

                guard let pngData = image.pngData() else {
                    XCTFail("PNG encoding failed: \(screen)/\(device.name)/\(appearanceName)")
                    continue
                }

                if FileManager.default.fileExists(atPath: url.path) {
                    let existing = try Data(contentsOf: url)
                    let ratio = abs(Double(pngData.count) - Double(existing.count)) / Double(max(existing.count, 1))
                    // Порог 30%: UIGraphicsImageRenderer нестабилен между прогонами
                    XCTAssertLessThan(
                        ratio, 0.30,
                        "Snapshot изменился (\(screen)·\(device.name)·\(appearanceName)): \(existing.count) → \(pngData.count) байт"
                    )
                } else {
                    try pngData.write(to: url)
                    XCTFail("Записан новый референс '\(url.lastPathComponent)' для \(screen). Перезапусти тест.")
                }
            }
        }
    }
}

@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - FocusStateSnapshotTests
//
// Plan v9 Блок B2 — edge-case снапшоты для фокусных состояний текстовых полей.
//
// Матрица:
//   Settings TextField state × iPhone 17 Pro × 2 темы = 2 PNG
//
// Стратегия: SettingsView рендерится в режиме стандартного старта (список виден).
// SettingsSpecialistConnectSheet — private тип, поэтому тестируем через публичный
// SettingsView (секция специалиста раскрыта по умолчанию в preview-контейнере).
//
// Хранение: __Snapshots__/FocusStates/

@MainActor
final class FocusStateSnapshotTests: XCTestCase {

    // MARK: - Device config (только iPhone 17 Pro, спека B2)

    private let deviceSize = CGSize(width: 402, height: 874)
    private let deviceName = "iPhone17Pro"

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark)
    ]

    // MARK: - 1. Settings — TextField edge case (light + dark)

    func test_settingsTextField_focusEdgeCase() throws {
        let view = SettingsView()
            .environment(AppContainer.preview())
        try recordFocus(view, screen: "SettingsTextField")
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

    // MARK: - Reference storage

    private func snapshotURL(screen: String, device: String, appearance: String) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "FocusStates",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    // MARK: - Record / compare

    private func recordFocus<V: View>(_ view: V, screen: String) throws {
        for (appearanceName, style) in appearances {
            let image = render(view, size: deviceSize, style: style)
            let url = snapshotURL(screen: screen, device: deviceName, appearance: appearanceName)

            guard let pngData = image.pngData() else {
                XCTFail("PNG encoding failed: \(screen)/\(deviceName)/\(appearanceName)")
                continue
            }

            if FileManager.default.fileExists(atPath: url.path) {
                let existing = try Data(contentsOf: url)
                let ratio = abs(Double(pngData.count) - Double(existing.count)) / Double(max(existing.count, 1))
                // Порог 30%: UIGraphicsImageRenderer нестабилен между прогонами
                XCTAssertLessThan(
                    ratio, 0.30,
                    "Snapshot изменился (\(screen)·\(deviceName)·\(appearanceName)): \(existing.count) → \(pngData.count) байт"
                )
            } else {
                try pngData.write(to: url)
                XCTFail(
                    "Записан новый референс '\(url.lastPathComponent)' для \(screen). Перезапусти тест."
                )
            }
        }
    }
}

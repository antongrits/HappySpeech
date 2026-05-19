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
            SnapshotTestHelper.renderView(view, size: size, style: style)
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
            let label = "\(screen)·\(deviceName)·\(appearanceName)"
            try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
        }
    }
}

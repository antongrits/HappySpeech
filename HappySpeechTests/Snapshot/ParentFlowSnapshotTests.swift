@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - ParentFlowSnapshotTests
//
// M10.2 — Snapshot-тесты для родительского контура.
// Матрица: 6 экранов × 2 девайса × 2 темы = 24 PNG.
//
// Хранение: __Snapshots__/ParentFlow/

@MainActor
final class ParentFlowSnapshotTests: XCTestCase {

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

    // MARK: - 1. ParentHomeView

    func test_parentHome_bothThemes() throws {
        let view = ParentHomeView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ParentHomeParentFlow")
    }

    // MARK: - 2. ProgressDashboardView

    func test_progressDashboard_bothThemes() throws {
        let view = ProgressDashboardView(childId: "preview-child-1")
            .environment(AppContainer.preview())
        try record(view, screen: "ProgressDashboardParentFlow")
    }

    // MARK: - 3. SessionHistoryView

    func test_sessionHistory_bothThemes() throws {
        let view = SessionHistoryView()
            .environment(AppContainer.preview())
        try record(view, screen: "SessionHistoryParentFlow")
    }

    // MARK: - 4. HomeTasksView

    func test_homeTasks_bothThemes() throws {
        let view = HomeTasksView()
            .environment(AppContainer.preview())
        try record(view, screen: "HomeTasksParentFlow")
    }

    // MARK: - 5. SettingsView

    func test_settings_bothThemes() throws {
        let view = SettingsView()
            .environment(AppContainer.preview())
        try record(view, screen: "SettingsParentFlow")
    }

    // MARK: - 6. OfflineStateView

    func test_offlineState_bothThemes() throws {
        let view = OfflineStateView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        try record(view, screen: "OfflineStateParentFlow")
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
            category: "ParentFlow",
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
                let label = "\(screen)·\(device.name)·\(appearanceName)"
                try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
            }
        }
    }
}

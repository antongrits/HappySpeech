@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - KeyScreensSnapshotTests
//
// F1 (S12-013): snapshot-тесты ключевых экранов в light и dark теме.
//
// Покрытые экраны (10 View × 2 темы × 2 устройства = 40 PNG):
//   1. AuthSignInView
//   2. OnboardingFlowView (step 1 — welcome)
//   3. ChildHomeView
//   4. RewardsView
//   5. SessionCompleteView
//   6. ProgressDashboardView
//   7. SettingsView
//   8. WorldMapView
//   9. ARZoneView
//  10. PermissionFlowView
//
// Рендеринг: UIHostingController + UIGraphicsImageRenderer (без pointfree API,
// консистентно с HSMascotViewSnapshotTests). При первом запуске записываются
// референсы в __Snapshots__/KeyScreens/ рядом с бандлом тест-таргета.
// При последующих запусках сравнивается байтовый размер с допуском 1%.
//
// Перегенерировать: удали папку __Snapshots__/KeyScreens/ и перезапусти тесты.
// ==================================================================================

@MainActor
final class KeyScreensSnapshotTests: XCTestCase {

    // MARK: - Device matrix

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }

    private let devices: [DeviceConfig] = [
        DeviceConfig(name: "iPhoneSE3",    size: CGSize(width: 375, height: 667)),
        DeviceConfig(name: "iPhone17Pro",  size: CGSize(width: 402, height: 874))
    ]

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark)
    ]

    // MARK: - 1. AuthSignInView

    func test_authSignIn_rendersInBothThemes() throws {
        let view = AuthSignInView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "AuthSignInView")
    }

    // MARK: - 2. OnboardingFlowView (step 1 — welcome)

    func test_onboardingFlow_rendersInBothThemes() throws {
        let view = OnboardingFlowView(onComplete: { _ in })
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "OnboardingFlowView")
    }

    // MARK: - 3. ChildHomeView

    func test_childHome_rendersInBothThemes() throws {
        let view = ChildHomeView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ChildHomeView")
    }

    // MARK: - 4. RewardsView

    func test_rewards_rendersInBothThemes() throws {
        let view = RewardsView(childId: "preview-child-1")
            .environment(AppContainer.preview())
        try record(view, screen: "RewardsView")
    }

    // MARK: - 5. SessionCompleteView

    func test_sessionComplete_threeStars_rendersInBothThemes() throws {
        let result = SessionResult.sample
        let view = SessionCompleteView(
            result: result,
            onContinue: {},
            onReplay: {}
        )
        try record(view, screen: "SessionCompleteView_3stars")
    }

    func test_sessionComplete_zeroStars_rendersInBothThemes() throws {
        let result = SessionResult(
            score: 0.30,
            starsEarned: 0,
            gameTitle: "Слушай и выбирай",
            soundTarget: "С",
            attempts: 5,
            durationSec: 120,
            nextLessonTitle: nil
        )
        let view = SessionCompleteView(
            result: result,
            onContinue: {},
            onReplay: {}
        )
        try record(view, screen: "SessionCompleteView_0stars")
    }

    // MARK: - 6. ProgressDashboardView

    func test_progressDashboard_rendersInBothThemes() throws {
        let view = ProgressDashboardView(childId: "preview-child-1")
            .environment(AppContainer.preview())
        try record(view, screen: "ProgressDashboardView")
    }

    // MARK: - 7. SettingsView

    func test_settings_rendersInBothThemes() throws {
        let view = SettingsView()
            .environment(AppContainer.preview())
        try record(view, screen: "SettingsView")
    }

    // MARK: - 8. WorldMapView

    func test_worldMap_rendersInBothThemes() throws {
        let view = WorldMapView(childId: "preview-child-1", targetSound: "Р")
            .environment(AppContainer.preview())
        try record(view, screen: "WorldMapView")
    }

    // MARK: - 9. ARZoneView

    func test_arZone_rendersInBothThemes() throws {
        let view = ARZoneView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        try record(view, screen: "ARZoneView")
    }

    // MARK: - 10. PermissionFlowView

    func test_permissionFlow_microphone_rendersInBothThemes() throws {
        let view = PermissionFlowView(type: .microphone)
            .environment(AppCoordinator())
        try record(view, screen: "PermissionFlowView_microphone")
    }

    func test_permissionFlow_camera_rendersInBothThemes() throws {
        let view = PermissionFlowView(type: .camera)
            .environment(AppCoordinator())
        try record(view, screen: "PermissionFlowView_camera")
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
            category: "KeyScreens",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    // MARK: - Record / compare

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

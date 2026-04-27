@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - ErrorStatesSnapshotTests
//
// M10.2 — Snapshot-тесты для состояний ошибок и пустых экранов.
// Матрица: 10 состояний × 2 девайса × 2 темы = 40 PNG.
//
// Тестируем view-компоненты напрямую с разными ViewModel-состояниями.
//
// Хранение: __Snapshots__/ErrorStates/

@MainActor
final class ErrorStatesSnapshotTests: XCTestCase {

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

    // MARK: - 1. OfflineStateView (основное состояние)

    func test_offlineState_main() throws {
        let view = OfflineStateView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        try record(view, screen: "ErrorState_Offline")
    }

    // MARK: - 2. SessionCompleteView — 0 звёзд (плохой результат)

    func test_sessionComplete_zeroStars() throws {
        let result = SessionResult(
            score: 0.25,
            starsEarned: 0,
            gameTitle: "Слушай и выбирай",
            soundTarget: "Р",
            attempts: 8,
            durationSec: 180,
            nextLessonTitle: nil
        )
        let view = SessionCompleteView(result: result, onContinue: {}, onReplay: {})
        try record(view, screen: "ErrorState_SessionComplete0Stars")
    }

    // MARK: - 3. SessionCompleteView — 1 звезда

    func test_sessionComplete_oneStar() throws {
        let result = SessionResult(
            score: 0.45,
            starsEarned: 1,
            gameTitle: "Сортировка",
            soundTarget: "С",
            attempts: 10,
            durationSec: 300,
            nextLessonTitle: nil
        )
        let view = SessionCompleteView(result: result, onContinue: {}, onReplay: {})
        try record(view, screen: "ErrorState_SessionComplete1Star")
    }

    // MARK: - 4. PermissionFlowView — denied state (camera)

    func test_permissionsFlow_camera() throws {
        let view = PermissionFlowView(type: .camera)
            .environment(AppCoordinator())
        try record(view, screen: "ErrorState_PermissionCamera")
    }

    // MARK: - 5. PermissionFlowView — notifications

    func test_permissionsFlow_notifications() throws {
        let view = PermissionFlowView(type: .notifications)
            .environment(AppCoordinator())
        try record(view, screen: "ErrorState_PermissionNotif")
    }

    // MARK: - 6. SplashView (loading state)

    func test_splash_loadingState() throws {
        let view = SplashView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ErrorState_Splash")
    }

    // MARK: - 7. AuthVerifyEmailView (email verification)

    func test_authVerifyEmail() throws {
        let view = AuthVerifyEmailView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ErrorState_AuthVerifyEmail")
    }

    // MARK: - 8. AuthForgotPasswordView

    func test_authForgotPassword() throws {
        let view = AuthForgotPasswordView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "ErrorState_AuthForgot")
    }

    // MARK: - 9. DemoView (вводный экран)

    func test_demoView_introState() throws {
        let view = DemoView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        try record(view, screen: "ErrorState_DemoIntro")
    }

    // MARK: - 10. WorldMapView — empty progress

    func test_worldMap_emptyProgress() throws {
        let view = WorldMapView(childId: "empty-child", targetSound: "Ш")
            .environment(AppContainer.preview())
        try record(view, screen: "ErrorState_WorldMapEmpty")
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
            category: "ErrorStates",
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
                    XCTAssertLessThan(
                        ratio, 0.02,
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

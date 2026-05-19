@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - DynamicTypeSnapshotTests
//
// M10.2 — Snapshot-тесты с вариациями Dynamic Type для 15 ключевых экранов.
//
// Матрица:
//   15 экранов × 3 DT-размера (default/large/accessibilityLarge) × 2 темы = 90 PNG
//
// Рендеринг: UIHostingController + UIGraphicsImageRenderer (тот же движок что и в
// KeyScreensSnapshotTests). Хранение: рядом с бандлом в __Snapshots__/DynamicType/.
// Допуск по размеру файла: 2%.

@MainActor
final class DynamicTypeSnapshotTests: XCTestCase {

    // MARK: - Device config

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }
    // Один девайс — iPhone 17 Pro (экономим время, DT важнее размера экрана).
    private let device = DeviceConfig(name: "iPhone17Pro", size: CGSize(width: 402, height: 874))

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark)
    ]

    private let dynamicTypeSizes: [(String, UIContentSizeCategory)] = [
        ("Default",           .large),
        ("DT_Large",          .extraExtraLarge),
        ("DT_AccessibilityL", .accessibilityExtraLarge)
    ]

    // MARK: - 1. ChildHomeView

    func test_childHome_dynamicType() throws {
        let view = ChildHomeView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try recordDT(view, screen: "ChildHomeDT")
    }

    // MARK: - 2. ParentHomeView

    func test_parentHome_dynamicType() throws {
        let view = ParentHomeView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try recordDT(view, screen: "ParentHomeDT")
    }

    // MARK: - 3. RewardsView

    func test_rewards_dynamicType() throws {
        let view = RewardsView(childId: "preview-child-1")
            .environment(AppContainer.preview())
        try recordDT(view, screen: "RewardsDT")
    }

    // MARK: - 4. SessionCompleteView

    func test_sessionComplete_dynamicType() throws {
        let view = SessionCompleteView(
            result: SessionResult.sample,
            onContinue: {},
            onReplay: {}
        )
        try recordDT(view, screen: "SessionCompleteDT")
    }

    // MARK: - 5. SettingsView

    func test_settings_dynamicType() throws {
        let view = SettingsView()
            .environment(AppContainer.preview())
        try recordDT(view, screen: "SettingsDT")
    }

    // MARK: - 6. WorldMapView

    func test_worldMap_dynamicType() throws {
        let view = WorldMapView(childId: "preview-child-1", targetSound: "Р")
            .environment(AppContainer.preview())
        try recordDT(view, screen: "WorldMapDT")
    }

    // MARK: - 7. ProgressDashboardView

    func test_progressDashboard_dynamicType() throws {
        let view = ProgressDashboardView(childId: "preview-child-1")
            .environment(AppContainer.preview())
        try recordDT(view, screen: "ProgressDashboardDT")
    }

    // MARK: - 8. OnboardingFlowView

    func test_onboarding_dynamicType() throws {
        let view = OnboardingFlowView(onComplete: { _ in })
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try recordDT(view, screen: "OnboardingDT")
    }

    // MARK: - 9. AuthSignInView

    func test_authSignIn_dynamicType() throws {
        let view = AuthSignInView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try recordDT(view, screen: "AuthSignInDT")
    }

    // MARK: - 10. HomeTasksView

    func test_homeTasks_dynamicType() throws {
        let view = HomeTasksView()
            .environment(AppContainer.preview())
        try recordDT(view, screen: "HomeTasksDT")
    }

    // MARK: - 11. SessionHistoryView

    func test_sessionHistory_dynamicType() throws {
        let view = SessionHistoryView()
            .environment(AppContainer.preview())
        try recordDT(view, screen: "SessionHistoryDT")
    }

    // MARK: - 12. PermissionFlowView (microphone)

    func test_permissionsFlow_dynamicType() throws {
        let view = PermissionFlowView(type: .microphone)
            .environment(AppCoordinator())
        try recordDT(view, screen: "PermissionsFlowDT")
    }

    // MARK: - 13. OfflineStateView

    func test_offlineState_dynamicType() throws {
        let view = OfflineStateView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        try recordDT(view, screen: "OfflineStateDT")
    }

    // MARK: - 14. DemoView

    func test_demo_dynamicType() throws {
        let view = DemoView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        try recordDT(view, screen: "DemoDT")
    }

    // MARK: - 15. BreathingView (game template)

    func test_breathingGame_dynamicType() throws {
        let activity = SessionActivity(
            id: "dt-breathing",
            gameType: .breathing,
            lessonId: "lesson-dt",
            soundTarget: "С",
            difficulty: 1,
            isCompleted: false,
            score: nil
        )
        let view = BreathingView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try recordDT(view, screen: "BreathingGameDT")
    }

    // MARK: - Rendering engine

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle,
        contentSize: UIContentSizeCategory
    ) -> UIImage {
        let sized = view
            .environment(\.sizeCategory, ContentSizeCategory(contentSize) ?? .large)
        return SnapshotTestHelper.renderView(sized, size: size, style: style)
    }

    // MARK: - Reference storage

    private func snapshotURL(screen: String, dtSize: String, appearance: String) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "DynamicType",
            screen: screen,
            device: dtSize,
            appearance: appearance
        )
    }

    // MARK: - Record / compare

    private func recordDT<V: View>(_ view: V, screen: String) throws {
        for (dtName, dtCategory) in dynamicTypeSizes {
            for (appearanceName, style) in appearances {
                let image = render(view, size: device.size, style: style, contentSize: dtCategory)
                let url = snapshotURL(screen: screen, dtSize: dtName, appearance: appearanceName)
                let label = "\(screen)·\(dtName)·\(appearanceName)"
                try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
            }
        }
    }
}

// MARK: - ContentSizeCategory bridging

private extension ContentSizeCategory {
    init?(_ uiKit: UIContentSizeCategory) {
        switch uiKit {
        case .extraSmall:               self = .extraSmall
        case .small:                    self = .small
        case .medium:                   self = .medium
        case .large:                    self = .large
        case .extraLarge:               self = .extraLarge
        case .extraExtraLarge:          self = .extraExtraLarge
        case .extraExtraExtraLarge:     self = .extraExtraExtraLarge
        case .accessibilityMedium:      self = .accessibilityMedium
        case .accessibilityLarge:       self = .accessibilityLarge
        case .accessibilityExtraLarge:  self = .accessibilityExtraLarge
        case .accessibilityExtraExtraLarge: self = .accessibilityExtraExtraLarge
        case .accessibilityExtraExtraExtraLarge: self = .accessibilityExtraExtraExtraLarge
        default: return nil
        }
    }
}

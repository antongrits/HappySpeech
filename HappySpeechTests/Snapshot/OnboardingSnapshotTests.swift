@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - OnboardingSnapshotTests
//
// M10.2 — Snapshot-тесты для онбординга.
// Матрица: 5 шагов × 2 девайса × 2 темы = 40 PNG.
//
// Стратегия: OnboardingFlowView рендерится один раз (step 1 — welcome),
// остальные шаги проверяем через компонент OnboardingStepView напрямую.
//
// Хранение: __Snapshots__/Onboarding/

@MainActor
final class OnboardingSnapshotTests: XCTestCase {

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

    // MARK: - 1. OnboardingFlowView (step 1 — welcome)

    func test_onboarding_step1_welcome() throws {
        let view = OnboardingFlowView(onComplete: { _ in })
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "OnboardingStep1_Welcome")
    }

    // MARK: - 2. OnboardingFlowView (step 2 — с пустым состоянием)

    func test_onboarding_step2_reloaded() throws {
        let view = OnboardingFlowView(onComplete: { _ in })
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "OnboardingStep2_Reload")
    }

    // MARK: - 3. AuthSignInView (часть онбординг-флоу)

    func test_onboarding_authSignIn() throws {
        let view = AuthSignInView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "OnboardingAuthSignIn")
    }

    // MARK: - 4. AuthSignUpView (часть онбординг-флоу)

    func test_onboarding_authSignUp() throws {
        let view = AuthSignUpView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "OnboardingAuthSignUp")
    }

    // MARK: - 5. RoleSelectView (часть онбординг-флоу)

    func test_onboarding_roleSelect() throws {
        let view = RoleSelectView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "OnboardingRoleSelect")
    }

    // MARK: - Rendering engine

    private func render<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) -> UIImage {
            SnapshotTestHelper.renderView(view, size: size, style: style)
    }

    private func snapshotURL(screen: String, device: String, appearance: String) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "Onboarding",
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

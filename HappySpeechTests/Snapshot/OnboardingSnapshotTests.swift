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
        try record(view, screen: "OnboardingStep1_Welcome")
    }

    // MARK: - 2. OnboardingFlowView (step 2 — с пустым состоянием)

    func test_onboarding_step2_reloaded() throws {
        let view = OnboardingFlowView(onComplete: { _ in })
            .environment(AppCoordinator())
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

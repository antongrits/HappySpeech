@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - AccessibilityVariantsSnapshotTests
//
// Plan v9 Блок B2 — дополнительные snapshot-варианты для accessibility-кейсов.
//
// Матрица:
//   Onboarding step1 × DT_Large × 2 темы       = 2 PNG
//   Onboarding step1 × DT_AccessibilityL × 2 темы = 2 PNG
//   ParentHome × DT_AccessibilityL × Light      = 1 PNG
//   ProgressDashboard × DT_AccessibilityL × Light = 1 PNG
//   SessionHistory × DT_AccessibilityL × Light  = 1 PNG
//
// Итого: 7 PNG в __Snapshots__/AccessibilityVariants/
//
// Хранение: рядом с бандлом в __Snapshots__/AccessibilityVariants/<screen>/
// Движок: UIHostingController + UIGraphicsImageRenderer (локальная реализация).

@MainActor
final class AccessibilityVariantsSnapshotTests: XCTestCase {

    // MARK: - Device config (только iPhone 17 Pro как в спеке B2)

    private let deviceSize = CGSize(width: 402, height: 874)
    private let deviceName = "iPhone17Pro"

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark)
    ]

    // MARK: - 1. Onboarding step 1 — Dynamic Type Large (light + dark)

    func test_onboardingStep1_dynamicTypeLarge() throws {
        let view = OnboardingFlowView(onComplete: { _ in })
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try recordAccessibility(
            view,
            screen: "OnboardingStep1_DT_Large",
            dtCategory: .extraExtraLarge,
            limitAppearances: appearances
        )
    }

    // MARK: - 2. Onboarding step 1 — Dynamic Type AccessibilityLarge (light + dark)

    func test_onboardingStep1_dynamicTypeAccessibilityLarge() throws {
        let view = OnboardingFlowView(onComplete: { _ in })
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try recordAccessibility(
            view,
            screen: "OnboardingStep1_DT_AccessibilityL",
            dtCategory: .accessibilityExtraLarge,
            limitAppearances: appearances
        )
    }

    // MARK: - 3. ParentHome — Dynamic Type AccessibilityLarge (light only)

    func test_parentHome_dynamicTypeAccessibilityLarge_light() throws {
        let view = ParentHomeView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try recordAccessibility(
            view,
            screen: "ParentHome_DT_AccessibilityL",
            dtCategory: .accessibilityExtraLarge,
            limitAppearances: [("Light", .light)]
        )
    }

    // MARK: - 4. ProgressDashboard — Dynamic Type AccessibilityLarge (light only)

    func test_progressDashboard_dynamicTypeAccessibilityLarge_light() throws {
        let view = ProgressDashboardView(childId: "preview-child-1")
            .environment(AppContainer.preview())
        try recordAccessibility(
            view,
            screen: "ProgressDashboard_DT_AccessibilityL",
            dtCategory: .accessibilityExtraLarge,
            limitAppearances: [("Light", .light)]
        )
    }

    // MARK: - 5. SessionHistory — Dynamic Type AccessibilityLarge (light only)

    func test_sessionHistory_dynamicTypeAccessibilityLarge_light() throws {
        let view = SessionHistoryView()
            .environment(AppContainer.preview())
        try recordAccessibility(
            view,
            screen: "SessionHistory_DT_AccessibilityL",
            dtCategory: .accessibilityExtraLarge,
            limitAppearances: [("Light", .light)]
        )
    }

    // MARK: - Rendering engine

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle,
        contentSize: UIContentSizeCategory
    ) -> UIImage {
        let sized = view
            .frame(width: size.width, height: size.height)
            .environment(\.sizeCategory, ContentSizeCategory(contentSize) ?? .large)
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
            category: "AccessibilityVariants",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    // MARK: - Record / compare helper

    private func recordAccessibility<V: View>(
        _ view: V,
        screen: String,
        dtCategory: UIContentSizeCategory,
        limitAppearances: [(String, UIUserInterfaceStyle)]
    ) throws {
        for (appearanceName, style) in limitAppearances {
            let image = render(view, size: deviceSize, style: style, contentSize: dtCategory)
            let url = snapshotURL(screen: screen, device: deviceName, appearance: appearanceName)
            let label = "\(screen)·\(deviceName)·\(appearanceName)"
            try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
        }
    }
}

// MARK: - ContentSizeCategory bridging (локальная копия для этого файла)

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

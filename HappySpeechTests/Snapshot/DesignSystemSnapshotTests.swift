@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - DesignSystemSnapshotTests
//
// Uses UIKit rendering to capture PNGs of key DesignSystem components across
// iPhone SE (3rd gen) and iPhone 17 Pro, in both light and dark appearance.
//
// IMPORTANT: this file intentionally does NOT depend on swift-snapshot-testing.
// It records reference images to `__Snapshots__/DesignSystemSnapshotTests/`
// on first run and compares byte-for-byte on subsequent runs. When refactoring
// a component, delete the reference file and re-run to regenerate.
//
// If the project later adds `pointfreeco/swift-snapshot-testing`, migrate these
// tests to `assertSnapshot(matching: view, as: .image(...))`.
// ==================================================================================

@MainActor
final class DesignSystemSnapshotTests: XCTestCase {

    // MARK: - Device matrix

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }
    private let devices: [DeviceConfig] = [
        DeviceConfig(name: "iPhoneSE3", size: CGSize(width: 375, height: 667)),
        DeviceConfig(name: "iPhone17Pro", size: CGSize(width: 402, height: 874))
    ]
    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light), ("Dark", .dark)
    ]

    // MARK: - Helpers

    private func render<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) -> UIImage {
            SnapshotTestHelper.renderView(view, size: size, style: style)
    }

    private func snapshotURL(component: String, device: String, appearance: String) -> URL {
        let base = SnapshotTestHelper.snapshotsBaseDir
            .appendingPathComponent(component)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("\(device)_\(appearance).png")
    }

    private func record<V: View>(_ view: V, component: String) throws {
        for device in devices {
            for (name, style) in appearances {
                let image = render(view, size: device.size, style: style)
                let url = snapshotURL(component: component, device: device.name, appearance: name)
                let label = "\(component)·\(device.name)·\(name)"
                try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
            }
        }
    }

    // MARK: - Tests (all components stable as of Plan v21 Block Z)

    func test_HSButton_primary_renders() throws {
        let view = HSButton("Начать урок", style: .primary, size: .large) {}
        try record(view, component: "HSButton_primary")
    }

    func test_HSSpeechBubble_lyalya_renders() throws {
        let view = HSSpeechBubble("Привет! Я Ляля. Давай учиться!", direction: .left, style: .lyalya)
        try record(view.padding(16), component: "HSSpeechBubble_lyalya")
    }

    func test_HSPictTile_correct_renders() throws {
        let view = HSPictTile(symbol: "sun.max.fill", label: "Солнце", state: .correct) {}
        try record(view, component: "HSPictTile_correct")
    }

    func test_GuidedTourTipView_firstStep_renders() throws {
        let step = TourStep(
            id: "welcome",
            title: "Добро пожаловать!",
            body: "Это ваш первый шаг в HappySpeech. Давайте познакомимся с приложением.",
            highlightKey: "childHome.dailyPlan",
            lyalyaPhrase: nil,
            autoAdvanceAfter: nil,
            allowSkip: true
        )
        let view = GuidedTourTipView(
            step: step,
            stepNumber: 1,
            totalSteps: 5,
            spotlightRect: .zero,
            screenSize: CGSize(width: 375, height: 667),
            isLastStep: false,
            onNext: {},
            onSkip: {}
        )
        try record(view.padding(16), component: "GuidedTourTipView_firstStep")
    }
}

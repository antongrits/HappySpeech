@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - Wave2MechanicsSnapshotTests
//
// Снапшот-тесты для новых игровых механик Волны 2 (F2-009 и далее).
//
// Матрица: View × 2 темы (Light/Dark) × 2 устройства (iPhoneSE3 375×667,
// iPhone17Pro 402×874) PNG в __Snapshots__/Wave2Mechanics/.
//
// Паттерн идентичен Wave1…4SnapshotTests: UIHostingController +
// UIGraphicsImageRenderer (scale 2.0), reduceMotion=true для детерминизма
// (замораживает HSMeshGradient/TimelineView анимации). VIP-view инициализируют
// interactor внутри `.task`; renderView() прокручивает main run loop.
//
// Первый прогон ЗАПИСЫВАЕТ референсы (XCTFail «Записан новый референс»);
// второй прогон сравнивает и проходит зелёным.

@MainActor
final class Wave2MechanicsSnapshotTests: XCTestCase {

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }

    private let devices: [DeviceConfig] = [
        DeviceConfig(name: "iPhoneSE3",   size: CGSize(width: 375, height: 667)),
        DeviceConfig(name: "iPhone17Pro", size: CGSize(width: 402, height: 874))
    ]

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark)
    ]

    // MARK: - F2-009 SoundDetectiveView (kid, childId)

    func test_soundDetective_rendersInBothThemes() throws {
        let view = SoundDetectiveView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        // Допуск 10%: clue-карточка использует translucent HSLiquidGlassCard
        // (.ultraThinMaterial fallback под reduceMotion) поверх asset-картинки —
        // material-blur даёт суб-пиксельный GPU-jitter (~5.3%) между процессами,
        // как у других material-heavy game-view (AdvancedGameSnapshotTests).
        try record(view, screen: "SoundDetectiveView", maxDiffRatio: 0.10)
    }

    // MARK: - F2-003 SyllableSnailView (kid, childId)

    func test_syllableSnail_rendersInBothThemes() throws {
        let view = SyllableSnailView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        // Допуск 10%: word-карточка использует translucent HSLiquidGlassCard
        // поверх asset-картинки — material-blur даёт суб-пиксельный GPU-jitter
        // между процессами, как у SoundDetectiveView выше.
        try record(view, screen: "SyllableSnailView", maxDiffRatio: 0.10)
    }

    // MARK: - F2-005 FourthExtraView (kid, childId)

    func test_fourthExtra_rendersInBothThemes() throws {
        let view = FourthExtraView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        // Допуск 10%: карточки сетки 2×2 используют translucent
        // HSLiquidGlassCard поверх asset-картинок — material-blur даёт
        // суб-пиксельный GPU-jitter между процессами, как у SoundDetectiveView.
        try record(view, screen: "FourthExtraView", maxDiffRatio: 0.10)
    }

    // MARK: - F2-007 WordFormationView (kid, childId)

    func test_wordFormation_rendersInBothThemes() throws {
        let view = WordFormationView(childId: "preview-child-1")
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        // Допуск 10%: картинка-основа в translucent HSLiquidGlassCard
        // (.ultraThinMaterial fallback под reduceMotion) поверх asset-картинки —
        // material-blur даёт суб-пиксельный GPU-jitter между процессами, как у
        // SoundDetectiveView / FourthExtraView выше.
        try record(view, screen: "WordFormationView", maxDiffRatio: 0.10)
    }

    // MARK: - Rendering engine

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle,
        reduceMotion: Bool = true
    ) -> UIImage {
        SnapshotTestHelper.renderView(view, size: size, style: style, reduceMotion: reduceMotion)
    }

    private func snapshotURL(screen: String, device: String, appearance: String) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "Wave2Mechanics",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    private func record<V: View>(
        _ view: V,
        screen: String,
        maxDiffRatio: Double = SnapshotTestHelper.defaultMaxDiffRatio,
        reduceMotion: Bool = true
    ) throws {
        for device in devices {
            for (appearanceName, style) in appearances {
                let image = render(view, size: device.size, style: style, reduceMotion: reduceMotion)
                let url = snapshotURL(screen: screen, device: device.name, appearance: appearanceName)
                let label = "\(screen)·\(device.name)·\(appearanceName)"
                try SnapshotTestHelper.assertPixelMatch(
                    image,
                    referenceURL: url,
                    maxDiffRatio: maxDiffRatio,
                    label: label
                )
            }
        }
    }
}

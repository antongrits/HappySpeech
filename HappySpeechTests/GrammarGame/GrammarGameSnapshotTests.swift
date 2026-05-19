@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - GrammarGameSnapshotTests
//
// 16 snapshot PNG для GrammarGameView (F1-011).
// 4 режима × 2 темы × 2 устройства = 16 PNG.
// Хранятся в __Snapshots__/GrammarGame/<экран>/<device>_<appearance>.png
//
// Рендеринг: UIHostingController + UIGraphicsImageRenderer (тот же движок что
// GameTemplatesSnapshotTests). Threshold 55%: GPU-рендер нестабилен на симуляторе.

@MainActor
final class GrammarGameSnapshotTests: XCTestCase {

    // MARK: - Device matrix

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

    // MARK: - Stub interactor / router

    /// Пустой интерактор — View рендерится в состоянии isLoading=true (после инициализации),
    /// что достаточно для snapshot покрытия UI-дерева каждого режима.
    @MainActor
    private final class StubInteractor: GrammarGameBusinessLogic {
        func loadGame(_ request: GrammarGameModels.LoadGame.Request) async {}
        func presentCurrentRound(_ request: GrammarGameModels.PresentRound.Request) {}
        func evaluateAnswer(_ request: GrammarGameModels.EvaluateAnswer.Request) async {}
        func evaluateDragDrop(_ request: GrammarGameModels.DragDrop.Request) async {}
        func advanceToNextRound() async {}
        func requestExit() {}
    }

    private func stubInteractor() -> any GrammarGameBusinessLogic { StubInteractor() }
    private func stubRouter() -> GrammarGameRouter { GrammarGameRouter() }

    // MARK: - 1–4. oneMany (Один–Много)

    func test_oneMany_easy_iPhone17Pro_Light() throws {
        let view = makeView(mode: .oneMany, difficulty: .easy)
        try record(view, screen: "oneMany_easy", device: devices[1], appearance: ("Light", .light))
    }

    func test_oneMany_easy_iPhone17Pro_Dark() throws {
        let view = makeView(mode: .oneMany, difficulty: .easy)
        try record(view, screen: "oneMany_easy", device: devices[1], appearance: ("Dark", .dark))
    }

    func test_oneMany_easy_iPhoneSE_Light() throws {
        let view = makeView(mode: .oneMany, difficulty: .easy)
        try record(view, screen: "oneMany_easy", device: devices[0], appearance: ("Light", .light))
    }

    func test_oneMany_easy_iPhoneSE_Dark() throws {
        let view = makeView(mode: .oneMany, difficulty: .easy)
        try record(view, screen: "oneMany_easy", device: devices[0], appearance: ("Dark", .dark))
    }

    // MARK: - 5–8. dative (Дательный, medium)

    func test_dative_medium_iPhone17Pro_Light() throws {
        let view = makeView(mode: .dative, difficulty: .medium)
        try record(view, screen: "dative_medium", device: devices[1], appearance: ("Light", .light))
    }

    func test_dative_medium_iPhone17Pro_Dark() throws {
        let view = makeView(mode: .dative, difficulty: .medium)
        try record(view, screen: "dative_medium", device: devices[1], appearance: ("Dark", .dark))
    }

    func test_dative_medium_iPhoneSE_Light() throws {
        let view = makeView(mode: .dative, difficulty: .medium)
        try record(view, screen: "dative_medium", device: devices[0], appearance: ("Light", .light))
    }

    func test_dative_medium_iPhoneSE_Dark() throws {
        let view = makeView(mode: .dative, difficulty: .medium)
        try record(view, screen: "dative_medium", device: devices[0], appearance: ("Dark", .dark))
    }

    // MARK: - 9–12. genitive (Родительный, hard)

    func test_genitive_hard_iPhone17Pro_Light() throws {
        let view = makeView(mode: .genitive, difficulty: .hard)
        try record(view, screen: "genitive_hard", device: devices[1], appearance: ("Light", .light))
    }

    func test_genitive_hard_iPhone17Pro_Dark() throws {
        let view = makeView(mode: .genitive, difficulty: .hard)
        try record(view, screen: "genitive_hard", device: devices[1], appearance: ("Dark", .dark))
    }

    func test_genitive_hard_iPhoneSE_Light() throws {
        let view = makeView(mode: .genitive, difficulty: .hard)
        try record(view, screen: "genitive_hard", device: devices[0], appearance: ("Light", .light))
    }

    func test_genitive_hard_iPhoneSE_Dark() throws {
        let view = makeView(mode: .genitive, difficulty: .hard)
        try record(view, screen: "genitive_hard", device: devices[0], appearance: ("Dark", .dark))
    }

    // MARK: - 13–16. instrumental easy (party_mode=false для easy)

    func test_instrumental_easy_iPhone17Pro_Light() throws {
        let view = makeView(mode: .instrumental, difficulty: .easy)
        try record(view, screen: "instrumental_easy", device: devices[1], appearance: ("Light", .light))
    }

    func test_instrumental_easy_iPhone17Pro_Dark() throws {
        let view = makeView(mode: .instrumental, difficulty: .easy)
        try record(view, screen: "instrumental_easy", device: devices[1], appearance: ("Dark", .dark))
    }

    func test_instrumental_easy_iPhoneSE_Light() throws {
        let view = makeView(mode: .instrumental, difficulty: .easy)
        try record(view, screen: "instrumental_easy", device: devices[0], appearance: ("Light", .light))
    }

    func test_instrumental_easy_iPhoneSE_Dark() throws {
        let view = makeView(mode: .instrumental, difficulty: .easy)
        try record(view, screen: "instrumental_easy", device: devices[0], appearance: ("Dark", .dark))
    }

    // MARK: - View factory

    private func makeView(mode: GrammarGameMode, difficulty: GrammarDifficulty) -> some View {
        GrammarGameView(
            mode: mode,
            difficulty: difficulty,
            childId: "snap-child",
            interactor: stubInteractor(),
            router: stubRouter()
        )
    }

    // MARK: - Rendering engine

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle
    ) -> UIImage {
        SnapshotTestHelper.renderView(view, size: size, style: style)
    }

    private func snapshotURL(
        screen: String,
        device: String,
        appearance: String
    ) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "GrammarGame",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    private func record<V: View>(
        _ view: V,
        screen: String,
        device: DeviceConfig,
        appearance: (String, UIUserInterfaceStyle)
    ) throws {
        let (appearanceName, style) = appearance
        let image = render(view, size: device.size, style: style)
        let url = snapshotURL(screen: screen, device: device.name, appearance: appearanceName)
        let label = "\(screen)·\(device.name)·\(appearanceName)"
        try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
    }
}

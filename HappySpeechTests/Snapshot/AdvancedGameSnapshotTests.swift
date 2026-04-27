@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - AdvancedGameSnapshotTests
//
// M10.2 — Snapshot-тесты для дополнительных игровых шаблонов.
// Матрица: 8 шаблонов × 2 девайса × 2 темы = 32 PNG.
//
// Покрывает игровые шаблоны, не вошедшие в GameTemplatesSnapshotTests.
//
// Хранение: __Snapshots__/AdvancedGames/

@MainActor
final class AdvancedGameSnapshotTests: XCTestCase {

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

    private func stubActivity(_ type: GameType) -> SessionActivity {
        SessionActivity(
            id: "adv-\(type.rawValue)",
            gameType: type,
            lessonId: "lesson-adv",
            soundTarget: "Р",
            difficulty: 2,
            isCompleted: false,
            score: nil
        )
    }

    // MARK: - 1. ArticulationImitationView

    func test_articulationImitation_bothThemes() throws {
        let activity = stubActivity(.articulationImitation)
        let view = ArticulationImitationView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try record(view, screen: "AdvancedGame_ArticulationImitation")
    }

    // MARK: - 2. RepeatAfterModelView

    func test_repeatAfterModel_bothThemes() throws {
        let activity = stubActivity(.repeatAfterModel)
        let view = RepeatAfterModelView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try record(view, screen: "AdvancedGame_RepeatAfterModel")
    }

    // MARK: - 3. ListenAndChooseView (difficulty = 3)

    func test_listenAndChoose_hard_bothThemes() throws {
        let activity = SessionActivity(
            id: "adv-lac-hard",
            gameType: .listenAndChoose,
            lessonId: "lesson-hard",
            soundTarget: "Ш",
            difficulty: 3,
            isCompleted: false,
            score: nil
        )
        let view = ListenAndChooseView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try record(view, screen: "AdvancedGame_ListenChooseHard")
    }

    // MARK: - 4. SortingView (difficulty = 3)

    func test_sorting_hard_bothThemes() throws {
        let activity = SessionActivity(
            id: "adv-sort-hard",
            gameType: .sorting,
            lessonId: "lesson-sort",
            soundTarget: "З",
            difficulty: 3,
            isCompleted: false,
            score: nil
        )
        let view = SortingView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try record(view, screen: "AdvancedGame_SortingHard")
    }

    // MARK: - 5. BingoView (difficulty = 2)

    func test_bingo_mid_bothThemes() throws {
        let activity = stubActivity(.bingo)
        let view = BingoView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try record(view, screen: "AdvancedGame_BingoMid")
    }

    // MARK: - 6. MemoryView (difficulty = 3)

    func test_memory_hard_bothThemes() throws {
        let activity = SessionActivity(
            id: "adv-mem-hard",
            gameType: .memory,
            lessonId: "lesson-mem",
            soundTarget: "Л",
            difficulty: 3,
            isCompleted: false,
            score: nil
        )
        let view = MemoryView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try record(view, screen: "AdvancedGame_MemoryHard")
    }

    // MARK: - 7. MinimalPairsView (difficulty = 2)

    func test_minimalPairs_mid_bothThemes() throws {
        let activity = stubActivity(.minimalPairs)
        let view = MinimalPairsView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try record(view, screen: "AdvancedGame_MinimalPairsMid")
    }

    // MARK: - 8. VisualAcousticView (difficulty = 2)

    func test_visualAcoustic_mid_bothThemes() throws {
        let activity = stubActivity(.visualAcoustic)
        let view = VisualAcousticView(activity: activity, onComplete: { _ in })
            .environment(AppContainer.preview())
        try record(view, screen: "AdvancedGame_VisualAcousticMid")
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
            category: "AdvancedGames",
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

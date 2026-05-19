@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - SpecialistSnapshotTests
//
// M10.2 — Snapshot-тесты для специалистского контура.
// Матрица: 6 экранов × 2 девайса × 2 темы = 24 PNG.
//
// Хранение: __Snapshots__/Specialist/

@MainActor
final class SpecialistSnapshotTests: XCTestCase {

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

    // MARK: - 1. SpecialistHomeView

    func test_specialistHome_bothThemes() throws {
        let view = SpecialistHomeView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        // maxDiffRatio=0.2: SpecialistHomeView показывает динамические виджеты
        // (даты, графики, статистика учеников) — покадровый drift до ~14.5%.
        try record(view, screen: "SpecialistHomeSnap", maxDiffRatio: 0.2)
    }

    // MARK: - 2. SpecialistReportsView

    func test_specialistReports_bothThemes() throws {
        let view = SpecialistReportsView()
            .environment(AppContainer.preview())
        try record(view, screen: "SpecialistReportsSnap")
    }

    // MARK: - 3. SessionReviewView

    func test_sessionReview_bothThemes() throws {
        let view = SessionReviewView(sessionId: "sess-1")
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
        try record(view, screen: "SessionReviewSnap")
    }

    // MARK: - 4. ProgramEditorView

    func test_programEditor_bothThemes() throws {
        let view = ProgramEditorView(
            childId: "preview-child-1",
            onSaved: { _ in },
            onCancel: {}
        )
        .environment(AppContainer.preview())
        try record(view, screen: "ProgramEditorSnap")
    }

    // MARK: - 5. ScreeningView (step 1)

    func test_screeningView_bothThemes() throws {
        let view = ScreeningView(
            childId: "snap-child",
            childAge: 6,
            onFinish: { _ in },
            onCancel: {}
        )
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
        try record(view, screen: "ScreeningViewSnap2")
    }

    // MARK: - 6. RoleSelectView

    func test_roleSelect_bothThemes() throws {
        let view = RoleSelectView()
            .environment(AppCoordinator())
            .environment(AppContainer.preview())
        try record(view, screen: "RoleSelectSnap")
    }

    // MARK: - Rendering engine

    private func render<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) -> UIImage {
            SnapshotTestHelper.renderView(view, size: size, style: style)
    }

    private func snapshotURL(screen: String, device: String, appearance: String) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "Specialist",
            screen: screen,
            device: device,
            appearance: appearance
        )
    }

    private func record<V: View>(
        _ view: V,
        screen: String,
        maxDiffRatio: Double = SnapshotTestHelper.defaultMaxDiffRatio
    ) throws {
        for device in devices {
            for (appearanceName, style) in appearances {
                let image = render(view, size: device.size, style: style)
                let url = snapshotURL(screen: screen, device: device.name, appearance: appearanceName)
                let label = "\(screen)·\(device.name)·\(appearanceName)"
                try SnapshotTestHelper.assertPixelMatch(
                    image, referenceURL: url, maxDiffRatio: maxDiffRatio, label: label
                )
            }
        }
    }
}

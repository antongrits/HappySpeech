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
        try record(view, screen: "SpecialistHomeSnap")
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
            category: "Specialist",
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

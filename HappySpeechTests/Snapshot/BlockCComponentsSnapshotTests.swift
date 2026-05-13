@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - BlockCComponentsSnapshotTests
//
// Block AB v21 — snapshot-тесты компонентов DesignSystem после Block C (эмодзи → SF Symbols).
//
// Покрытые компоненты:
//   1. LyalyaMascotView — 5 состояний × 2 темы (post-emoji-purge fallbackSFSymbol)
//   2. HSCustomAlertView — 3 варианта × 2 темы (symbol, mascot, no-illustration)
//   3. HSOnboardingParallax — первая страница × 2 темы × 2 устройства
//
// Хранение: __Snapshots__/BlockCComponents/
// Итог: (10 + 6 + 4) = 20 PNG референсов.
//
// Перегенерировать: удали __Snapshots__/BlockCComponents/ и перезапусти тесты.

@MainActor
final class BlockCComponentsSnapshotTests: XCTestCase {

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark", .dark)
    ]

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }

    private let devices: [DeviceConfig] = [
        DeviceConfig(name: "iPhoneSE3",   size: CGSize(width: 375, height: 667)),
        DeviceConfig(name: "iPhone17Pro", size: CGSize(width: 402, height: 874))
    ]

    // MARK: - 1. LyalyaMascotView — 5 состояний post-emoji-purge

    func test_lyalya_idle_bothThemes() throws {
        try recordLyalya(state: .idle, name: "idle")
    }

    func test_lyalya_celebrating_bothThemes() throws {
        try recordLyalya(state: .celebrating, name: "celebrating")
    }

    func test_lyalya_thinking_bothThemes() throws {
        try recordLyalya(state: .thinking, name: "thinking")
    }

    func test_lyalya_waving_bothThemes() throws {
        try recordLyalya(state: .waving, name: "waving")
    }

    func test_lyalya_encouraging_bothThemes() throws {
        try recordLyalya(state: .encouraging, name: "encouraging")
    }

    // MARK: - 2. HSCustomAlertView — 3 варианта

    func test_customAlert_withSFSymbol_bothThemes() throws {
        let item = HSAlertItem(
            title: "Сохранить прогресс?",
            message: "Урок ещё не закончен.",
            symbol: "checkmark.circle.fill",
            primary: HSAlertAction(title: "Сохранить", role: .primary, action: {}),
            secondary: HSAlertAction(title: "Отмена", role: .cancel, action: {})
        )
        let view = HSCustomAlertView(item: item, onDismiss: {})
            .frame(width: 375, height: 667)
        try recordComponent(view, name: "HSCustomAlert_symbol")
    }

    func test_customAlert_withMascot_bothThemes() throws {
        let item = HSAlertItem(
            title: "Молодец!",
            message: "Ты выполнил задание отлично.",
            mascot: .celebrating,
            primary: HSAlertAction(title: "Продолжить", role: .primary, action: {})
        )
        let view = HSCustomAlertView(item: item, onDismiss: {})
            .frame(width: 375, height: 667)
        try recordComponent(view, name: "HSCustomAlert_mascot")
    }

    func test_customAlert_destructive_bothThemes() throws {
        let item = HSAlertItem(
            title: "Удалить прогресс?",
            message: "Это действие нельзя отменить.",
            symbol: "trash.fill",
            primary: HSAlertAction(title: "Удалить", role: .destructive, action: {}),
            secondary: HSAlertAction(title: "Отмена", role: .cancel, action: {})
        )
        let view = HSCustomAlertView(item: item, onDismiss: {})
            .frame(width: 375, height: 667)
        try recordComponent(view, name: "HSCustomAlert_destructive")
    }

    // MARK: - 3. HSOnboardingParallax — первая страница

    func test_onboardingParallax_firstPage_bothDevices() throws {
        let pages: [HSOnboardingParallax.Page] = [
            HSOnboardingParallax.Page(
                imageName: "onboarding-welcome",
                title: "Привет! Я Ляля!",
                subtitle: "Будем учиться говорить вместе",
                mascotState: .waving
            )
        ]
        let view = HSOnboardingParallax(pages: pages, onFinish: {})

        for device in devices {
            for (appearanceName, style) in appearances {
                let image = renderView(view, size: device.size, style: style)
                let url = snapshotURL(
                    category: "BlockCComponents",
                    name: "HSOnboardingParallax_page1",
                    device: device.name,
                    appearance: appearanceName
                )
                let label = "HSOnboardingParallax_page1·\(device.name)·\(appearanceName)"
                try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
            }
        }
    }

    // MARK: - Rendering helpers

    private func renderView<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) -> UIImage {
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

    private func recordLyalya(state: LyalyaState, name: String) throws {
        let renderSize = CGSize(width: 200, height: 200)
        for (appearanceName, style) in appearances {
            let view = LyalyaMascotView(state: state, size: 160)
                .frame(width: renderSize.width, height: renderSize.height)
                .background(style == .dark ? Color.black : Color.white)
            let image = renderView(view, size: renderSize, style: style)
            let url = SnapshotTestHelper.snapshotURL(
                testClass: Self.self,
                category: "BlockCComponents",
                name: "LyalyaMascot_\(name)",
                appearance: appearanceName
            )
            let label = "LyalyaMascot_\(name)·\(appearanceName)"
            try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
        }
    }

    private func recordComponent<V: View>(_ view: V, name: String) throws {
        let size = CGSize(width: 375, height: 667)
        for (appearanceName, style) in appearances {
            let image = renderView(view, size: size, style: style)
            let url = SnapshotTestHelper.snapshotURL(
                testClass: Self.self,
                category: "BlockCComponents",
                name: name,
                appearance: appearanceName
            )
            let label = "\(name)·\(appearanceName)"
            try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
        }
    }

    private func snapshotURL(
        category: String,
        name: String,
        device: String,
        appearance: String
    ) -> URL {
        let dir = SnapshotTestHelper.snapshotsBaseDir
            .appendingPathComponent(category)
            .appendingPathComponent("\(name)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(device)_\(appearance).png")
    }
}

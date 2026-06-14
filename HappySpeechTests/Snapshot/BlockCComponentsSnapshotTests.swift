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
//
// Хранение: __Snapshots__/BlockCComponents/
// Итог: (10 + 6) = 16 PNG референсов.
//
// Перегенерировать: удали __Snapshots__/BlockCComponents/ и перезапусти тесты.

@MainActor
final class BlockCComponentsSnapshotTests: XCTestCase {

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark", .dark)
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

    // MARK: - Rendering helpers

    private func renderView<V: View>(_ view: V, size: CGSize, style: UIUserInterfaceStyle) -> UIImage {
            SnapshotTestHelper.renderView(view, size: size, style: style)
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
}

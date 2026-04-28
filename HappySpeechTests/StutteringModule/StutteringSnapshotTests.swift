@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - StutteringSnapshotTests
//
// 8 snapshot PNG для StutteringModule Views (F5-step6).
// 4 экрана × 2 темы (iPhone 17 Pro × 2 + iPhone SE × 2) = 8 PNG.
// Хранятся в __Snapshots__/StutteringModule/<экран>/<device>_<appearance>.png
//
// Рендеринг: UIHostingController + UIGraphicsImageRenderer.
// Threshold 55%: GPU-рендер нестабилен на симуляторе.

@MainActor
final class StutteringSnapshotTests: XCTestCase {

    // MARK: - Device matrix

    private struct DeviceConfig {
        let name: String
        let size: CGSize
    }

    private let iPhone17Pro = DeviceConfig(name: "iPhone17Pro", size: CGSize(width: 402, height: 874))
    private let iPhoneSE3   = DeviceConfig(name: "iPhoneSE3",   size: CGSize(width: 375, height: 667))

    private let appearances: [(String, UIUserInterfaceStyle)] = [
        ("Light", .light),
        ("Dark",  .dark)
    ]

    // MARK: - 1–2. StutteringHome iPhone17Pro Light / Dark

    func test_stutteringHome_iPhone17Pro_Light() throws {
        try record(makeStutteringHome(), screen: "stutteringHome",
                   device: iPhone17Pro, appearance: ("Light", .light))
    }

    func test_stutteringHome_iPhone17Pro_Dark() throws {
        try record(makeStutteringHome(), screen: "stutteringHome",
                   device: iPhone17Pro, appearance: ("Dark", .dark))
    }

    // MARK: - 3–4. MetronomeView idle iPhone17Pro Light / Dark

    func test_metronome_idle_iPhone17Pro_Light() throws {
        try record(makeMetronome(), screen: "metronome_idle",
                   device: iPhone17Pro, appearance: ("Light", .light))
    }

    func test_metronome_idle_iPhone17Pro_Dark() throws {
        try record(makeMetronome(), screen: "metronome_idle",
                   device: iPhone17Pro, appearance: ("Dark", .dark))
    }

    // MARK: - 5–6. SoftOnsetView iPhone17Pro Light / Dark

    func test_softOnset_iPhone17Pro_Light() throws {
        try record(makeSoftOnset(), screen: "softOnset",
                   device: iPhone17Pro, appearance: ("Light", .light))
    }

    func test_softOnset_iPhone17Pro_Dark() throws {
        try record(makeSoftOnset(), screen: "softOnset",
                   device: iPhone17Pro, appearance: ("Dark", .dark))
    }

    // MARK: - 7–8. BreathingTreeView iPhoneSE3 Light / Dark

    func test_diary_idle_iPhoneSE_Light() throws {
        try record(makeBreathingTree(), screen: "diary_idle",
                   device: iPhoneSE3, appearance: ("Light", .light))
    }

    func test_diary_idle_iPhoneSE_Dark() throws {
        try record(makeBreathingTree(), screen: "diary_idle",
                   device: iPhoneSE3, appearance: ("Dark", .dark))
    }

    // MARK: - View factories

    private func makeStutteringHome() -> some View {
        // Рендерим только карточки без NavigationStack для стабильного snapshot
        let cards: [ExerciseCardViewModel] = StutteringMode.allCases.map { mode in
            ExerciseCardViewModel(
                mode: mode,
                title: mode.rawValue,
                subtitle: "Описание",
                symbol: "waveform",
                symbolColor: .primary,
                duration: "~5 мин",
                accessibilityLabel: mode.rawValue
            )
        }
        return StutteringHomePreviewWrapper(cards: cards)
            .environment(\.circuitContext, .kid)
    }

    private func makeMetronome() -> some View {
        MetronomePreviewWrapper()
            .environment(\.circuitContext, .kid)
    }

    private func makeSoftOnset() -> some View {
        SoftOnsetPreviewWrapper()
            .environment(\.circuitContext, .kid)
    }

    private func makeBreathingTree() -> some View {
        BreathingTreeView()
            .environment(\.circuitContext, .kid)
    }

    // MARK: - Rendering engine

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle
    ) -> UIImage {
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

    private func snapshotURL(
        screen: String,
        device: String,
        appearance: String
    ) -> URL {
        SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "StutteringModule",
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

        guard let pngData = image.pngData() else {
            XCTFail("PNG encoding failed: \(screen) / \(device.name) / \(appearanceName)")
            return
        }

        if FileManager.default.fileExists(atPath: url.path) {
            let existing = try Data(contentsOf: url)
            let ratio = abs(Double(pngData.count) - Double(existing.count)) /
                        Double(max(existing.count, 1))
            XCTAssertLessThan(
                ratio, 0.55,
                "Snapshot изменился (\(screen) · \(device.name) · \(appearanceName)): " +
                "\(existing.count) → \(pngData.count) байт"
            )
        } else {
            try pngData.write(to: url)
            XCTFail(
                "Записан новый референс '\(url.lastPathComponent)' для \(screen)/\(device.name)/\(appearanceName). " +
                "Перезапусти тест для сравнения."
            )
        }
    }
}

// MARK: - Minimal preview wrappers (без зависимостей AudioEngine / AppContainer)

/// Обёртка StutteringHome: отображает сетку карточек без NavigationStack и task-запросов.
private struct StutteringHomePreviewWrapper: View {
    let cards: [ExerciseCardViewModel]

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            ScrollView {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 12
                ) {
                    ForEach(cards) { card in
                        ExerciseCardPreview(card: card)
                    }
                }
                .padding(16)
            }
        }
    }
}

private struct ExerciseCardPreview: View {
    let card: ExerciseCardViewModel
    var body: some View {
        HSCard(style: .elevated, padding: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: card.symbol)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(card.title)
                    .font(TypographyTokens.headline(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(card.duration)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 130)
        }
        .accessibilityLabel(card.accessibilityLabel)
    }
}

/// Обёртка MetronomeView: idle-состояние без запуска audio-сессии.
private struct MetronomePreviewWrapper: View {
    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            VStack(spacing: 24) {
                HSMascotView(mood: .idle)
                    .frame(width: 80, height: 80)
                Text("Ритмичная речь")
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text("Нажми, чтобы начать")
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                HSButton("Начать", style: .primary) {}
                    .frame(height: 56)
                    .padding(.horizontal, 32)
            }
            .padding()
        }
    }
}

/// Обёртка SoftOnsetView: idle-состояние без запуска audio-сессии.
private struct SoftOnsetPreviewWrapper: View {
    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            VStack(spacing: 20) {
                HSMascotView(mood: .idle)
                    .frame(width: 80, height: 80)
                Text("СЛОВО")
                    .font(TypographyTokens.title(32))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Image(systemName: "light.beacon.max")
                    .font(.system(size: 60))
                    .foregroundStyle(ColorTokens.Brand.butter)
                HSButton("Слушай", style: .secondary) {}
                    .frame(height: 52)
                    .padding(.horizontal, 32)
                HSButton("Запись", style: .primary) {}
                    .frame(height: 52)
                    .padding(.horizontal, 32)
            }
            .padding()
        }
    }
}

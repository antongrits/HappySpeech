@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - CustomizationSnapshotTests
//
// 8 snapshot PNG для CustomizationView (F2-011).
// 5 скинов × 1 тема (light, default color=warm) = 5 PNG
// 3 цвета × 1 тема (light, default skin=classic) = 3 PNG — но warm уже покрыт
// Итого 5 (skins) + 2 (cool + nature) + 1 (dark cross-check) = 8 PNG
//
// Рендеринг: UIHostingController + UIGraphicsImageRenderer (тот же движок что GrammarGameSnapshotTests).
// Устройство: iPhone 17 Pro (402×874).
// Threshold 55%: GPU-рендер нестабилен на симуляторе.

@MainActor
final class CustomizationSnapshotTests: XCTestCase {

    // MARK: - Device

    private let deviceSize = CGSize(width: 402, height: 874)
    private let deviceName = "iPhone17Pro"

    // MARK: - 1. skin classic + color warm (default state)

    func test_skin_classic_warm() throws {
        try record(
            view: makeView(skin: .classic, color: .warm),
            screen: "skin_classic_warm",
            appearance: ("Light", .light)
        )
    }

    // MARK: - 2. skin princess + color warm

    func test_skin_princess_warm() throws {
        try record(
            view: makeView(skin: .princess, color: .warm),
            screen: "skin_princess_warm",
            appearance: ("Light", .light)
        )
    }

    // MARK: - 3. skin scientist + color warm

    func test_skin_scientist_warm() throws {
        try record(
            view: makeView(skin: .scientist, color: .warm),
            screen: "skin_scientist_warm",
            appearance: ("Light", .light)
        )
    }

    // MARK: - 4. skin athlete + color warm

    func test_skin_athlete_warm() throws {
        try record(
            view: makeView(skin: .athlete, color: .warm),
            screen: "skin_athlete_warm",
            appearance: ("Light", .light)
        )
    }

    // MARK: - 5. skin artist + color warm

    func test_skin_artist_warm() throws {
        try record(
            view: makeView(skin: .artist, color: .warm),
            screen: "skin_artist_warm",
            appearance: ("Light", .light)
        )
    }

    // MARK: - 6. skin classic + color cool

    func test_skin_classic_cool() throws {
        try record(
            view: makeView(skin: .classic, color: .cool),
            screen: "skin_classic_cool",
            appearance: ("Light", .light)
        )
    }

    // MARK: - 7. skin classic + color nature

    func test_skin_classic_nature() throws {
        try record(
            view: makeView(skin: .classic, color: .nature),
            screen: "skin_classic_nature",
            appearance: ("Light", .light)
        )
    }

    // MARK: - 8. skin classic + color warm, dark mode (cross-check)

    func test_skin_classic_dark() throws {
        try record(
            view: makeView(skin: .classic, color: .warm),
            screen: "skin_classic_warm",
            appearance: ("Dark", .dark)
        )
    }

    // MARK: - View factory

    /// Создаёт CustomizationView в «frozen» состоянии (без bootstrap — только статичный ViewModel).
    /// Использует CustomizationPreviewWrapper чтобы передать viewModel напрямую в Display,
    /// минуя bootstrap() который требует AppContainer + Realm.
    private func makeView(
        skin: LyalyaSkin,
        color: LyalyaColorVariant,
        voice: LyalyaVoice = .classic
    ) -> some View {
        CustomizationSnapshotWrapper(
            viewModel: CustomizationViewModel(
                selectedSkin: skin,
                selectedColor: color,
                selectedVoice: voice,
                isSaving: false,
                isUnchanged: true
            )
        )
        .environment(AppContainer.preview())
        .environment(\.circuitContext, .parent)
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

    private func record<V: View>(
        view: V,
        screen: String,
        appearance: (String, UIUserInterfaceStyle)
    ) throws {
        let (appearanceName, style) = appearance
        let image = render(view, size: deviceSize, style: style)
        let url = SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "Customization",
            screen: screen,
            device: deviceName,
            appearance: appearanceName
        )

        guard let pngData = image.pngData() else {
            XCTFail("PNG encoding failed: \(screen) / \(deviceName) / \(appearanceName)")
            return
        }

        if FileManager.default.fileExists(atPath: url.path) {
            let existing = try Data(contentsOf: url)
            let ratio = abs(Double(pngData.count) - Double(existing.count)) /
                        Double(max(existing.count, 1))
            XCTAssertLessThan(
                ratio, 0.55,
                "Snapshot изменился (\(screen) · \(deviceName) · \(appearanceName)): " +
                "\(existing.count) → \(pngData.count) байт"
            )
        } else {
            try pngData.write(to: url)
            XCTFail(
                "Записан новый референс '\(url.lastPathComponent)' для \(screen)/\(deviceName)/\(appearanceName). " +
                "Перезапусти тест для сравнения."
            )
        }
    }
}

// MARK: - CustomizationSnapshotWrapper

/// Обёртка для snapshot тестов: рендерит Customization UI с заданным ViewModel
/// без запуска bootstrap() (нет обращения к Realm/Firebase).
private struct CustomizationSnapshotWrapper: View {
    let viewModel: CustomizationViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ColorTokens.Kid.bg.ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        mascotHeader
                        sectionTitle("Костюм")
                        skinsSection
                        sectionTitle("Цвет фона")
                        colorsSection
                        sectionTitle("Голос")
                        voiceSection
                        saveButton
                    }
                }
            }
            .navigationTitle("Мой образ")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private var mascotHeader: some View {
        let (gradFrom, gradTo) = viewModel.selectedColor.gradientColors
        return ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(
                    LinearGradient(colors: [gradFrom, gradTo],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 240, height: 240)

            LyalyaMascotView(state: .idle, size: 200)
                .id(viewModel.selectedSkin.rawValue)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.medium)
        .padding(.bottom, SpacingTokens.large)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Kid.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.top, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.tiny)
    }

    private var skinsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(LyalyaSkin.allCases) { skin in
                    skinCard(skin: skin, isSelected: viewModel.selectedSkin == skin)
                }
            }
            .padding(.horizontal, SpacingTokens.regular)
        }
        .frame(height: 180)
        .padding(.bottom, SpacingTokens.regular)
    }

    private func skinCard(skin: LyalyaSkin, isSelected: Bool) -> some View {
        VStack(spacing: SpacingTokens.tiny) {
            ZStack {
                placeholderGradient(for: skin)
                    .frame(width: 80, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous))
                Image(systemName: "figure.stand")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(ColorTokens.Brand.primary)
                                .background(Circle().fill(Color.white).padding(-2))
                                .padding(SpacingTokens.sp1)
                        }
                        Spacer()
                    }
                    .frame(width: 80, height: 100)
                }
            }
            Text(skin.localizedName)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
        }
        .frame(width: 120, height: 160)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(isSelected
                      ? ColorTokens.Brand.primary.opacity(0.12)
                      : ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .strokeBorder(isSelected ? ColorTokens.Brand.primary : Color.clear, lineWidth: 2)
                )
        )
    }

    private func placeholderGradient(for skin: LyalyaSkin) -> some View {
        let from: Color
        let to: Color
        switch skin {
        case .classic:   from = Color(red: 0.72, green: 0.87, blue: 0.98); to = Color(red: 0.50, green: 0.72, blue: 0.92)
        case .princess:  from = Color(red: 1.00, green: 0.75, blue: 0.85); to = Color(red: 0.95, green: 0.55, blue: 0.70)
        case .scientist: from = Color(red: 0.85, green: 0.95, blue: 0.85); to = Color(red: 0.65, green: 0.88, blue: 0.65)
        case .athlete:   from = Color(red: 1.00, green: 0.88, blue: 0.65); to = Color(red: 0.95, green: 0.70, blue: 0.35)
        case .artist:    from = Color(red: 0.90, green: 0.75, blue: 0.95); to = Color(red: 0.75, green: 0.55, blue: 0.90)
        }
        return LinearGradient(colors: [from, to], startPoint: .top, endPoint: .bottom)
    }

    private var colorsSection: some View {
        HStack(spacing: SpacingTokens.regular) {
            ForEach(LyalyaColorVariant.allCases) { variant in
                ZStack {
                    Circle()
                        .fill(variant.previewGradient)
                        .frame(width: 44, height: 44)
                    if viewModel.selectedColor == variant {
                        Circle()
                            .strokeBorder(ColorTokens.Brand.primary, lineWidth: 3)
                            .frame(width: 52, height: 52)
                    }
                }
                .frame(width: 56, height: 56)
                .accessibilityLabel(variant.localizedName)
            }
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.bottom, SpacingTokens.regular)
    }

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LyalyaVoice.allCases) { voice in
                HStack(spacing: SpacingTokens.small) {
                    ZStack {
                        Circle()
                            .strokeBorder(
                                viewModel.selectedVoice == voice
                                    ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                lineWidth: 2
                            )
                            .frame(width: 24, height: 24)
                        if viewModel.selectedVoice == voice {
                            Circle().fill(ColorTokens.Brand.primary).frame(width: 14, height: 14)
                        }
                    }
                    Text(voice.localizedName)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Spacer()
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                .frame(minHeight: 56)
                .padding(.horizontal, SpacingTokens.regular)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .fill(viewModel.selectedVoice == voice
                              ? ColorTokens.Brand.primary.opacity(0.08) : Color.clear)
                )
                .padding(.horizontal, SpacingTokens.small)
                .padding(.bottom, SpacingTokens.tiny)
            }
        }
        .padding(.bottom, SpacingTokens.regular)
    }

    private var saveButton: some View {
        HSButton("Сохранить", style: .primary, size: .large, isLoading: false) {}
            .disabled(viewModel.isUnchanged)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.medium)
    }
}

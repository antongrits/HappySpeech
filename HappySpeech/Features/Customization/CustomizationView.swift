import OSLog
import SwiftUI

// MARK: - CustomizationView

/// Экран кастомизации Ляли (Plan v9, Блок F2).
/// Parent-контур: точка входа из Settings.
/// Содержит: preview Ляли, секцию костюмов, цветовую палитру, голос, CTA «Сохранить».
struct CustomizationView: View {

    // MARK: - Environment

    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - VIP State

    @State private var display = CustomizationDisplay()
    @State private var interactor: CustomizationInteractor?
    @State private var bootstrapped = false

    // MARK: - Local UI state

    @State private var lyalyaState: LyalyaState = .idle

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CustomizationView")

    // MARK: - Convenience

    private var viewModel: CustomizationViewModel { display.viewModel }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            ColorTokens.Kid.bg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    mascotHeader
                    sectionTitle(String(localized: "customization.section.skins"))
                    skinsSection
                    sectionTitle(String(localized: "customization.section.colors"))
                    colorsSection
                    sectionTitle(String(localized: "customization.section.voice"))
                    voiceSection
                    saveButton
                }
            }

            if let toast = viewModel.toastMessage {
                HSToast(toast, type: viewModel.toastIsError ? .error : .success)
                    .padding(.bottom, SpacingTokens.large)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task(id: toast) {
                        try? await Task.sleep(for: .seconds(2.6))
                        withAnimation(.easeInOut(duration: 0.25)) {
                            display.viewModel.toastMessage = nil
                        }
                    }
            }
        }
        .navigationTitle(String(localized: "customization.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await bootstrap() }
        .onDisappear {
            interactor?.stopVoicePreview()
        }
    }

    // MARK: - Header: Ляля preview

    private var mascotHeader: some View {
        let (gradFrom, gradTo) = viewModel.selectedColor.gradientColors
        return ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(
                    LinearGradient(colors: [gradFrom, gradTo],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .frame(width: 240, height: 240)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.25),
                           value: viewModel.selectedColor)

            LyalyaMascotView(state: lyalyaState, size: mascotSize)
                .id(viewModel.selectedSkin.rawValue)
                .transition(reduceMotion
                            ? .opacity
                            : .scale(scale: 0.85).combined(with: .opacity))
                .animation(reduceMotion ? .linear(duration: 0.3) : MotionTokens.spring,
                           value: viewModel.selectedSkin)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.medium)
        .padding(.bottom, SpacingTokens.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(format: String(localized: "customization.a11y.preview"),
                                   viewModel.selectedSkin.localizedName,
                                   viewModel.selectedColor.localizedName))
    }

    // MARK: - Section title

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Kid.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.top, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.tiny)
    }

    // MARK: - Skins section

    private var skinsSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(LyalyaSkin.allCases) { skin in
                    SkinCard(
                        skin: skin,
                        isSelected: viewModel.selectedSkin == skin
                    )
                    .onTapGesture {
                        withAnimation(reduceMotion ? .linear(duration: 0.3) : MotionTokens.spring) {
                            interactor?.selectSkin(.init(skin: skin))
                        }
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.regular)
        }
        .frame(height: skinScrollHeight)
        .padding(.bottom, SpacingTokens.regular)
    }

    // MARK: - Colors section

    private var colorsSection: some View {
        HStack(spacing: SpacingTokens.regular) {
            ForEach(LyalyaColorVariant.allCases) { variant in
                ColorPaletteCircle(
                    variant: variant,
                    isSelected: viewModel.selectedColor == variant
                )
                .onTapGesture {
                    withAnimation(reduceMotion ? .linear(duration: 0.3) : .easeInOut(duration: 0.25)) {
                        interactor?.selectColor(.init(color: variant))
                    }
                }
            }
        }
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.bottom, SpacingTokens.regular)
    }

    // MARK: - Voice section

    private var voiceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(LyalyaVoice.allCases) { voice in
                VoiceRow(
                    voice: voice,
                    isSelected: viewModel.selectedVoice == voice,
                    isPlaying: viewModel.playingVoice == voice,
                    onPreviewTap: { [interactor] v in
                        interactor?.previewVoice(.init(voice: v))
                    }
                )
                .onTapGesture {
                    interactor?.selectVoice(.init(voice: voice))
                }
                .padding(.bottom, SpacingTokens.tiny)
            }
        }
        .padding(.bottom, SpacingTokens.regular)
    }

    // MARK: - Save CTA

    private var saveButton: some View {
        HSButton(
            String(localized: "customization.cta.save"),
            style: .primary,
            size: .large,
            isLoading: viewModel.isSaving
        ) {
            interactor?.saveCustomization(.init(
                skin: viewModel.selectedSkin,
                color: viewModel.selectedColor,
                voice: viewModel.selectedVoice
            ))
            triggerCelebration()
        }
        .disabled(viewModel.isUnchanged)
        .frame(maxWidth: .infinity)
        .frame(height: 56)
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.bottom, SpacingTokens.medium)
        .accessibilityLabel(String(localized: "customization.cta.save"))
        .accessibilityHint(viewModel.isUnchanged
                           ? String(localized: "customization.a11y.no_changes")
                           : String(localized: "customization.a11y.save_hint"))
    }

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // MARK: - Responsive sizing

    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    private var mascotSize: CGFloat {
        isCompactWidth ? 160 : 200
    }

    private var skinScrollHeight: CGFloat {
        isCompactWidth ? 156 : 180
    }

    // MARK: - Animation helpers

    private func triggerCelebration() {
        withAnimation(reduceMotion ? nil : MotionTokens.bounce) {
            lyalyaState = .celebrating
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { lyalyaState = .idle }
        }
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let interactor = CustomizationInteractor(
            realmActor: container.realmActor,
            authService: container.authService
        )
        let presenter = CustomizationPresenter()

        presenter.display = display
        interactor.presenter = presenter

        self.interactor = interactor

        interactor.loadCustomization(.init())
    }
}

// MARK: - SkinCard

private struct SkinCard: View {

    let skin: LyalyaSkin
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPressed = false

    private var isCompactWidth: Bool { horizontalSizeClass == .compact }

    var body: some View {
        VStack(spacing: SpacingTokens.tiny) {
            ZStack(alignment: .topTrailing) {
                skinIllustration
                    .frame(width: skinWidth, height: skinHeight)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous))

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .background(Circle().fill(Color.white).padding(-2))
                        .padding(SpacingTokens.sp1)
                }
            }

            Text(skin.localizedName)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(width: cardWidth, height: cardHeight)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(isSelected
                      ? ColorTokens.Brand.primary.opacity(0.12)
                      : ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                        .strokeBorder(
                            isSelected ? ColorTokens.Brand.primary : Color.clear,
                            lineWidth: 2
                        )
                )
        )
        .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
        .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isPressed)
        .onLongPressGesture(minimumDuration: .infinity, maximumDistance: .infinity,
                            pressing: { pressing in isPressed = pressing },
                            perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Скин: \(skin.localizedName)\(isSelected ? ", выбран" : "")")
        .accessibilityHint(String(localized: "customization.a11y.skin_card_hint"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var skinIllustration: some View {
        if UIImage(named: skin.illustrationName) != nil {
            Image(skin.illustrationName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                placeholderGradient
                Image(systemName: "figure.stand")
                    .font(.system(size: skinHeight * 0.5, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var placeholderGradient: some View {
        LinearGradient(
            colors: [placeholderFrom, placeholderTo],
            startPoint: .top, endPoint: .bottom
        )
    }

    // Placeholder gradient до получения real illustrations от designer-visual.
    // RGB-значения намеренны — ColorTokens не содержит per-skin пастельных оттенков.
    private var placeholderFrom: Color {
        switch skin {
        case .classic:    return Color(red: 0.72, green: 0.87, blue: 0.98)
        case .princess:   return Color(red: 1.00, green: 0.75, blue: 0.85)
        case .scientist:  return Color(red: 0.85, green: 0.95, blue: 0.85)
        case .athlete:    return Color(red: 1.00, green: 0.88, blue: 0.65)
        case .artist:     return Color(red: 0.90, green: 0.75, blue: 0.95)
        }
    }

    // Placeholder gradient до получения real illustrations от designer-visual.
    private var placeholderTo: Color {
        switch skin {
        case .classic:    return Color(red: 0.50, green: 0.72, blue: 0.92)
        case .princess:   return Color(red: 0.95, green: 0.55, blue: 0.70)
        case .scientist:  return Color(red: 0.65, green: 0.88, blue: 0.65)
        case .athlete:    return Color(red: 0.95, green: 0.70, blue: 0.35)
        case .artist:     return Color(red: 0.75, green: 0.55, blue: 0.90)
        }
    }

    private var cardWidth: CGFloat { isCompactWidth ? 100 : 120 }
    private var cardHeight: CGFloat { isCompactWidth ? 136 : 160 }
    private var skinWidth: CGFloat { isCompactWidth ? 66 : 80 }
    private var skinHeight: CGFloat { isCompactWidth ? 84 : 100 }
}

// MARK: - ColorPaletteCircle

private struct ColorPaletteCircle: View {

    let variant: LyalyaColorVariant
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompactWidth: Bool { horizontalSizeClass == .compact }
    private var touchTarget: CGFloat { isCompactWidth ? 48 : 56 }
    private var circleSize: CGFloat { isCompactWidth ? 40 : 44 }

    var body: some View {
        ZStack {
            Circle()
                .fill(variant.previewGradient)
                .frame(width: circleSize, height: circleSize)

            if isSelected {
                Circle()
                    .strokeBorder(ColorTokens.Brand.primary, lineWidth: 3)
                    .frame(width: circleSize + 8, height: circleSize + 8)
                    .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)
            }
        }
        .frame(width: touchTarget, height: touchTarget)
        .contentShape(Circle())
        .accessibilityLabel("\(variant.localizedName)\(isSelected ? ", выбрана" : "")")
        .accessibilityHint(String(localized: "customization.a11y.color_card_hint"))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - VoiceRow

private struct VoiceRow: View {

    let voice: LyalyaVoice
    let isSelected: Bool
    let isPlaying: Bool
    var onPreviewTap: ((LyalyaVoice) -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                        lineWidth: 2
                    )
                    .frame(width: 24, height: 24)
                if isSelected {
                    Circle()
                        .fill(ColorTokens.Brand.primary)
                        .frame(width: 14, height: 14)
                }
            }
            .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)

            Text(voice.localizedName)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.ink)

            Spacer()

            Button {
                onPreviewTap?(voice)
            } label: {
                Label(
                    String(localized: "customization.voice.preview"),
                    systemImage: isPlaying ? "stop.circle.fill" : "play.circle.fill"
                )
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Brand.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            }
            .frame(minWidth: 56, minHeight: 44)
            .accessibilityLabel(String(format: String(localized: "customization.a11y.voice_preview"),
                                       voice.localizedName))
            .accessibilityHint(isPlaying ? "Нажмите чтобы остановить" : "Нажмите чтобы прослушать")
        }
        .frame(minHeight: 56)
        .padding(.horizontal, SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(isSelected ? ColorTokens.Brand.primary.opacity(0.08) : Color.clear)
                .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)
        )
        .padding(.horizontal, SpacingTokens.small)
        .accessibilityElement(children: .contain)
    }
}

// MARK: - Preview

#Preview("Customization – Light") {
    NavigationStack {
        CustomizationView()
            .environment(AppContainer.preview())
            .environment(\.circuitContext, .parent)
    }
}

#Preview("Customization – Dark") {
    NavigationStack {
        CustomizationView()
            .environment(AppContainer.preview())
            .environment(\.circuitContext, .parent)
            .preferredColorScheme(.dark)
    }
}

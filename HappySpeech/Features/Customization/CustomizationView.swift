import OSLog
import SwiftUI

// MARK: - CustomizationTab

enum CustomizationTab: String, CaseIterable, Identifiable {
    case outfit
    case color
    case voice
    case background

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .outfit:     return String(localized: "customization.tab.outfit")
        case .color:      return String(localized: "customization.tab.color")
        case .voice:      return String(localized: "customization.tab.voice")
        case .background: return String(localized: "customization.tab.background")
        }
    }

    var iconName: String {
        switch self {
        case .outfit:     return "tshirt"
        case .color:      return "paintpalette"
        case .voice:      return "waveform"
        case .background: return "photo.on.rectangle"
        }
    }
}

// MARK: - CustomizationView

/// Экран кастомизации Ляли.
/// Содержит: live-preview Ляли, 4 вкладки (Наряд / Цвет / Голос / Фон),
/// секцию аксессуаров, голосовой prompt Ляли, кнопки «Готово!» и «Сброс».
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

    // Fix 3.20 — стартовое состояние превью Ляли — бодрый канонический
    // вид (.happy → mascot_lyalya_happy), а не .idle (mascot_lyalya_sleep с
    // полуприкрытыми глазами), чтобы ребёнок видел весёлую Лялю.
    @State private var lyalyaState: LyalyaState = .happy
    @State private var selectedTab: CustomizationTab = .outfit
    @State private var showResetConfirm = false

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CustomizationView")

    // MARK: - Convenience

    private var viewModel: CustomizationViewModel { display.viewModel }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Fix v32-postreaudit — фиксируем ZStack по screen-bounds,
            // иначе GeometryReader в GuidedTourContainer (AppCoordinatorView)
            // оставляет ZStack схлопнутым по intrinsic size и контент
            // (live-preview Ляли, tab picker) уезжает к topLeading.
            Color.clear
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityHidden(true)

            HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                .ignoresSafeArea()
                .blendMode(.softLight)
                .accessibilityHidden(true)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    mascotHeader
                    lyalyaPromptBubble
                    tabPicker
                    tabContent
                    accessoriesSection
                    Spacer(minLength: SpacingTokens.xLarge)
                    actionButtons
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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                resetButton
            }
        }
        .confirmationDialog(
            String(localized: "customization.reset.confirm_title"),
            isPresented: $showResetConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "customization.reset.confirm_action"), role: .destructive) {
                interactor?.resetToDefault(.init())
            }
            Button(String(localized: "customization.reset.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "customization.reset.confirm_message"))
        }
        .task { await bootstrap() }
        .onDisappear {
            interactor?.viewWillDisappear()
        }
    }

    // MARK: - Header: Ляля preview

    private var mascotHeader: some View {
        let (gradFrom, gradTo) = viewModel.selectedColor.gradientColors
        return HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.medium) {
            ZStack {
                // Слой 1: реальный фон сцены (bg_<id>) за героем + цветовая
                // тонировка-градиент сверху. Фон меняется при выборе вкладки «Фон».
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [gradFrom, gradTo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 240, height: 240)
                    .overlay(
                        Image(viewModel.selectedBackground.illustrationName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 240, height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
                            .id(viewModel.selectedBackground.rawValue)
                            .transition(reduceMotion ? .opacity : .opacity)
                            .accessibilityHidden(true)
                    )
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25),
                               value: viewModel.selectedColor)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.3),
                               value: viewModel.selectedBackground)

                // Слой 2: герой. При выбранном наряде ≠ повседневный показываем
                // статичный lyalya_outfit_<id> (видимая смена одежды); иначе —
                // живой анимированный канон.
                Group {
                    if viewModel.selectedOutfit != .everyday {
                        Image(viewModel.selectedOutfit.illustrationName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: mascotSize, height: mascotSize)
                            .id("outfit-\(viewModel.selectedOutfit.rawValue)")
                    } else {
                        LyalyaMascotView(state: lyalyaState, size: mascotSize)
                            .id("skin-\(viewModel.selectedSkin.rawValue)")
                    }
                }
                .transition(reduceMotion
                    ? .opacity
                    : .scale(scale: 0.85).combined(with: .opacity))
                .animation(reduceMotion ? .linear(duration: 0.3) : MotionTokens.spring,
                           value: viewModel.selectedSkin)
                .animation(reduceMotion ? .linear(duration: 0.3) : MotionTokens.spring,
                           value: viewModel.selectedOutfit)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, SpacingTokens.regular)
        .padding(.top, SpacingTokens.medium)
        .padding(.bottom, SpacingTokens.small)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "customization.a11y.preview"),
                viewModel.selectedSkin.localizedName,
                viewModel.selectedColor.localizedName
            )
        )
    }

    // MARK: - Lyalya prompt bubble

    @ViewBuilder
    private var lyalyaPromptBubble: some View {
        if let prompt = viewModel.lyalyaPrompt {
            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.small) {
                Text(prompt)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.small)
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(reduceMotion ? nil : MotionTokens.spring, value: prompt)
            .accessibilityLabel(prompt)
        }
    }

    // MARK: - Tab picker

    private var tabPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.small) {
                ForEach(CustomizationTab.allCases) { tab in
                    CustomizationTabButton(
                        tab: tab,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(reduceMotion ? .linear(duration: 0.2) : MotionTokens.spring) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.regular)
        }
        .padding(.bottom, SpacingTokens.regular)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .outfit:
            outfitTab
        case .color:
            colorTab
        case .voice:
            voiceTab
        case .background:
            backgroundTab
        }
    }

    // MARK: - Outfit tab

    private var outfitTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(String(localized: "customization.section.outfits"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.small) {
                    ForEach(viewModel.outfitItems) { item in
                        OutfitCard(item: item) {
                            interactor?.selectOutfit(.init(outfit: item.outfit))
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.regular)
            }
            .frame(height: isCompactWidth ? 160 : 180)
            .padding(.bottom, SpacingTokens.regular)

            sectionTitle(String(localized: "customization.section.skins"))
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
    }

    // MARK: - Color tab

    private var colorTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(String(localized: "customization.section.colors"))
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

            sectionTitle(String(localized: "customization.section.hair"))
            HStack(spacing: SpacingTokens.regular) {
                ForEach(LyalyaHairColor.allCases) { hairColor in
                    ColorCircle(
                        color: hairColor.previewColor,
                        label: hairColor.localizedName,
                        isSelected: viewModel.selectedHairColor == hairColor
                    )
                    .onTapGesture {
                        interactor?.selectHairColor(.init(color: hairColor))
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.regular)

            sectionTitle(String(localized: "customization.section.eyes"))
            HStack(spacing: SpacingTokens.regular) {
                ForEach(LyalyaEyeColor.allCases) { eyeColor in
                    ColorCircle(
                        color: eyeColor.previewColor,
                        label: eyeColor.localizedName,
                        isSelected: viewModel.selectedEyeColor == eyeColor
                    )
                    .onTapGesture {
                        interactor?.selectEyeColor(.init(color: eyeColor))
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.regular)

            sectionTitle(String(localized: "customization.section.skintone"))
            HStack(spacing: SpacingTokens.regular) {
                ForEach(LyalyaSkinTone.allCases) { tone in
                    ColorCircle(
                        color: tone.previewColor,
                        label: tone.localizedName,
                        isSelected: viewModel.selectedSkinTone == tone
                    )
                    .onTapGesture {
                        interactor?.selectSkinTone(.init(tone: tone))
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.regular)
        }
    }

    // MARK: - Voice tab

    private var voiceTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(String(localized: "customization.section.voice"))
            ForEach(LyalyaVoice.allCases) { voice in
                VoiceRow(
                    voice: voice,
                    isSelected: viewModel.selectedVoice == voice,
                    isPlaying: viewModel.playingVoice == voice,
                    onPreviewTap: { [interactor] voiceArg in
                        interactor?.previewVoice(.init(voice: voiceArg))
                    }
                )
                .onTapGesture {
                    interactor?.selectVoice(.init(voice: voice))
                }
                .padding(.bottom, SpacingTokens.tiny)
            }
            .padding(.bottom, SpacingTokens.regular)
        }
    }

    // MARK: - Background tab

    private var backgroundTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle(String(localized: "customization.section.background"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.small) {
                    ForEach(viewModel.backgroundItems) { item in
                        BackgroundCard(
                            item: item,
                            isSelected: viewModel.selectedBackground == item.background
                        ) {
                            withAnimation(reduceMotion ? .linear(duration: 0.2) : MotionTokens.spring) {
                                interactor?.selectBackground(.init(background: item.background))
                            }
                        }
                    }
                }
                .padding(.horizontal, SpacingTokens.regular)
            }
            .frame(height: isCompactWidth ? 120 : 140)
            .padding(.bottom, SpacingTokens.regular)
        }
    }

    // MARK: - Accessories section (всегда видна)

    private var accessoriesSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            sectionTitle(String(localized: "customization.section.accessories"))
            HStack(spacing: SpacingTokens.small) {
                ForEach(Array(viewModel.accessoryItems.enumerated()), id: \.element.id) { index, item in
                    AccessoryToggleButton(item: item) {
                        interactor?.toggleAccessory(.init(accessory: item.accessory))
                    }
                    .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0)
                            .scaleEffect(phase.isIdentity ? 1 : 0.92)
                    }
                    .hsParallaxTile(factor: 0.15)
                    .zIndex(Double(viewModel.accessoryItems.count - index))
                }
            }
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.regular)
        }
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        VStack(spacing: SpacingTokens.small) {
            HSButton(
                String(localized: "customization.cta.save"),
                style: .primary,
                size: .large,
                isLoading: viewModel.isSaving
            ) {
                interactor?.saveCustomization(.init(
                    skin: viewModel.selectedSkin,
                    color: viewModel.selectedColor,
                    voice: viewModel.selectedVoice,
                    outfit: viewModel.selectedOutfit,
                    hairColor: viewModel.selectedHairColor,
                    eyeColor: viewModel.selectedEyeColor,
                    skinTone: viewModel.selectedSkinTone,
                    enabledAccessories: viewModel.enabledAccessories,
                    background: viewModel.selectedBackground
                ))
                triggerCelebration()
            }
            .disabled(viewModel.isUnchanged)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, SpacingTokens.regular)
            .accessibilityLabel(String(localized: "customization.cta.save"))
            .accessibilityHint(
                viewModel.isUnchanged
                    ? String(localized: "customization.a11y.no_changes")
                    : String(localized: "customization.a11y.save_hint")
            )
        }
        .padding(.bottom, SpacingTokens.medium)
    }

    // MARK: - Reset toolbar button

    private var resetButton: some View {
        Button {
            showResetConfirm = true
        } label: {
            Label(
                String(localized: "customization.cta.reset"),
                systemImage: "arrow.counterclockwise"
            )
            .font(TypographyTokens.caption(13))
        }
        .accessibilityLabel(String(localized: "customization.cta.reset"))
        .accessibilityHint(String(localized: "customization.a11y.reset_hint"))
    }

    // MARK: - Section title helper

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Kid.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpacingTokens.regular)
            .padding(.top, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.tiny)
    }

    // MARK: - Responsive sizing

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }
    private var mascotSize: CGFloat { isCompactWidth ? 160 : 200 }
    private var skinScrollHeight: CGFloat { isCompactWidth ? 156 : 180 }

    // MARK: - Animation helpers

    private func triggerCelebration() {
        withAnimation(reduceMotion ? nil : MotionTokens.bounce) {
            lyalyaState = .celebrating
        }
        Task {
            try? await Task.sleep(for: .seconds(2))
            withAnimation { lyalyaState = .happy }
        }
    }

    // MARK: - Bootstrap

    @MainActor
    private func bootstrap() async {
        guard !bootstrapped else { return }
        bootstrapped = true

        let newInteractor = CustomizationInteractor(
            realmActor: container.realmActor,
            authService: container.authService
        )
        let presenter = CustomizationPresenter()

        presenter.display = display
        newInteractor.presenter = presenter

        self.interactor = newInteractor

        newInteractor.loadCustomization(.init(
            childStreakDays: 0,
            unlockedAchievements: []
        ))
    }
}

// MARK: - Preview

#Preview("Customization — Light") {
    NavigationStack {
        CustomizationView()
            .environment(AppContainer.preview())
            .environment(\.circuitContext, .parent)
    }
}

#Preview("Customization — Dark") {
    NavigationStack {
        CustomizationView()
            .environment(AppContainer.preview())
            .environment(\.circuitContext, .parent)
            .preferredColorScheme(.dark)
    }
}

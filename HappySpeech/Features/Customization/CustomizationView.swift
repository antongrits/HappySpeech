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

            // Kid-контур: тёплый кремовый однотонный холст (#FFF8F0 light /
            // тёмный нейтрально-тёплый dark). Статичный, без softLight-оверлея,
            // соответствует эталону «Образ Ляли» (kid тёплая палитра).
            HSMeshGradientBackground(palette: .kidWarm, animated: false)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {
                    mascotHeader
                    lyalyaPromptBubble
                    tabPicker
                    tabContent
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
    //
    // Design ref: warm radial gradient card, name-tag pill (top-left),
    // shuffle-random button (top-right), Lyalya centered with glow shadow.

    private var mascotHeader: some View {
        let (gradFrom, gradTo) = viewModel.selectedColor.gradientColors
        return VStack(spacing: 0) {
                // Name tag + shuffle row
                HStack {
                    // Name tag pill (top-left)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(ColorTokens.Brand.rose)
                            .frame(width: 8, height: 8)
                            .accessibilityHidden(true)
                        Text(String(localized: "customization.preview.name", defaultValue: "Ляля"))
                            .font(TypographyTokens.caption(13).weight(.bold))
                            .foregroundStyle(ColorTokens.Kid.ink)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(ColorTokens.Kid.surface)
                            .overlay(
                                Capsule(style: .continuous)
                                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                            )
                            .shadow(color: ColorTokens.Kid.ink.opacity(0.06), radius: 4, x: 0, y: 2)
                    )

                    Spacer()

                    // Shuffle (random outfit) button (top-right)
                    Button {
                        let allOutfits = LyalyaOutfit.allCases
                        if let random = allOutfits.filter({ $0 != viewModel.selectedOutfit }).randomElement() {
                            interactor?.selectOutfit(.init(outfit: random))
                        }
                    } label: {
                        Image(systemName: "shuffle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(ColorTokens.Kid.surface)
                                    .overlay(Circle().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                                    .shadow(color: ColorTokens.Kid.ink.opacity(0.06), radius: 4, x: 0, y: 2)
                            )
                    }
                    .accessibilityLabel(
                        String(localized: "customization.a11y.shuffle", defaultValue: "Случайный наряд")
                    )
                }
                .padding(.horizontal, SpacingTokens.regular)
                .padding(.top, SpacingTokens.regular)

                // Mascot with ground glow
                ZStack(alignment: .bottom) {
                    // Ground glow
                    Ellipse()
                        .fill(
                            RadialGradient(
                                colors: [ColorTokens.Brand.primary.opacity(0.22), .clear],
                                center: .center,
                                startRadius: 2,
                                endRadius: 80
                            )
                        )
                        .frame(width: 160, height: 32)
                        .blur(radius: 2)
                        .padding(.bottom, -8)
                        .accessibilityHidden(true)

                    // Background scene layer (visible when background tab is active)
                    if selectedTab == .background {
                        Image(viewModel.selectedBackground.illustrationName)
                            .resizable()
                            .scaledToFill()
                            .frame(width: mascotPreviewSize, height: mascotPreviewSize)
                            .clipShape(Circle())
                            .opacity(0.35)
                            .id(viewModel.selectedBackground.rawValue)
                            .transition(.opacity)
                            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3),
                                       value: viewModel.selectedBackground)
                            .accessibilityHidden(true)
                    }

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
                        : .scale(scale: 0.88).combined(with: .opacity))
                    .animation(reduceMotion ? .linear(duration: 0.3) : MotionTokens.spring,
                               value: viewModel.selectedSkin)
                    .animation(reduceMotion ? .linear(duration: 0.3) : MotionTokens.spring,
                               value: viewModel.selectedOutfit)
                }
                .frame(height: mascotPreviewSize)
                .padding(.bottom, SpacingTokens.regular)
        }
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white.opacity(0.85),
                            gradFrom.opacity(0.6),
                            gradTo.opacity(0.9)
                        ],
                        center: .top,
                        startRadius: 0,
                        endRadius: 280
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.xl, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
                .shadow(
                    color: ColorTokens.Brand.primary.opacity(0.22),
                    radius: 20, x: 0, y: 10
                )
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.3),
                           value: viewModel.selectedColor)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
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
            .padding(.horizontal, SpacingTokens.screenEdge)
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
            .padding(.horizontal, SpacingTokens.screenEdge)
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
    //
    // Design ref: 3-column LazyVGrid of outfit cards (not horizontal scroll).
    // Section label shows title + count on the same line.

    private var outfitTab: some View {
        let columns = [
            GridItem(.flexible(), spacing: SpacingTokens.small),
            GridItem(.flexible(), spacing: SpacingTokens.small),
            GridItem(.flexible(), spacing: SpacingTokens.small)
        ]
        return VStack(alignment: .leading, spacing: 0) {
            sectionTitleWithCount(
                String(localized: "customization.section.outfits",
                       defaultValue: "Выбери наряд"),
                count: viewModel.outfitItems.count
            )
            LazyVGrid(columns: columns, spacing: SpacingTokens.small) {
                ForEach(viewModel.outfitItems) { item in
                    OutfitCard(item: item) {
                        interactor?.selectOutfit(.init(outfit: item.outfit))
                    }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
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
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
            .frame(height: skinScrollHeight)
            .padding(.bottom, SpacingTokens.regular)
        }
    }

    // MARK: - Color tab
    //
    // Показываем только выбор цветового варианта (LyalyaColorVariant) —
    // единственная категория, которая реально влияет на превью маскота
    // (gradient в mascotHeader). Секции hair/eye/skinTone удалены: для них
    // нет компонуемых PNG-слоёв в Assets.xcassets — выбор ничего не менял
    // на экране (мёртвый UI). Данные по-прежнему хранятся в Realm через
    // saveCustomization/autoSave, но редактор этих значений скрыт до появления ассетов.

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
            .padding(.horizontal, SpacingTokens.screenEdge)
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
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
            .frame(height: isCompactWidth ? 120 : 140)
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
            .padding(.horizontal, SpacingTokens.screenEdge)
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

    // MARK: - Section title helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(TypographyTokens.headline(17).weight(.bold))
            .foregroundStyle(ColorTokens.Kid.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
            .padding(.bottom, SpacingTokens.tiny)
    }

    /// Section title with a count badge on the right, matching the design reference.
    private func sectionTitleWithCount(_ title: String, count: Int) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.sp1) {
            Text(title)
                .font(TypographyTokens.headline(17).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)

            Spacer()

            Text("\(count) \(String(localized: "customization.section.variants", defaultValue: "вариантов"))")
                .font(TypographyTokens.caption(13).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.inkSoft)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.regular)
        .padding(.bottom, SpacingTokens.tiny)
    }

    // MARK: - Responsive sizing

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    private var isCompactWidth: Bool { horizontalSizeClass == .compact }
    private var mascotSize: CGFloat { isCompactWidth ? 176 : 220 }
    private var mascotPreviewSize: CGFloat { isCompactWidth ? 220 : 260 }
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

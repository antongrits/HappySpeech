import OSLog
import SwiftUI

// MARK: - CustomizationTab

private enum CustomizationTab: String, CaseIterable, Identifiable {
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

    @State private var lyalyaState: LyalyaState = .idle
    @State private var selectedTab: CustomizationTab = .outfit
    @State private var showResetConfirm = false

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
        return ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [gradFrom, gradTo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
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
            Text(prompt)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.medium)
                .padding(.vertical, SpacingTokens.small)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                )
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
                ForEach(viewModel.accessoryItems) { item in
                    AccessoryToggleButton(item: item) {
                        interactor?.toggleAccessory(.init(accessory: item.accessory))
                    }
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
            withAnimation { lyalyaState = .idle }
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

// MARK: - CustomizationTabButton

private struct CustomizationTabButton: View {

    let tab: CustomizationTab
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp1) {
                Image(systemName: tab.iconName)
                    .font(.system(size: 18, weight: .medium))
                Text(tab.localizedName)
                    .font(TypographyTokens.caption(11))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundStyle(
                isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.inkMuted
            )
            .frame(minWidth: 64, minHeight: 56)
            .padding(.horizontal, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(
                        isSelected
                            ? ColorTokens.Brand.primary.opacity(0.12)
                            : Color.clear
                    )
            )
            .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)
        }
        .accessibilityLabel(tab.localizedName)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - OutfitCard

private struct OutfitCard: View {

    let item: OutfitItemViewModel
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isPressed = false

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var cardWidth: CGFloat { isCompact ? 100 : 120 }
    private var cardHeight: CGFloat { isCompact ? 136 : 158 }

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.tiny) {
                ZStack(alignment: .topTrailing) {
                    outfitIllustration
                        .frame(width: cardWidth * 0.7, height: cardHeight * 0.6)
                        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous))

                    if case .locked = item.unlockStatus {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .background(Circle().fill(ColorTokens.Kid.surface).padding(-4))
                            .padding(SpacingTokens.sp1)
                    } else if item.isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .background(Circle().fill(Color.white).padding(-2))
                            .padding(SpacingTokens.sp1)
                    }
                }

                Text(item.localizedName)
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)

                if item.starCost > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(ColorTokens.Brand.gold)
                        Text("\(item.starCost)")
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                }
            }
            .frame(width: cardWidth, height: cardHeight)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .fill(item.isSelected
                        ? ColorTokens.Brand.primary.opacity(0.12)
                        : ColorTokens.Kid.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                            .strokeBorder(
                                item.isSelected ? ColorTokens.Brand.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .opacity(item.unlockStatus.isAccessible ? 1.0 : 0.55)
            .scaleEffect(isPressed && !reduceMotion ? 0.95 : 1.0)
            .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isPressed)
        }
        .buttonStyle(PressedButtonStyle(isPressed: $isPressed))
        .accessibilityLabel("\(item.localizedName)\(item.isSelected ? ", выбран" : "")")
        .accessibilityHint(
            item.unlockStatus.isAccessible
                ? String(localized: "customization.a11y.outfit_card_hint")
                : item.outfit.unlockHint
        )
        .accessibilityAddTraits(item.isSelected ? [.isSelected] : [])
    }

    @ViewBuilder
    private var outfitIllustration: some View {
        if UIImage(named: item.illustrationName) != nil {
            Image(item.illustrationName)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                outfitPlaceholderGradient
                Image(systemName: "tshirt")
                    .font(.system(size: 28, weight: .light))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var outfitPlaceholderGradient: some View {
        LinearGradient(
            colors: [placeholderFromColor, placeholderToColor],
            startPoint: .top, endPoint: .bottom
        )
    }

    private var placeholderFromColor: Color {
        switch item.outfit {
        case .everyday:  return Color(red: 0.72, green: 0.87, blue: 0.98)
        case .beach:     return Color(red: 0.98, green: 0.92, blue: 0.60)
        case .winter:    return Color(red: 0.82, green: 0.93, blue: 0.98)
        case .school:    return Color(red: 0.78, green: 0.87, blue: 0.68)
        case .birthday:  return Color(red: 0.98, green: 0.75, blue: 0.85)
        case .space:     return Color(red: 0.50, green: 0.55, blue: 0.80)
        }
    }

    private var placeholderToColor: Color {
        switch item.outfit {
        case .everyday:  return Color(red: 0.50, green: 0.72, blue: 0.92)
        case .beach:     return Color(red: 0.98, green: 0.75, blue: 0.30)
        case .winter:    return Color(red: 0.60, green: 0.80, blue: 0.95)
        case .school:    return Color(red: 0.55, green: 0.75, blue: 0.45)
        case .birthday:  return Color(red: 0.95, green: 0.55, blue: 0.70)
        case .space:     return Color(red: 0.20, green: 0.25, blue: 0.55)
        }
    }
}

// MARK: - BackgroundCard

private struct BackgroundCard: View {

    let item: BackgroundItemViewModel
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var cardWidth: CGFloat { isCompact ? 100 : 120 }
    private var cardHeight: CGFloat { isCompact ? 100 : 120 }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                if UIImage(named: item.illustrationName) != nil {
                    Image(item.illustrationName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: cardWidth, height: cardHeight)
                        .clipped()
                } else {
                    item.background.previewGradient
                        .frame(width: cardWidth, height: cardHeight)
                }

                Text(item.localizedName)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                    .padding(.vertical, SpacingTokens.sp1)
                    .padding(.horizontal, SpacingTokens.sp2)
                    .background(.ultraThinMaterial)
                    .frame(maxWidth: .infinity)
            }
            .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(
                        isSelected ? ColorTokens.Brand.primary : Color.clear,
                        lineWidth: 3
                    )
            )
            .frame(width: cardWidth, height: cardHeight)
        }
        .accessibilityLabel("\(item.localizedName)\(isSelected ? ", выбран" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - AccessoryToggleButton

private struct AccessoryToggleButton: View {

    let item: AccessoryItemViewModel
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isLocked: Bool {
        if case .locked = item.unlockStatus { return true }
        return false
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp1) {
                ZStack {
                    Circle()
                        .fill(item.isEnabled
                            ? ColorTokens.Brand.primary.opacity(0.15)
                            : ColorTokens.Kid.surface)
                        .frame(width: 52, height: 52)

                    Image(systemName: item.iconName)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(
                            isLocked
                                ? ColorTokens.Kid.inkMuted
                                : (item.isEnabled ? ColorTokens.Brand.primary : ColorTokens.Kid.ink)
                        )

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .offset(x: 16, y: 16)
                    }
                }

                Text(item.localizedName)
                    .font(TypographyTokens.caption(10))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
            }
            .frame(minWidth: 56, minHeight: 72)
            .animation(reduceMotion ? nil : MotionTokens.outQuick, value: item.isEnabled)
        }
        .accessibilityLabel(item.localizedName)
        .accessibilityHint(
            isLocked
                ? String(localized: "customization.a11y.accessory_locked")
                : (item.isEnabled
                    ? String(localized: "customization.a11y.accessory_on")
                    : String(localized: "customization.a11y.accessory_off"))
        )
        .accessibilityAddTraits(item.isEnabled ? [.isSelected] : [])
    }
}

// MARK: - ColorCircle (hair / eye / skin tone)

private struct ColorCircle: View {

    let color: Color
    let label: String
    let isSelected: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool { horizontalSizeClass == .compact }
    private var circleSize: CGFloat { isCompact ? 40 : 44 }
    private var touchTarget: CGFloat { isCompact ? 48 : 56 }

    var body: some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: circleSize, height: circleSize)
                .overlay(
                    Circle().strokeBorder(.white.opacity(0.3), lineWidth: 1)
                )

            if isSelected {
                Circle()
                    .strokeBorder(ColorTokens.Brand.primary, lineWidth: 3)
                    .frame(width: circleSize + 8, height: circleSize + 8)
                    .animation(reduceMotion ? nil : MotionTokens.outQuick, value: isSelected)
            }
        }
        .frame(width: touchTarget, height: touchTarget)
        .contentShape(Circle())
        .accessibilityLabel("\(label)\(isSelected ? ", выбран" : "")")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
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
        .onLongPressGesture(
            minimumDuration: .infinity,
            maximumDistance: .infinity,
            pressing: { pressing in isPressed = pressing },
            perform: {}
        )
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

    private var placeholderFrom: Color {
        switch skin {
        case .classic:   return Color(red: 0.72, green: 0.87, blue: 0.98)
        case .princess:  return Color(red: 1.00, green: 0.75, blue: 0.85)
        case .scientist: return Color(red: 0.85, green: 0.95, blue: 0.85)
        case .athlete:   return Color(red: 1.00, green: 0.88, blue: 0.65)
        case .artist:    return Color(red: 0.90, green: 0.75, blue: 0.95)
        }
    }

    private var placeholderTo: Color {
        switch skin {
        case .classic:   return Color(red: 0.50, green: 0.72, blue: 0.92)
        case .princess:  return Color(red: 0.95, green: 0.55, blue: 0.70)
        case .scientist: return Color(red: 0.65, green: 0.88, blue: 0.65)
        case .athlete:   return Color(red: 0.95, green: 0.70, blue: 0.35)
        case .artist:    return Color(red: 0.75, green: 0.55, blue: 0.90)
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
            .accessibilityLabel(
                String(format: String(localized: "customization.a11y.voice_preview"), voice.localizedName)
            )
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

// MARK: - PressedButtonStyle

private struct PressedButtonStyle: ButtonStyle {
    @Binding var isPressed: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, newValue in
                isPressed = newValue
            }
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

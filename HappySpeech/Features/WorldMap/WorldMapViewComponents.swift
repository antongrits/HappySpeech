import OSLog
import SwiftUI

// MARK: - WorldMapViewComponents
//
// Подкомпоненты карты звуков: WorldZoneTile, WorldZoneDetailSheet, color
// helpers и Preview. Извлечено из `WorldMapView.swift` (Block K.4 v16)
// для удержания LOC ≤700. Доступ — internal (был private).

// MARK: - WorldZoneTile

/// Карточка одной зоны на карте. Размер 140×160pt по дизайн-спеке.
/// При `isWide=true` растягивается на полную ширину (для 5-й зоны).
struct WorldZoneTile: View {

    let card: WorldZoneCard
    let cardWidth: CGFloat?
    let appeared: Bool
    let index: Int
    let reduceMotion: Bool
    var isWide: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            tileContent
                .frame(maxWidth: isWide ? .infinity : cardWidth)
                .frame(minHeight: 160)
                .background(background)
                .overlay(highlightOverlay)
                .overlay(lockOverlay)
                .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous))
                .shadow(
                    color: card.backgroundColor.opacity(0.32),
                    radius: 12, x: 0, y: 6
                )
                .scaleEffect(scaleValue)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(
                    reduceMotion
                        ? nil
                        : .spring(response: 0.55, dampingFraction: 0.78)
                            .delay(Double(index) * 0.08),
                    value: appeared
                )
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                    value: isPressed
                )
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityHint(card.accessibilityHint)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: Subviews

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            HStack(alignment: .top) {
                Image(systemName: card.icon)
                    .font(.system(size: isWide ? 44 : 36, weight: .regular))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
                Spacer(minLength: 0)
                if !card.isLocked {
                    Text(card.progressLabel)
                        .font(TypographyTokens.mono(11).weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule().fill(card.foregroundColor.opacity(0.18))
                        )
                        .foregroundStyle(card.foregroundColor)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text(card.name)
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(card.foregroundColor)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                Text(card.soundsLabel)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(card.foregroundColor.opacity(0.85))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HSProgressBar(
                value: card.progress,
                style: .parent,
                tint: card.foregroundColor
            )
            .frame(height: 4)
            .accessibilityHidden(true)

            Text(card.lessonsLabel)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(card.foregroundColor.opacity(0.85))
        }
        .padding(SpacingTokens.regular)
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [
                        card.backgroundColor,
                        card.backgroundColor.opacity(0.85)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    @ViewBuilder
    private var highlightOverlay: some View {
        if card.isHighlighted {
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .strokeBorder(Color.white, lineWidth: 3)
                .shadow(color: .white.opacity(0.4), radius: 8)
        }
    }

    @ViewBuilder
    private var lockOverlay: some View {
        if card.isLocked {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Overlay.dimmer)
                Image(systemName: "lock.fill")
                    .font(TypographyTokens.title(32).weight(.semibold))
                    .foregroundStyle(.white)
                    .accessibilityHidden(true)
            }
        }
    }

    private var scaleValue: CGFloat {
        if card.isLocked { return 1.0 }
        return isPressed && !reduceMotion ? 0.96 : 1.0
    }
}

// MARK: - WorldZoneDetailSheet

/// Детальный sheet зоны карты звуков.
/// Показывается при любом tap на зону (открытую или заблокированную).
/// Содержит: название, описание, список звуков, прогресс-кольцо, рекомендации,
/// CTA «Начать» / «Продолжить» / «Заблокировано».
struct WorldZoneDetailSheet: View {

    let viewModel: WorldMapModels.LoadZoneDetail.ViewModel
    let reduceMotion: Bool
    let onStart: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.large) {
                headerSection
                if let hint = viewModel.prerequisiteHint, viewModel.isLocked {
                    lockHintSection(hint)
                }
                progressSection
                descriptionSection
                soundsSection
                statsSection
                ctaSection
                Spacer(minLength: SpacingTokens.xxLarge)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
        }
        .background(
            LinearGradient(
                colors: [
                    viewModel.backgroundColor.opacity(0.12),
                    ColorTokens.Kid.bg
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(viewModel.accessibilityLabel)
    }

    // MARK: Header

    private var headerSection: some View {
        HStack(alignment: .top, spacing: SpacingTokens.regular) {
            // Большой иконка-кружок с цветом зоны
            ZStack {
                Circle()
                    .fill(viewModel.backgroundColor.opacity(viewModel.isLocked ? 0.25 : 0.20))
                    .frame(width: 80, height: 80)
                if viewModel.isLocked {
                    Image(systemName: "lock.fill")
                        .font(TypographyTokens.titleLarge(30))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .accessibilityHidden(true)
                } else {
                    Image(systemName: viewModel.icon)
                        .font(.system(size: 40, weight: .regular))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                }
            }

            VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                HStack {
                    Text(viewModel.name)
                        .font(TypographyTokens.title(22))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(TypographyTokens.title(24))
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "worldMap.detail.close"))
                    .frame(width: 44, height: 44)
                }

                if !viewModel.soundsLabel.isEmpty {
                    Text(viewModel.soundsLabel)
                        .font(TypographyTokens.body(15))
                        .foregroundStyle(viewModel.backgroundColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
            }
        }
    }

    // MARK: Lock hint

    private func lockHintSection(_ hint: String) -> some View {
        HSLiquidGlassCard(style: .tinted(ColorTokens.Semantic.warning), padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.regular) {
                Image(systemName: "lock.shield.fill")
                    .font(TypographyTokens.titleSmall(22))
                    .foregroundStyle(ColorTokens.Semantic.warning)
                    .accessibilityHidden(true)
                Text(hint)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .lineSpacing(3)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(hint)
    }

    // MARK: Progress ring + label

    private var progressSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.cardPad) {
            HStack(spacing: SpacingTokens.large) {
                // Минипрогресс-кольцо (через HSProgressRing если есть, иначе ZStack)
                progressRing

                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    Text(viewModel.progressLabel)
                        .font(TypographyTokens.mono(22).weight(.bold))
                        .foregroundStyle(viewModel.isLocked
                            ? ColorTokens.Kid.inkSoft
                            : viewModel.backgroundColor)
                        .lineLimit(1)

                    Text(viewModel.lessonsLabel)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.progressLabel). \(viewModel.lessonsLabel)")
    }

    private var progressRing: some View {
        ZStack {
            Circle()
                .stroke(ColorTokens.Kid.line, lineWidth: 6)
                .frame(width: 56, height: 56)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, viewModel.progress)))
                .stroke(
                    viewModel.isLocked
                        ? ColorTokens.Kid.inkSoft
                        : viewModel.backgroundColor,
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: 56, height: 56)
                .animation(
                    reduceMotion ? nil : .easeOut(duration: 0.8),
                    value: viewModel.progress
                )
        }
        .accessibilityHidden(true)
    }

    // MARK: Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.small) {
            sectionHeader(String(localized: "worldMap.detail.descriptionTitle"))

            Text(viewModel.description)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .lineSpacing(4)
                .minimumScaleFactor(0.85)
        }
    }

    // MARK: Sounds chips

    @ViewBuilder
    private var soundsSection: some View {
        if !viewModel.soundsLabel.isEmpty {
            VStack(alignment: .leading, spacing: SpacingTokens.small) {
                sectionHeader(String(localized: "worldMap.detail.soundsTitle"))

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: SpacingTokens.small), count: 4),
                    spacing: SpacingTokens.small
                ) {
                    ForEach(viewModel.soundsLabel.components(separatedBy: " · "), id: \.self) { sound in
                        Text(sound)
                            .font(TypographyTokens.mono(18).weight(.bold))
                            .foregroundStyle(viewModel.isLocked ? ColorTokens.Kid.inkSoft : viewModel.foregroundColor)
                            .frame(minWidth: 48, minHeight: 48)
                            .background(
                                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                                    .fill(viewModel.isLocked
                                        ? ColorTokens.Kid.surface
                                        : viewModel.backgroundColor)
                            )
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(viewModel.soundsLabel)
            }
        }
    }

    // MARK: Stats

    private var statsSection: some View {
        HSLiquidGlassCard(style: .primary, padding: SpacingTokens.cardPad) {
            HStack(spacing: 0) {
                statCell(
                    icon: "book.closed.fill",
                    value: viewModel.recommendedLabel,
                    label: String(localized: "worldMap.detail.stats.lessons")
                )
                Divider()
                    .frame(height: 40)
                statCell(
                    icon: "clock.fill",
                    value: viewModel.durationLabel,
                    label: String(localized: "worldMap.detail.stats.perSession")
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statCell(icon: String, value: String, label: String) -> some View {
        VStack(spacing: SpacingTokens.micro) {
            Image(systemName: icon)
                .font(TypographyTokens.bodyMedium(16))
                .foregroundStyle(viewModel.backgroundColor)
                .accessibilityHidden(true)
            Text(value)
                .font(TypographyTokens.mono(15).weight(.semibold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }

    // MARK: CTA

    private var ctaSection: some View {
        HSButton(
            viewModel.ctaTitle,
            style: viewModel.isLocked ? .ghost : .primary,
            icon: viewModel.isLocked ? "lock.fill" : "play.fill"
        ) {
            guard !viewModel.isLocked else { return }
            onStart()
        }
        .frame(maxWidth: .infinity)
        .disabled(viewModel.isLocked)
        .accessibilityLabel(viewModel.ctaTitle)
        .accessibilityHint(viewModel.isLocked
            ? String(localized: "worldMap.a11y.lockedHint")
            : String(localized: "worldMap.a11y.unlockedHint"))
    }

    // MARK: Helpers

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(TypographyTokens.caption(12).weight(.semibold))
            .foregroundStyle(ColorTokens.Kid.inkSoft)
            .textCase(.uppercase)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Color helpers (View layer only)

private extension WorldZoneCard {
    /// Основной цвет зоны, смаппированный из `colorName` в SwiftUI `Color`.
    var backgroundColor: Color { colorName.zoneBackgroundColor }
    /// Цвет текста поверх основного цвета зоны.
    var foregroundColor: Color { colorName.zoneForegroundColor }
}

private extension WorldMapModels.LoadZoneDetail.ViewModel {
    /// Основной цвет зоны, смаппированный из `colorName` в SwiftUI `Color`.
    var backgroundColor: Color { colorName.zoneBackgroundColor }
    /// Цвет текста поверх основного цвета зоны.
    var foregroundColor: Color { colorName.zoneForegroundColor }
}

private extension String {
    var zoneBackgroundColor: Color {
        switch self {
        case "mint":    return ColorTokens.Brand.mint
        case "butter":  return ColorTokens.Brand.butter
        case "lilac":   return ColorTokens.Brand.lilac
        case "coral":   return ColorTokens.Brand.primary
        case "gold":    return ColorTokens.Brand.gold
        case "sky":     return ColorTokens.Brand.sky
        case "primary": return ColorTokens.Brand.primary
        default:        return ColorTokens.Brand.sky
        }
    }

    var zoneForegroundColor: Color {
        switch self {
        case "butter", "gold": return ColorTokens.Kid.ink
        default:               return .white
        }
    }
}

// MARK: - Preview

#Preview("WorldMap") {
    NavigationStack {
        WorldMapView(childId: "preview-child", targetSound: "С")
    }
    .environment(AppContainer.preview())
    .environment(\.circuitContext, .kid)
}

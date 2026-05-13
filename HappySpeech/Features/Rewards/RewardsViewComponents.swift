import OSLog
import Particles
import SwiftUI

// MARK: - RewardsViewComponents
//
// Подкомпоненты экрана наград: StickerCellView, StickerDetailSheet,
// StickerUnlockOverlay и Preview. Извлечено из `RewardsView.swift`
// (Block K.10 v16) для удержания LOC ≤700. Доступ — internal (был private).

// MARK: - StickerCellView
//
// S12 Block S: принимает опциональный heroNamespace для matchedGeometryEffect
// на emoji стикера. isHeroSource=false когда этот стикер летит в unlock overlay.

struct StickerCellView: View {
    let cell: StickerCellViewModel
    let appearIndex: Int
    var heroNamespace: Namespace.ID? = nil
    var isHeroSource: Bool = true
    let onTap: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bounce = false
    @State private var appeared = false
    @State private var sparkleAngle: Double = 0

    private var appearDelay: Double {
        // Stagger: 30ms × index, capped to keep the screen alive.
        min(Double(appearIndex) * 0.030, 0.6)
    }

    var body: some View {
        Button(
            action: {
                onTap()
                withAnimation(reduceMotion ? nil : MotionTokens.bounce) {
                    bounce.toggle()
                }
            },
            label: {
                if cell.isUnlocked {
                    unlockedCell
                } else {
                    lockedCell
                }
            }
        )
        .buttonStyle(.plain)
        .scaleEffect(appeared ? 1 : 0.6)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            guard !appeared else { return }
            if reduceMotion {
                appeared = true
                return
            }
            // Bounce-in только для unlocked. Locked — мягкий fade.
            let animation: Animation = cell.isUnlocked
                ? .spring(response: 0.5, dampingFraction: 0.55).delay(appearDelay)
                : .easeOut(duration: 0.35).delay(appearDelay)
            withAnimation(animation) {
                appeared = true
            }
            // Sparkle: вращение для isNew стикеров.
            if cell.isNew {
                withAnimation(
                    .linear(duration: 6).repeatForever(autoreverses: false)
                ) {
                    sparkleAngle = 360
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cell.accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Unlocked: HSLiquidGlassCard with color tint

    private var unlockedCell: some View {
        HSLiquidGlassCard(
            style: .tinted(ColorTokens.Brand.butter),
            padding: SpacingTokens.tiny
        ) {
            VStack(spacing: SpacingTokens.tiny) {
                ZStack {
                    // Soft halo behind the icon
                    Circle()
                        .fill(ColorTokens.Brand.butter.opacity(0.18))
                        .frame(width: 64, height: 64)
                        .shadow(
                            color: cell.isNew
                                ? ColorTokens.Brand.gold.opacity(0.55)
                                : Color.clear,
                            radius: 10
                        )

                    // Sparkle ring around isNew stickers
                    if cell.isNew {
                        sparkleRing
                            .frame(width: 84, height: 84)
                            .accessibilityHidden(true)
                    }

                    // S12: matchedGeometryEffect на emoji — source когда overlay закрыт.
                    emojiView

                    if cell.isNew {
                        Circle()
                            .strokeBorder(ColorTokens.Brand.gold, lineWidth: 3)
                            .frame(width: 70, height: 70)
                    }
                }

                Text(cell.name)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                if cell.isNew {
                    Text(String(localized: "rewards.badge.new"))
                        .font(TypographyTokens.mono(10))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ColorTokens.Brand.gold))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 88)
        }
    }

    // S12: emoji с опциональным matchedGeometryEffect (source или destination).
    @ViewBuilder
    private var emojiView: some View {
        let base = HSContentSymbol(cell.emoji, size: 38, tint: ColorTokens.Brand.gold)
            .scaleEffect(bounce ? 1.08 : 1.0)
        if let ns = heroNamespace {
            base.matchedGeometryEffect(
                id: "sticker_\(cell.id)",
                in: ns,
                isSource: isHeroSource
            )
        } else {
            base
        }
    }

    /// Лёгкий sparkle-ring: 4 крошечных звёздочки по окружности, медленно вращается.
    private var sparkleRing: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(TypographyTokens.caption(10).weight(.bold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .offset(y: -42)
                    .rotationEffect(.degrees(Double(i) * 90))
            }
        }
        .rotationEffect(.degrees(reduceMotion ? 0 : sparkleAngle))
    }

    // MARK: - Locked: plain surface, no glass

    private var lockedCell: some View {
        VStack(spacing: SpacingTokens.tiny) {
            ZStack {
                Circle()
                    .fill(ColorTokens.Kid.surfaceAlt)
                    .frame(width: 64, height: 64)

                HSContentSymbol(cell.emoji, size: 38, tint: ColorTokens.Kid.inkSoft)
                    .grayscale(0.95)
                    .opacity(0.35)

                Image(systemName: "lock.fill")
                    .font(TypographyTokens.caption(14).weight(.semibold))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .padding(6)
                    .background(Circle().fill(ColorTokens.Kid.surface))
                    .offset(x: 22, y: 22)
                    .accessibilityLabel(String(localized: "rewards.locked"))
            }

            Text(cell.name)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .padding(SpacingTokens.tiny)
    }
}

// MARK: - StickerDetailSheet

struct StickerDetailSheet: View {
    let detail: StickerDetailViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            Capsule()
                .fill(ColorTokens.Kid.line)
                .frame(width: 36, height: 4)
                .padding(.top, SpacingTokens.tiny)

            ZStack {
                Circle()
                    .fill(
                        detail.isUnlocked
                            ? ColorTokens.Brand.butter.opacity(0.30)
                            : ColorTokens.Kid.surfaceAlt
                    )
                    .frame(width: 140, height: 140)
                HSContentSymbol(detail.emoji, size: 80, tint: ColorTokens.Brand.gold)
                    .opacity(detail.isUnlocked ? 1 : 0.4)
                    .grayscale(detail.isUnlocked ? 0 : 0.9)
            }

            // E v21: 3D Ляля в StickerDetailSheet (reward detail screen).
            // .celebrating если разблокирован, .thinking если ещё не открыт.
            LyalyaHeroView(
                state: detail.isUnlocked ? .celebrating : .thinking,
                mood: detail.isUnlocked ? 1.0 : 0.4,
                size: 100
            )
            .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.tiny) {
                Text(detail.name)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(detail.collectionName)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .textCase(.uppercase)
                    .tracking(0.6)
            }

            HSLiquidGlassCard(style: .primary, padding: SpacingTokens.medium) {
                VStack(alignment: .leading, spacing: SpacingTokens.small) {
                    Label {
                        Text(detail.unlockCondition)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.ink)
                    } icon: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(ColorTokens.Brand.primary)
                    }

                    if let dateLabel = detail.unlockedDateLabel {
                        Label {
                            Text(dateLabel)
                                .font(TypographyTokens.body(13))
                                .foregroundStyle(ColorTokens.Kid.inkMuted)
                        } icon: {
                            Image(systemName: "calendar")
                                .foregroundStyle(ColorTokens.Brand.mint)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()

            HSButton(
                String(localized: "rewards.detail.close"),
                style: .primary,
                icon: "xmark",
                action: onClose
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.large)
        }
        .frame(maxWidth: .infinity)
        .background(ColorTokens.Kid.bg.ignoresSafeArea())
        .accessibilityElement(children: .contain)
    }
}

// MARK: - StickerUnlockOverlay
//
// S12 Block S: добавлены параметры heroNamespace и heroSourceId для
// matchedGeometryEffect на emoji стикера (destination в overlay).
// Nil-безопасны — backward compatible.

struct StickerUnlockOverlay: View {
    let unlock: StickerUnlockViewModel
    var heroNamespace: Namespace.ID? = nil
    var heroSourceId: String? = nil
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stickerScale: CGFloat = 0.2
    @State private var confettiAppeared = false

    var body: some View {
        ZStack {
            ColorTokens.Overlay.dimmerHeavy
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(String(localized: "a11y.button.close"))

            // Confetti particles через swiftui-particles (benlmyers/swiftui-particles, MIT)
            if confettiAppeared {
                Emitter(from: .top, to: .bottom) {
                    Confetti(
                        [
                            ColorTokens.Brand.gold,
                            ColorTokens.Brand.primary,
                            ColorTokens.Brand.lilac,
                            ColorTokens.Feedback.correct
                        ],
                        size: .medium
                    )
                }
                .emitForever(intensity: 30)
                .particleLifetime(2.5)
                .emitSpread(0.9)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }

            VStack(spacing: SpacingTokens.large) {
                Text(String(localized: "rewards.unlock.badge"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .padding(.horizontal, SpacingTokens.medium)
                    .padding(.vertical, SpacingTokens.tiny)
                    .background(Capsule().fill(ColorTokens.Brand.gold))
                    .textCase(.uppercase)
                    .tracking(1.0)

                // S12: emoji — destination matchedGeometryEffect (isSource=false).
                unlockEmojiView

                Text(unlock.name)
                    .font(TypographyTokens.title(28))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
                    .multilineTextAlignment(.center)

                HSButton(
                    String(localized: "rewards.unlock.cta"),
                    style: .primary,
                    icon: "sparkles",
                    action: onDismiss
                )
                .padding(.horizontal, SpacingTokens.xxLarge)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            String(format: String(localized: "rewards.a11y.unlocked"), unlock.name)
        )
        .onAppear {
            if reduceMotion {
                stickerScale = 1
                confettiAppeared = true
                return
            }
            withAnimation(.spring(response: 0.55, dampingFraction: 0.55)) {
                stickerScale = 1
            }
            withAnimation(.easeOut(duration: 1.6)) {
                confettiAppeared = true
            }
        }
    }

    // S12: emoji view с опциональным matchedGeometryEffect (isSource=false — destination).
    @ViewBuilder
    private var unlockEmojiView: some View {
        let base = HSContentSymbol(unlock.emoji, size: 120, tint: ColorTokens.Brand.gold)
            .scaleEffect(heroNamespace != nil ? 1 : stickerScale)
            .shadow(color: ColorTokens.Brand.gold.opacity(0.5), radius: 18)
        if let ns = heroNamespace, let sourceId = heroSourceId {
            base.matchedGeometryEffect(
                id: "sticker_\(sourceId)",
                in: ns,
                isSource: false
            )
        } else {
            base
        }
    }
}

// MARK: - Preview

#Preview("Rewards") {
    RewardsView(childId: "preview-child")
        .environment(AppContainer.preview())
}

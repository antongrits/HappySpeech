import SwiftUI

// MARK: - VoicingSoftnessViewComponents
//
// Игровые подвью «Карты звонкости и мягкости». Пиксельно следуют эталонам
// references/kid-game-voicing-softness-{1,2,3}.html:
//   • зоны-домики (звонкая/глухая или сердитый/ласковый брат) с эмодзи-
//     горлышком/братом Ø74–78pt + кольца вибрации / покачивание;
//   • перетаскиваемый токен-звук Ø84pt;
//   • картинки минимальной пары + diff-hint с подсветкой различающейся буквы.
// Только View-слой: палитра через ColorTokens (звонкий=коралл, глухой=серый —
// НЕ синий; твёрдый=коралл-силач, мягкий=Rose). Reduced Motion отключает buzz/
// wiggle. Симметричные отступы, без обрезки текста.

// MARK: - Zone Row (две зоны-домика)

struct VoicingZoneRow: View {
    let zones: [VoicingSoftnessModels.Start.ZoneViewModel]
    let droppedZone: VoicingZone?
    let revealedZone: VoicingZone?
    let reduceMotion: Bool
    let onSelect: (VoicingZone) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            ForEach(zones) { zone in
                VoicingZoneCard(
                    zone: zone,
                    isDropped: droppedZone == zone.id,
                    isRevealed: revealedZone == zone.id,
                    isMissed: droppedZone == zone.id && revealedZone != nil && revealedZone != zone.id,
                    reduceMotion: reduceMotion,
                    onTap: { onSelect(zone.id) }
                )
            }
        }
    }
}

// MARK: - Zone Card

struct VoicingZoneCard: View {
    let zone: VoicingSoftnessModels.Start.ZoneViewModel
    let isDropped: Bool
    let isRevealed: Bool
    let isMissed: Bool
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var animate = false

    private var accent: Color {
        switch zone.id {
        case .voiced:    return ColorTokens.VoicingSoftness.voiced
        case .voiceless: return ColorTokens.VoicingSoftness.voiceless
        case .hard:      return ColorTokens.VoicingSoftness.hard
        case .soft:      return ColorTokens.VoicingSoftness.soft
        }
    }

    /// Звонкая зона дрожит (buzz), мягкий братик мягко покачивается (wiggle).
    private var isLivelyZone: Bool { zone.id == .voiced || zone.id == .soft }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.small) {
                throatOrBrother
                Text(zone.title)
                    .font(TypographyTokens.kidCardTitle(16))
                    .foregroundStyle(accent)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                Text(zone.desc)
                    .font(TypographyTokens.caption(12).weight(.medium))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.regular)
            .padding(.horizontal, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(zoneBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(zoneBorder, lineWidth: borderWidth)
            )
            .kidTileShadow()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(zone.accessibilityLabel))
        .accessibilityHint(Text("voicingSoftness.zone.hint"))
        .accessibilityAddTraits(isRevealed ? [.isButton, .isSelected] : .isButton)
        .onAppear {
            guard !reduceMotion, isLivelyZone else { return }
            animate = true
        }
    }

    // MARK: Throat / brother avatar

    @ViewBuilder
    private var throatOrBrother: some View {
        ZStack {
            // Кольца вибрации только у звонкой зоны (метафора гудящего голоса).
            if zone.id == .voiced, !reduceMotion {
                vibrationRing(delay: 0)
                vibrationRing(delay: 0.55)
            }

            Circle()
                .fill(
                    RadialGradient(
                        colors: [accent.opacity(0.30), ColorTokens.Kid.surface],
                        center: .init(x: 0.5, y: 0.4),
                        startRadius: 2,
                        endRadius: 40
                    )
                )
                .overlay(Circle().strokeBorder(accent.opacity(0.5), lineWidth: 2))
                .frame(width: 76, height: 76)
                .overlay(
                    Text(verbatim: zone.emoji)
                        .font(.system(size: 40))
                        .accessibilityHidden(true)
                )
                // Звонкая зона дрожит; мягкий братик покачивается.
                .modifier(VoicingLivelyMotion(
                    kind: liveliness,
                    active: animate && !reduceMotion
                ))
        }
        .frame(height: 84)
        .accessibilityHidden(true)
    }

    private var liveliness: VoicingLiveliness {
        if reduceMotion { return .still }
        switch zone.id {
        case .voiced: return .buzz
        case .soft:   return .wiggle
        default:      return .still
        }
    }

    private func vibrationRing(delay: Double) -> some View {
        Circle()
            .strokeBorder(accent, lineWidth: 2)
            .frame(width: 76, height: 76)
            .scaleEffect(animate ? 1.5 : 0.8)
            .opacity(animate ? 0 : 0.55)
            .animation(
                .easeOut(duration: 1.1).repeatForever(autoreverses: false).delay(delay),
                value: animate
            )
    }

    // MARK: Styling

    private var zoneBackground: Color {
        if isRevealed { return ColorTokens.Brand.mint.opacity(0.18) }
        if isMissed { return ColorTokens.Semantic.errorBg }
        return accent.opacity(0.10)
    }

    private var zoneBorder: Color {
        if isRevealed { return ColorTokens.Brand.mint }
        if isMissed { return ColorTokens.Semantic.error.opacity(0.6) }
        if isDropped { return accent }
        return accent.opacity(0.45)
    }

    private var borderWidth: CGFloat {
        (isRevealed || isMissed || isDropped) ? 2.5 : 2
    }
}

// MARK: - Lively motion modifier (buzz / wiggle)

/// Тип «оживления» аватара зоны: звонкий дрожит, мягкий покачивается.
enum VoicingLiveliness { case buzz, wiggle, still }

private struct VoicingLivelyMotion: ViewModifier {
    let kind: VoicingLiveliness
    let active: Bool

    func body(content: Content) -> some View {
        switch kind {
        case .buzz:
            content
                .offset(x: active ? 1.2 : -1.2, y: active ? -0.6 : 0.6)
                .animation(
                    active ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true) : nil,
                    value: active
                )
        case .wiggle:
            content
                .rotationEffect(.degrees(active ? 2 : -2))
                .animation(
                    active ? .easeInOut(duration: 1.1).repeatForever(autoreverses: true) : nil,
                    value: active
                )
        case .still:
            content
        }
    }
}

// MARK: - Token Row (перетаскиваемый звук)

struct VoicingTokenRow: View {
    let token: String
    let isVoiced: Bool
    let placed: Bool
    let accessibilityLabel: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var accent: Color {
        isVoiced ? ColorTokens.VoicingSoftness.voiced : ColorTokens.VoicingSoftness.voiceless
    }

    var body: some View {
        HStack(spacing: SpacingTokens.regular) {
            tokenChip
            Text("voicingSoftness.token.hint")
                .font(TypographyTokens.caption(13).weight(.medium))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }

    private var tokenChip: some View {
        Text(token)
            .font(TypographyTokens.title(38))
            .foregroundStyle(accent)
            .frame(width: 84, height: 84)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(accent, lineWidth: 2.5)
            )
            .overlay(alignment: .bottom) {
                // «Ручка» захвата (грабер) как в эталоне.
                Capsule()
                    .fill(accent.opacity(0.45))
                    .frame(width: 30, height: 6)
                    .offset(y: 5)
                    .accessibilityHidden(true)
            }
            .shadow(color: accent.opacity(0.35), radius: 10, y: 6)
            .opacity(placed ? 0.4 : 1)
            .scaleEffect(placed && !reduceMotion ? 0.92 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7), value: placed)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(accessibilityLabel))
    }
}

// MARK: - Trap Ask Card (слова-ловушки: «Я сказала слово …»)

struct VoicingTrapAskCard: View {
    let targetWord: String

    var body: some View {
        HStack(spacing: SpacingTokens.regular) {
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .frame(width: 64, height: 64)
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: SpacingTokens.micro) {
                Text("voicingSoftness.trap.ask.label")
                    .font(TypographyTokens.caption(12).weight(.bold))
                    .tracking(0.4)
                    .textCase(.uppercase)
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text(verbatim: "«\(targetWord)»")
                    .font(TypographyTokens.kidCardTitle(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.8)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .kidTileShadow()
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(
            String(format: String(localized: "voicingSoftness.trap.ask.a11y"), targetWord)
        ))
    }
}

// MARK: - Picks Row (две картинки минимальной пары)

struct VoicingPicksRow: View {
    let options: [VoicingSoftnessModels.Start.TrapOptionViewModel]
    let chosenOptionId: String?
    let correctOptionId: String?
    let feedback: FeedbackTier?
    let reduceMotion: Bool
    let onSelect: (String) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: SpacingTokens.small) {
            ForEach(options) { option in
                VoicingPickCard(
                    option: option,
                    state: state(for: option),
                    reduceMotion: reduceMotion,
                    onTap: { onSelect(option.id) }
                )
            }
        }
    }

    private func state(for option: VoicingSoftnessModels.Start.TrapOptionViewModel) -> KidGameCardState {
        guard correctOptionId != nil || (feedback != nil && feedback != .almost) else {
            return chosenOptionId == option.id ? .selected : .neutral
        }
        if option.id == correctOptionId { return .correct }
        if option.id == chosenOptionId { return .wrong }
        return .neutral
    }
}

// MARK: - Pick Card (картинка минимальной пары с подсветкой буквы)

struct VoicingPickCard: View {
    let option: VoicingSoftnessModels.Start.TrapOptionViewModel
    let state: KidGameCardState
    let reduceMotion: Bool
    let onTap: () -> Void

    @State private var shake = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: SpacingTokens.small) {
                HSContentSymbol(option.imageAsset, size: 58, tint: ColorTokens.Brand.primary)
                    .frame(width: 96, height: 96)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .fill(state.picBackground)
                    )
                    .accessibilityHidden(true)

                diffWord
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 156)
            .padding(.vertical, SpacingTokens.regular)
            .padding(.horizontal, SpacingTokens.small)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(alignment: .topTrailing) {
                if let icon = state.badgeIcon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(state.badgeColor))
                        .padding(SpacingTokens.tiny)
                        .accessibilityHidden(true)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.lg, style: .continuous)
                    .strokeBorder(state.borderColor, lineWidth: state.borderWidth)
            )
            .kidTileShadow()
            .offset(x: shake ? 6 : 0)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.accessibilityLabel + state.a11ySuffix))
        .accessibilityAddTraits(.isButton)
        .accessibilityAddTraits(state == .selected || state == .correct ? .isSelected : [])
        .onChange(of: state) { _, newState in
            guard newState == .wrong, !reduceMotion else { return }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.35)) { shake = true }
            withAnimation(.spring(response: 0.12, dampingFraction: 0.35).delay(0.12)) { shake = false }
        }
    }

    /// Слово с подсвеченной коралловым различающейся буквой.
    private var diffWord: some View {
        let chars = Array(option.word)
        return HStack(spacing: 0) {
            ForEach(Array(chars.enumerated()), id: \.offset) { index, char in
                Text(String(char))
                    .font(TypographyTokens.kidCardTitle(20))
                    .foregroundStyle(
                        index == option.diffIndex
                            ? ColorTokens.Brand.primary
                            : ColorTokens.Kid.ink
                    )
            }
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .accessibilityHidden(true)
    }
}

// MARK: - Throat Hint Card («потрогай горлышко»)

struct VoicingThroatHintCard: View {
    let text: String

    var body: some View {
        HStack(spacing: SpacingTokens.small) {
            Image(systemName: "hand.raised.fingers.spread.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .fill(ColorTokens.Kid.surface)
                )
                .accessibilityHidden(true)
            Text(text)
                .font(TypographyTokens.body(13).weight(.medium))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.regular)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Brand.primaryLo.opacity(0.35))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(ColorTokens.Brand.primary.opacity(0.4), lineWidth: 1.5)
                )
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(text))
    }
}

// MARK: - Summary View

struct VoicingSoftnessSummaryView: View {
    let summary: VoicingSoftnessModels.Answer.SummaryViewModel
    let onAgain: () -> Void
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            Image(systemName: summary.accuracyFraction >= 0.8
                ? "waveform.circle.fill"
                : "hand.thumbsup.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(ColorTokens.Brand.gold)
                .hsSymbolEffect(.bounce, value: summary.scoreText)
                .accessibilityHidden(true)

            Text(summary.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)

            Text(summary.scoreText)
                .font(TypographyTokens.headline(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)

            Text(summary.encouragement)
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.sp6)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                Button(action: onAgain) {
                    Text("voicingSoftness.summary.again")
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .frame(maxWidth: .infinity, minHeight: 58)
                        .background(
                            RoundedRectangle(cornerRadius: RadiusTokens.card)
                                .fill(ColorTokens.Brand.primary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityHint(Text("voicingSoftness.summary.again.hint"))

                Button(action: onDone) {
                    Text("voicingSoftness.summary.done")
                        .font(TypographyTokens.body(16).weight(.medium))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp6)
        }
        .accessibilityElement(children: .contain)
    }
}

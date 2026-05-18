import SwiftUI

// MARK: - PacingView
//
// Экран упражнения «Темп речи» (фразовый пейсинг).
// Ребёнок проговаривает фразу, ведя речь за бегунком, который равномерно
// подсвечивает слоги. Тренирует темповый самоконтроль и плавную связную речь.

struct PacingView: View {

    @State private var interactor = PacingInteractor()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let difficulty: StutteringDifficulty = .easy

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            VStack(spacing: SpacingTokens.sp5) {
                mascotHeader
                instructionLabel
                phraseCard
                tempoSlider
                progressLabel
                Spacer(minLength: 0)
                controlButtons
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp5)

            if interactor.display.showRoundReward {
                rewardOverlay
            }
            if interactor.display.isSessionComplete {
                sessionCompleteOverlay
            }
        }
        .navigationTitle(String(localized: "stuttering.exercise.pacing.title"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.circuitContext, .kid)
        .task {
            interactor.startSession(difficulty: difficulty)
        }
        .onDisappear {
            interactor.stop()
        }
    }

    // MARK: - Mascot Header

    private var mascotHeader: some View {
        let mood: MascotMood = interactor.display.showRoundReward
            ? .celebrating
            : (interactor.display.isRunning ? .happy : .idle)
        return HSMascotView(mood: mood)
            .frame(width: 96, height: 96)
            .frame(maxWidth: .infinity)
            .accessibilityHidden(true)
    }

    // MARK: - Instruction

    private var instructionLabel: some View {
        Text(String(localized: "stuttering.pacing.instruction"))
            .font(TypographyTokens.body(15))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
    }

    // MARK: - Phrase Card

    private var phraseCard: some View {
        HSCard(style: .elevated, padding: SpacingTokens.sp4) {
            SyllableFlowLayout(spacing: SpacingTokens.sp1) {
                ForEach(interactor.display.syllables) { syllable in
                    PacingSyllableChip(syllable: syllable, reduceMotion: reduceMotion)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(minHeight: 120)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            String(
                format: String(localized: "stuttering.pacing.phrase_accessibility"),
                interactor.display.phraseText
            )
        )
    }

    // MARK: - Tempo Slider (visual pacing guide)

    private var tempoSlider: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ColorTokens.Kid.surfaceAlt)
                    .frame(height: 12)

                Capsule()
                    .fill(ColorTokens.Brand.primary)
                    .frame(
                        width: max(12, geo.size.width * interactor.display.sliderProgress),
                        height: 12
                    )

                Circle()
                    .fill(ColorTokens.Brand.primary)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Image(systemName: "hare.fill")
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Overlay.onAccent)
                    }
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.3), radius: 4)
                    .offset(x: max(0, geo.size.width * interactor.display.sliderProgress - 14))
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.2),
                        value: interactor.display.sliderProgress
                    )
            }
            .frame(height: 28)
        }
        .frame(height: 28)
        .accessibilityHidden(true)
    }

    // MARK: - Progress

    private var progressLabel: some View {
        Text(interactor.display.progressLabel)
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
    }

    // MARK: - Controls

    private var controlButtons: some View {
        VStack(spacing: SpacingTokens.sp3) {
            HSButton(
                interactor.display.isRunning
                    ? String(localized: "stuttering.pacing.control.pause")
                    : (interactor.display.isPaused
                        ? String(localized: "stuttering.pacing.control.resume")
                        : String(localized: "stuttering.pacing.control.start")),
                style: .primary,
                icon: interactor.display.isRunning ? "pause.fill" : "play.fill",
                action: {
                    if interactor.display.isRunning {
                        interactor.pause()
                    } else {
                        interactor.play()
                    }
                }
            )
            .frame(height: 56)
            .disabled(interactor.display.isSessionComplete)

            if interactor.display.isPaused {
                HSButton(
                    String(localized: "stuttering.pacing.control.restart"),
                    style: .secondary,
                    icon: "arrow.counterclockwise",
                    action: { interactor.stop() }
                )
                .frame(height: 56)
            }
        }
    }

    // MARK: - Reward Overlay

    private var rewardOverlay: some View {
        VStack(spacing: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "star.fill")
                        .font(TypographyTokens.kidDisplay(32))
                        .foregroundStyle(ColorTokens.Brand.butter)
                        .scaleEffect(1.0)
                        .animation(
                            reduceMotion ? nil : MotionTokens.bounce.delay(Double(index) * 0.1),
                            value: interactor.display.showRoundReward
                        )
                }
            }
            Text(String(localized: "stuttering.pacing.phrase_done"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.sp6)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
        .accessibilityLabel(String(localized: "stuttering.pacing.phrase_done"))
    }

    // MARK: - Session Complete Overlay

    private var sessionCompleteOverlay: some View {
        VStack(spacing: SpacingTokens.sp4) {
            HSMascotView(mood: .celebrating)
                .frame(width: 110, height: 110)
            Text(String(localized: "stuttering.pacing.session_done.title"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Text(interactor.display.summaryText)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.sp6)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .padding(.horizontal, SpacingTokens.screenEdge)
        .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
    }
}

// MARK: - PacingSyllableChip

private struct PacingSyllableChip: View {

    let syllable: PacingSyllableViewModel
    let reduceMotion: Bool

    var body: some View {
        Text(syllable.text)
            .font(TypographyTokens.kidDisplay(26))
            .foregroundStyle(textColor)
            .padding(.horizontal, SpacingTokens.sp2)
            .padding(.vertical, SpacingTokens.sp1)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(backgroundColor)
            )
            .scaleEffect(syllable.state == .active && !reduceMotion ? 1.18 : 1.0)
            .shadow(
                color: syllable.state == .active
                    ? ColorTokens.Brand.primary.opacity(0.35)
                    : .clear,
                radius: syllable.state == .active ? 8 : 0
            )
            .animation(reduceMotion ? nil : MotionTokens.spring, value: syllable.state)
            // Дефис между слогами одного слова, пробел — между словами.
            .padding(.trailing, syllable.isWordEnd ? SpacingTokens.sp2 : 0)
    }

    private var backgroundColor: Color {
        switch syllable.state {
        case .waiting: return .clear
        case .active:  return ColorTokens.Brand.primary
        case .spoken:  return ColorTokens.Brand.mint.opacity(0.25)
        }
    }

    private var textColor: Color {
        switch syllable.state {
        case .waiting: return ColorTokens.Kid.ink
        case .active:  return ColorTokens.Overlay.onAccent
        case .spoken:  return ColorTokens.Kid.ink
        }
    }
}

// MARK: - SyllableFlowLayout
//
// Простой flow-layout: переносит слоги-чипы на новую строку при нехватке
// ширины. Используется для отрисовки фразы любой длины.

private struct SyllableFlowLayout: Layout {

    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = arrange(subviews: subviews, maxWidth: maxWidth)
        let height = rows.map(\.height).reduce(0, +)
            + spacing * CGFloat(max(0, rows.count - 1))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: min(width, maxWidth), height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Void
    ) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        var y = bounds.minY
        for row in rows {
            // Центрируем строку по горизонтали.
            var x = bounds.minX + (bounds.width - row.width) / 2
            for item in row.items {
                let size = subviews[item.index].sizeThatFits(.unspecified)
                subviews[item.index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    // MARK: - Row arrangement

    private struct RowItem { let index: Int }
    private struct Row {
        var items: [RowItem] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let projectedWidth = current.width
                + (current.items.isEmpty ? 0 : spacing)
                + size.width
            if projectedWidth > maxWidth, !current.items.isEmpty {
                rows.append(current)
                current = Row()
            }
            if !current.items.isEmpty { current.width += spacing }
            current.items.append(RowItem(index: index))
            current.width += size.width
            current.height = max(current.height, size.height)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

// MARK: - Preview

#Preview("PacingView") {
    NavigationStack {
        PacingView()
    }
    .environment(\.circuitContext, .kid)
}

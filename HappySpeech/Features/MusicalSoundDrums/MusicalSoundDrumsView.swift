import SwiftUI

// MARK: - MusicalSoundDrumsView

struct MusicalSoundDrumsView: View {

    let childId: String

    @State private var interactor: MusicalSoundDrumsInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        Group {
            if let interactor, interactor.state.isLoaded {
                KidGameCanvasScaffold(
                    title: Text(String(localized: "musicalDrums.hero.title")),
                    subtitle: String(localized: "musicalDrums.hero.subtitle"),
                    palette: .kidWarm,
                    onExit: { exitGame() }
                ) {
                    canvasContent(interactor: interactor)
                } toolbar: {
                    drumsToolbar(interactor: interactor)
                }
            } else {
                ZStack {
                    KidGameCanvasBackground(palette: .kidWarm)
                    ProgressView().controlSize(.large)
                }
            }
        }
        .task {
            if interactor == nil {
                let new = MusicalSoundDrumsInteractor(
                    childId: childId,
                    childRepository: container.childRepository,
                    adaptivePlanner: container.adaptivePlannerService
                )
                interactor = new
                await new.load()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Canvas content (внутри холста)

    private func canvasContent(interactor: MusicalSoundDrumsInteractor) -> some View {
        VStack(spacing: SpacingTokens.regular) {
            rhythmCard(interactor: interactor)
            Spacer(minLength: 0)
            if interactor.isGameComplete {
                completeBanner(interactor: interactor)
            } else if interactor.state.roundComplete {
                roundDoneBanner(interactor: interactor)
            } else {
                drums(interactor: interactor)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.small)
    }

    // MARK: - Toolbar (CTA: reset / next)

    @ViewBuilder
    private func drumsToolbar(interactor: MusicalSoundDrumsInteractor) -> some View {
        if !interactor.isGameComplete && interactor.state.roundComplete {
            KidGameCTAButton(
                title: String(localized: "musicalDrums.next"),
                systemImage: "arrow.right"
            ) {
                hapticService.impact(.light)
                interactor.nextRound()
            }
        } else {
            KidGameCTAButton(
                title: String(localized: "musicalDrums.cta.action"),
                systemImage: "arrow.counterclockwise"
            ) {
                hapticService.notification(.success)
                interactor.reset()
            }
        }
    }

    private func rhythmCard(interactor: MusicalSoundDrumsInteractor) -> some View {
        let state = interactor.state
        return HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp2) {
                Text(String(localized: "musicalDrums.repeatPrompt"))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                HStack(spacing: SpacingTokens.sp2) {
                    ForEach(Array(state.pattern.enumerated()), id: \.offset) { idx, syllable in
                        let isDone = idx < state.progressIndex
                        let isNext = idx == state.progressIndex && !state.roundComplete
                        Text(syllable.text)
                            .font(TypographyTokens.title(syllable.drum == .high ? 28 : 20))
                            .foregroundStyle(isDone
                                ? ColorTokens.Semantic.success
                                : (isNext ? ColorTokens.Brand.primary : ColorTokens.Kid.inkSoft))
                            .hsSymbolEffect(.bounce, value: state.progressIndex)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(String(
                    format: String(localized: "musicalDrums.a11y.pattern %@"),
                    state.patternText
                )))
                Text(String(
                    format: String(localized: "musicalDrums.round %lld %lld"),
                    state.roundsPlayed + (interactor.isGameComplete ? 0 : 1),
                    MusicalSoundDrumsInteractor.totalRounds
                ))
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
        }
    }

    private func roundDoneBanner(interactor: MusicalSoundDrumsInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.12))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                Text(String(localized: "musicalDrums.roundDone"))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }
        }
    }

    private func completeBanner(interactor: MusicalSoundDrumsInteractor) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.gold.opacity(0.14))) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .celebrating, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "musicalDrums.gameDone"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text(String(
                        format: String(localized: "kidGame.stars %lld"),
                        interactor.state.stars
                    ))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Brand.gold)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func drums(interactor: MusicalSoundDrumsInteractor) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(MusicalSoundDrumsModels.DrumId.allCases, id: \.self) { drum in
                drumButton(drum, isActive: interactor.state.lastDrumId == drum) {
                    hapticService.impact(.medium)
                    interactor.tap(drum)
                }
            }
        }
    }

    private func drumButton(
        _ drum: MusicalSoundDrumsModels.DrumId,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: SpacingTokens.sp2) {
                drumCircleIcon(drum: drum, isActive: isActive)
                Text(drum.label)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                    .fill(isActive ? ColorTokens.Brand.primary : ColorTokens.Kid.surfaceAlt)
                    .overlay(
                        RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                            .strokeBorder(ColorTokens.Kid.line, lineWidth: isActive ? 0 : 1)
                    )
            )
            .scaleEffect(isActive ? 0.97 : 1.0)
            .animation(.spring(duration: 0.2), value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(
            format: String(localized: "musicalDrums.a11y.drum %@"),
            drum.label
        )))
        .accessibilityAddTraits(.isButton)
    }

    /// Визуальная иконка барабана: концентрические круги разного масштаба
    /// для трёх уровней громкости — как в эталоне класса kid-game-canvas.
    private func drumCircleIcon(
        drum: MusicalSoundDrumsModels.DrumId,
        isActive: Bool
    ) -> some View {
        let tint: Color = isActive ? ColorTokens.Overlay.onAccent : ColorTokens.Brand.primary
        let outerSize: CGFloat
        let innerSize: CGFloat
        let showRing: Bool
        switch drum {
        case .high:
            outerSize = 44
            innerSize = 44
            showRing = false
        case .mid:
            outerSize = 44
            innerSize = 24
            showRing = true
        case .low:
            outerSize = 44
            innerSize = 12
            showRing = true
        }
        return ZStack {
            // Кольцо — для средней и тихой громкости.
            if showRing {
                Circle()
                    .strokeBorder(tint, lineWidth: 3)
                    .frame(width: outerSize, height: outerSize)
            }
            // Заполненный внутренний кружок.
            Circle()
                .fill(tint)
                .frame(width: innerSize, height: innerSize)
        }
        .frame(width: outerSize, height: outerSize)
        .accessibilityHidden(true)
    }
}

// MARK: - Preview

#Preview("MusicalSoundDrums — Light") {
    MusicalSoundDrumsView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("MusicalSoundDrums — Dark") {
    MusicalSoundDrumsView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

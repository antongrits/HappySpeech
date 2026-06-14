import SwiftUI

// MARK: - PhonemeJourneyMapView

struct PhonemeJourneyMapView: View {

    let childId: String

    @State private var interactor: PhonemeJourneyMapInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch C — Pattern 1: kidCool mesh палитра (прохладный
                // roadmap-вайб). softLight overlay для глубины фона.
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.28)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "phonemeJourney.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let worker = PhonemeJourneyMapWorker(
                        sessionRepository: container.sessionRepository,
                        childRepository: container.childRepository
                    )
                    let new = PhonemeJourneyMapInteractor(childId: childId, worker: worker)
                    interactor = new
                    new.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            VStack(spacing: 0) {
                MapJourneyHeader(
                    title: String(localized: "phonemeJourney.hero.title"),
                    subtitle: headerSubtitle(state: interactor.state),
                    starsCollected: "\(interactor.state.stages.filter(\.isComplete).count)",
                    starsTotal: String(
                        format: String(localized: "phonemeJourney.steps.of", defaultValue: "из %d"),
                        interactor.state.stages.count
                    ),
                    progress: interactor.state.progress,
                    leadingIcon: "waveform",
                    reduceMotion: reduceMotion
                )
                .padding(.top, SpacingTokens.tiny)

                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        soundHero(state: interactor.state)
                        roadmap(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, 110)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            .safeAreaInset(edge: .bottom) {
                cta(interactor: interactor)
                    .padding(.bottom, SpacingTokens.tiny)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func headerSubtitle(state: PhonemeJourneyMapModels.ViewState) -> String {
        let sound = state.targetSound.isEmpty
            ? String(localized: "phonemeJourney.hero.subtitle")
            : "\(String(localized: "phonemeJourney.sound.prefix", defaultValue: "Звук")) \(state.targetSound)"
        return sound
    }

    /// Маскот + крупная буква-звук над дорожкой этапов (эталон — «герой острова»).
    private func soundHero(state: PhonemeJourneyMapModels.ViewState) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp4) {
                LyalyaMascotView(state: .explaining, size: 76)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
                    HStack(alignment: .firstTextBaseline, spacing: SpacingTokens.tiny) {
                        Text(state.targetSound.isEmpty ? "—" : state.targetSound)
                            .font(TypographyTokens.titleLarge(34).weight(.black))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(String(
                            format: String(localized: "phonemeJourney.step.counter", defaultValue: "шаг %1$d из %2$d"),
                            state.currentIndex + 1, state.stages.count
                        ))
                        .font(TypographyTokens.caption(13).weight(.semibold))
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.8)
                    }
                    Text(String(localized: "phonemeJourney.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func roadmap(interactor: PhonemeJourneyMapInteractor) -> some View {
        let currentIndex = interactor.state.currentIndex
        return VStack(spacing: 0) {
            ForEach(Array(interactor.state.stages.enumerated()), id: \.element.id) { idx, item in
                stageRow(
                    item: item,
                    index: idx,
                    isCurrent: idx == currentIndex && !item.isComplete,
                    isLast: idx == interactor.state.stages.count - 1
                )
                .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                    content
                        .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                        .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                }
                .hsParallaxTile(factor: 0.25)
            }
        }
    }

    private func stageRow(
        item: PhonemeJourneyMapModels.StageItem,
        index: Int,
        isCurrent: Bool,
        isLast: Bool
    ) -> some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp4) {
            VStack(spacing: 0) {
                stageNode(item: item, isCurrent: isCurrent)
                if !isLast {
                    // Коннектор по эталону: коралловый у пройденного, пунктир-мягкий далее.
                    Rectangle()
                        .fill(item.isComplete
                              ? ColorTokens.Brand.primary.opacity(0.45)
                              : ColorTokens.Kid.line)
                        .frame(width: 3, height: 46)
                }
            }
            // Read-only отражение реального прогресса — не интерактивный toggle.
            HSCard(style: isCurrent ? .tinted(ColorTokens.Brand.primaryLo.opacity(0.35)) : .elevated) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.id.title)
                        .font(TypographyTokens.headline(15).weight(.bold))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text(item.id.caption)
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(item.id.title))
            .accessibilityValue(Text(item.isComplete
                ? String(localized: "phonemeJourney.stage.done")
                : String(localized: "phonemeJourney.stage.inProgress")))
        }
        .padding(.bottom, isLast ? 0 : SpacingTokens.sp2)
    }

    /// Узел этапа по эталону: пройдено — золотой ободок + мятная галочка-бейдж;
    /// текущий — коралловый кружок с пульсом; будущее — мягкий нейтральный.
    @ViewBuilder
    private func stageNode(item: PhonemeJourneyMapModels.StageItem, isCurrent: Bool) -> some View {
        ZStack {
            if item.isComplete {
                Circle()
                    .fill(ColorTokens.Kid.surface)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().strokeBorder(ColorTokens.Brand.gold.opacity(0.7), lineWidth: 3)
                    )
                    .shadow(color: ColorTokens.Brand.gold.opacity(0.22), radius: 5, y: 2)
                Image(systemName: "star.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .hsSymbolEffect(.bounce, value: item.isComplete)
                // Мятная галочка — мелкий семантический акцент «готово» (как в эталоне).
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(ColorTokens.Kid.surface, ColorTokens.Brand.mint)
                    .offset(x: 15, y: 15)
            } else if isCurrent {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [ColorTokens.Brand.primaryHi, ColorTokens.Brand.primary],
                            center: .topLeading, startRadius: 2, endRadius: 40
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(Circle().strokeBorder(ColorTokens.Kid.surface, lineWidth: 3))
                    .shadow(color: ColorTokens.Brand.primary.opacity(0.5), radius: 7, y: 3)
                Image(systemName: item.id.iconSystemName)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            } else {
                Circle()
                    .fill(ColorTokens.Kid.surfaceAlt)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Circle().strokeBorder(ColorTokens.Kid.line, style: StrokeStyle(lineWidth: 2, dash: [3, 4]))
                    )
                Image(systemName: item.id.iconSystemName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
        }
        .accessibilityHidden(true)
    }

    private func cta(interactor: PhonemeJourneyMapInteractor) -> some View {
        MapLevelCTACard(
            badgeText: interactor.state.targetSound,
            kicker: String(localized: "phonemeJourney.cta.kicker", defaultValue: "Следующий шаг"),
            levelTitle: interactor.state.stages[safe: interactor.state.currentIndex]?.id.title
                ?? String(localized: "phonemeJourney.cta.action"),
            actionTitle: String(localized: "action.play", defaultValue: "Играть"),
            actionIcon: "arrow.right",
            reduceMotion: reduceMotion,
            onTap: {
                hapticService.notification(.success)
                coordinator.navigate(to: .worldMap(
                    childId: childId,
                    targetSound: interactor.state.targetSound
                ))
            }
        )
    }
}

// MARK: - Safe index helper

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Preview

#Preview("PhonemeJourneyMap — Light") {
    PhonemeJourneyMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("PhonemeJourneyMap — Dark") {
    PhonemeJourneyMapView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

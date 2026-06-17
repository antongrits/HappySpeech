import SwiftUI

// MARK: - SoundJournalKidView
//
// Детский «дневник звуков» (kid-progress класс). Редизайн по эталону
// kid-progress: ряд колец прогресса по звукам (буква в центре, %
// и подпись), под ним — карточки практик. Все данные реальные
// (SoundJournalKidInteractor.refresh() из SessionRepository): по каждому
// звуку — число практик и последний балл. Без выдуманных записей.
//
// Инварианты: тёплая палитра (coral/butter/rose/lilac); кольца красятся
// тёплыми токенами (НЕ голый .green); выделение карточки — warm coral,
// не зелёный successBg; текст не обрезается; симметричные screenEdge-отступы;
// SE-safe; light+dark; Dynamic Type; VoiceOver; Reduced Motion.

struct SoundJournalKidView: View {

    // MARK: - Dependencies

    let childId: String

    @State private var interactor: SoundJournalKidInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                // Тёплый kidWarm mesh (как в эталоне kid-progress) — единая
                // тёплая палитра вместо холодного kidCool.
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.22 : 0.40)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                content
            }
            .navigationTitle(Text(String(localized: "soundJournal.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let new = SoundJournalKidInteractor(
                        childId: childId,
                        sessionRepository: container.sessionRepository
                    )
                    interactor = new
                    new.refresh()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content switch

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    if interactor.state.isEmpty {
                        emptyState
                    } else {
                        ringsSection(interactor: interactor)
                        listSection(interactor: interactor)
                    }
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp8)
            }
        } else {
            VStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .happy, size: 80)
                    .accessibilityHidden(true)
                ProgressView().controlSize(.large)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Hero

    private var hero: some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.cardPad) {
            HStack(alignment: .center, spacing: SpacingTokens.sp3) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [ColorTokens.Brand.butter, ColorTokens.Brand.gold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 52, height: 52)
                    Image(systemName: "book.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "soundJournal.hero.title"))
                        .font(TypographyTokens.kidTitle(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(String(localized: "soundJournal.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Rings row (эталон: кольца прогресса по звукам)

    private func ringsSection(interactor: SoundJournalKidInteractor) -> some View {
        // До 3 ведущих звуков как кольца (эталон показывает 3); остальные —
        // в списке ниже. Источник — реальные entries (отсортированы интерактором).
        let topEntries = Array(interactor.state.entries.prefix(3))
        return VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(
                title: String(localized: "soundJournal.sounds.title"),
                meta: String(localized: "soundJournal.sounds.meta")
            )
            HStack(spacing: SpacingTokens.sp3) {
                ForEach(topEntries) { entry in
                    ringCard(entry: entry)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func ringCard(entry: SoundJournalKidModels.Entry) -> some View {
        let fraction = Double(entry.lastScore) / 100.0
        let tint = ringTint(score: entry.lastScore)

        return HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp2) {
                HSProgressRing(
                    value: fraction,
                    size: 76,
                    lineWidth: 8,
                    color: tint,
                    label: entry.sound
                )
                .accessibilityHidden(true)

                Text(verbatim: "\(entry.lastScore)%")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(ringCaption(score: entry.lastScore))
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "soundJournal.ring.a11y"),
            entry.sound, entry.lastScore
        )))
    }

    // Тёплый ramp по баллу: учим (rose) → растём (coral) → класс (gold).
    private func ringTint(score: Int) -> Color {
        if score >= 85 { return ColorTokens.Brand.gold }
        if score >= 60 { return ColorTokens.Brand.primary }
        return ColorTokens.Brand.rose
    }

    private func ringCaption(score: Int) -> String {
        if score >= 85 { return String(localized: "soundJournal.ring.great") }
        if score >= 60 { return String(localized: "soundJournal.ring.grow") }
        return String(localized: "soundJournal.ring.learn")
    }

    // MARK: - Journal list

    private func listSection(interactor: SoundJournalKidInteractor) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
            sectionHeader(title: String(localized: "soundJournal.list.title"), meta: nil)
            VStack(spacing: SpacingTokens.sp2) {
                ForEach(interactor.state.entries) { entry in
                    row(entry: entry, isSelected: entry.id == interactor.state.selectedEntryId) {
                        hapticService.impact(.light)
                        interactor.select(entry.id)
                    }
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                    }
                }
            }
            .animation(reduceMotion ? nil : MotionTokens.settleSpring, value: interactor.state.entries.count)
        }
    }

    private func row(
        entry: SoundJournalKidModels.Entry,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        let tint = ringTint(score: entry.lastScore)
        return Button(action: action) {
            // Выделение — тёплый coral primaryLo (не зелёный successBg).
            HSCard(style: isSelected
                ? .tinted(ColorTokens.Brand.primaryLo.opacity(0.35))
                : .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Text(entry.emoji)
                        .font(.system(size: 30))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle().fill(ColorTokens.Kid.surfaceAlt)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(format: String(localized: "soundJournal.entry.sound"), entry.sound))
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                        Text(String(format: String(localized: "soundJournal.entry.times"), entry.timesPracticed))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: SpacingTokens.sp2)
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(verbatim: "\(entry.lastScore)")
                            .font(TypographyTokens.title(20))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(String(localized: "soundJournal.entry.score"))
                            .font(TypographyTokens.caption(10))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(
            format: String(localized: "soundJournal.entry.a11y"),
            entry.sound, entry.timesPracticed, entry.lastScore
        )))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp2) {
                LyalyaMascotView(state: .encouraging, size: 72)
                    .accessibilityHidden(true)
                Text(String(localized: "soundJournal.empty.title"))
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text(String(localized: "soundJournal.empty.subtitle"))
                    .font(TypographyTokens.body(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTA

    private var cta: some View {
        HSButton(
            String(localized: "soundJournal.cta.action"),
            style: .primary,
            size: .large,
            icon: "checkmark"
        ) {
            hapticService.notification(.success)
            exitGame()
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(title: String, meta: String?) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
            Spacer()
            if let meta {
                Text(meta)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, SpacingTokens.sp1)
    }
}

// MARK: - Preview

#Preview("SoundJournalKid — Light") {
    SoundJournalKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SoundJournalKid — Dark") {
    SoundJournalKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

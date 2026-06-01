import SwiftUI

// MARK: - SoundDoctorKidView

struct SoundDoctorKidView: View {

    let childId: String

    @State private var interactor: SoundDoctorKidInteractor?
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                // Step 10 Batch E — Pattern 1: mesh .kidWarm палитра для
                // тёплого «лечебного» режима sound-doctor.
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                content
            }
            .navigationTitle(Text(String(localized: "soundDoctor.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    let doctor = SoundDoctorKidInteractor(
                        childId: childId,
                        childRepository: container.childRepository,
                        adaptivePlanner: container.adaptivePlannerService
                    )
                    interactor = doctor
                    await doctor.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            if !interactor.state.isLoaded {
                ProgressView().controlSize(.large)
            } else if interactor.state.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        hero(state: interactor.state)
                        if let kase = interactor.state.currentCase {
                            caseCard(kase, interactor: interactor)
                        } else {
                            completionCard(state: interactor.state)
                        }
                        cta(interactor: interactor)
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var emptyState: some View {
        VStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .idle, size: 80)
                .accessibilityHidden(true)
            Text(String(localized: "soundDoctor.empty.title"))
                .font(TypographyTokens.headline(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.screenEdge)
    }

    private func hero(state: SoundDoctorKidModels.ViewState) -> some View {
        // Step 10 Batch E — Pattern 2: hero на HSLiquidGlassCard(.elevated).
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .pointing, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "soundDoctor.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "soundDoctor.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    Text(String(
                        format: String(localized: "soundDoctor.cured %lld"),
                        state.cured
                    ))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Brand.primary)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func caseCard(
        _ kase: SoundDoctorKidModels.Case,
        interactor: SoundDoctorKidInteractor
    ) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                HStack {
                    Image(systemName: "cross.case.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Brand.primary)
                    Text(String(
                        format: String(localized: "soundDoctor.case.title %@"),
                        kase.brokenSound
                    ))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                }
                Text(kase.hint)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(kase.options) { option in
                        Button {
                            hapticService.impact(.light)
                            let ok = interactor.choose(option.id)
                            hapticService.notification(ok ? .success : .warning)
                        } label: {
                            Text(option.articulation)
                                .font(TypographyTokens.body(14))
                                .foregroundStyle(ColorTokens.Kid.ink)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(SpacingTokens.sp2)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(ColorTokens.Kid.surface)
                                )
                        }
                        .buttonStyle(.plain)
                        // Step 10 Batch E — Pattern 3: scrollTransition stagger
                        // на articulation options.
                        .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                            content
                                .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                                .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                        }
                    }
                }
            }
        }
    }

    private func completionCard(state: SoundDoctorKidModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Semantic.successBg)) {
            VStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "stethoscope")
                    .font(.system(size: 36))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    // Step 10 Batch E — Pattern 5: bounce при появлении
                    // completion screen.
                    .hsSymbolEffect(.bounce, value: state.cured)
                Text(String(localized: "soundDoctor.complete.title"))
                    .font(TypographyTokens.title(18))
                    .foregroundStyle(ColorTokens.Kid.ink)
                Text(String(
                    format: String(localized: "soundDoctor.complete.score %lld %lld"),
                    state.cured, state.cases.count
                ))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp3)
        }
    }

    private func cta(interactor: SoundDoctorKidInteractor) -> some View {
        HSButton(
            String(localized: "soundDoctor.cta.action"),
            style: .primary,
            size: .large,
            icon: "arrow.counterclockwise"
        ) {
            hapticService.impact(.light)
            interactor.reset()
        }
    }
}

// MARK: - Preview

#Preview("SoundDoctorKid — Light") {
    SoundDoctorKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SoundDoctorKid — Dark") {
    SoundDoctorKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

import SwiftUI

// MARK: - EveningReflectionView

struct EveningReflectionView: View {

    let childId: String

    @State private var interactor: EveningReflectionInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .calm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "evening.nav.title")))
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
                    interactor = EveningReflectionInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    funQuestion(interactor: interactor)
                    hardQuestion(interactor: interactor)
                    moodPicker(interactor: interactor)
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .thinking, size: 64)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "evening.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "evening.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func funQuestion(interactor: EveningReflectionInteractor) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text("Что было весёлого?")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                TextField("Расскажи Ляле…", text: Binding(
                    get: { interactor.entry.fun },
                    set: { interactor.entry.fun = $0 }
                ), axis: .vertical)
                    .lineLimit(2...4)
                    .padding(SpacingTokens.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTokens.Kid.bgSoft)
                    )
            }
        }
    }

    private func hardQuestion(interactor: EveningReflectionInteractor) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text("Что было трудно?")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                TextField("Это поможет нам", text: Binding(
                    get: { interactor.entry.hard },
                    set: { interactor.entry.hard = $0 }
                ), axis: .vertical)
                    .lineLimit(2...4)
                    .padding(SpacingTokens.sp2)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(ColorTokens.Kid.bgSoft)
                    )
            }
        }
    }

    private func moodPicker(interactor: EveningReflectionInteractor) -> some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Text("Настроение")
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                HStack(spacing: SpacingTokens.sp2) {
                    ForEach(Array(EveningReflectionModels.Mood.allCases.enumerated()), id: \.element.id) { index, mood in
                        moodButton(mood, interactor: interactor)
                            .scrollTransition(
                                .animated(reduceMotion
                                    ? .linear(duration: 0)
                                    : .spring(response: 0.5, dampingFraction: 0.85))
                            ) { content, phase in
                                content
                                    .opacity(phase.isIdentity ? 1 : 0)
                                    .scaleEffect(phase.isIdentity ? 1 : 0.9)
                            }
                            .hsParallaxTile(factor: 0.15)
                            .zIndex(Double(EveningReflectionModels.Mood.allCases.count - index))
                    }
                }
            }
        }
    }

    private func moodButton(
        _ mood: EveningReflectionModels.Mood,
        interactor: EveningReflectionInteractor
    ) -> some View {
        let isSelected = interactor.entry.mood == mood
        return Button {
            hapticService.impact(.light)
            interactor.entry.mood = mood
        } label: {
            VStack(spacing: 4) {
                Text(mood.emoji).font(.system(size: 36))
                Text(mood.label)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected
                          ? ColorTokens.Brand.primary.opacity(0.15)
                          : ColorTokens.Kid.bgSoft)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? ColorTokens.Brand.primary : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(mood.label))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    private func cta(interactor: EveningReflectionInteractor) -> some View {
        HSButton(
            String(localized: "evening.cta.save"),
            style: .primary,
            size: .large,
            icon: "moon.stars.fill"
        ) {
            hapticService.notification(.success)
            interactor.submit()
            dismiss()
        }
        .disabled(interactor.entry.mood == nil)
        .opacity(interactor.entry.mood == nil ? 0.5 : 1.0)
    }
}

// MARK: - Preview

#Preview("EveningReflection — Light") {
    EveningReflectionView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("EveningReflection — Dark") {
    EveningReflectionView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

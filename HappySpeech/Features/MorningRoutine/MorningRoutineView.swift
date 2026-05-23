import SwiftUI

// MARK: - MorningRoutineView

struct MorningRoutineView: View {

    let childId: String

    @State private var interactor: MorningRoutineInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "morning.nav.title")))
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
                    interactor = MorningRoutineInteractor(childId: childId)
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
                    hero(state: interactor.state)
                    stepsList(interactor: interactor)
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

    private func hero(state: MorningRoutineModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.18))) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .waving, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "morning.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "morning.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    HSProgressBar(value: state.progress, style: .kid)
                        .frame(height: 8)
                        .padding(.top, 4)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func stepsList(interactor: MorningRoutineInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(interactor.state.steps) { step in
                stepCard(step) {
                    hapticService.impact(.light)
                    interactor.toggle(step.id)
                }
            }
        }
    }

    private func stepCard(
        _ step: MorningRoutineModels.Step,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HSCard(style: step.isDone ? .tinted(ColorTokens.Semantic.successBg) : .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: step.id.iconSystemName)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.id.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                        Text(step.id.subtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    Image(systemName: step.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24, weight: .regular))
                        .foregroundStyle(step.isDone ? ColorTokens.Semantic.success : ColorTokens.Kid.inkSoft)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(step.id.title))
        .accessibilityValue(Text(step.isDone ? "Готово" : "Начать"))
        .accessibilityAddTraits(.isButton)
    }

    private func cta(interactor: MorningRoutineInteractor) -> some View {
        HSButton(
            interactor.state.isCompleted
                ? String(localized: "morning.cta.finish")
                : String(localized: "morning.cta.start"),
            style: .primary,
            size: .large,
            icon: interactor.state.isCompleted ? "checkmark" : "sun.max.fill"
        ) {
            hapticService.notification(.success)
            if interactor.state.isCompleted {
                dismiss()
            } else {
                coordinator.navigate(to: .articulationGym(soundGroup: .sibilant))
            }
        }
    }
}

// MARK: - Preview

#Preview("MorningRoutine — Light") {
    MorningRoutineView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("MorningRoutine — Dark") {
    MorningRoutineView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

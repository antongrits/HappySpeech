import SwiftUI

// MARK: - PracticeReminderKidView

struct PracticeReminderKidView: View {

    let childId: String

    @State private var interactor: PracticeReminderKidInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                content
            }
            .navigationTitle(Text(String(localized: "practiceReminder.nav.title")))
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
                    interactor = PracticeReminderKidInteractor(childId: childId)
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
                    reminderCard(state: interactor.state, interactor: interactor)
                    cta
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private func hero(state: PracticeReminderKidModels.ViewState) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.mint.opacity(0.18))) {
            HStack(alignment: .top, spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .happy, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "practiceReminder.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "practiceReminder.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func reminderCard(
        state: PracticeReminderKidModels.ViewState,
        interactor: PracticeReminderKidInteractor
    ) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp4) {
                    badge(icon: "clock.fill", value: "\(state.estimatedMinutes) мин", label: "Сегодня")
                    badge(icon: "flame.fill", value: "\(state.streakDays)", label: "Серия")
                }
                Button {
                    hapticService.impact(.light)
                    interactor.snooze()
                } label: {
                    Text("Напомнить позже")
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                .buttonStyle(.plain)
                .opacity(state.isDismissed ? 0.4 : 1.0)
                .disabled(state.isDismissed)
            }
        }
    }

    private func badge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
            Text(value)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp2)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ColorTokens.Kid.surface)
        )
    }

    private var cta: some View {
        HSButton(
            String(localized: "practiceReminder.cta.action"),
            style: .primary,
            size: .large,
            icon: "play.fill"
        ) {
            hapticService.notification(.success)
            coordinator.navigate(to: .childHome(childId: childId))
        }
    }
}

// MARK: - Preview

#Preview("PracticeReminderKid — Light") {
    PracticeReminderKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("PracticeReminderKid — Dark") {
    PracticeReminderKidView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

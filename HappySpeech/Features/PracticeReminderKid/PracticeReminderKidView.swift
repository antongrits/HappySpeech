import SwiftUI

// MARK: - PracticeReminderKidView
//
// Центрированный одноцелевой prompt детского контура: крупная Ляля на тёплом
// коралловом glow + короткая фраза + task-pill «Сегодня нас ждёт звук …» +
// реальные бейджи (минуты сегодня / серия) + коралловая CTA «Начать» и мягкая
// «Позже». Тёплый кремовый холст, без холодных заливок.

struct PracticeReminderKidView: View {

    let childId: String

    @State private var interactor: PracticeReminderKidInteractor?
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var mascotAppeared = false

    var body: some View {
        NavigationStack {
            ZStack {
                background
                content
            }
            .navigationTitle(Text(String(localized: "practiceReminder.nav.title")))
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
                    let new = PracticeReminderKidInteractor(
                        childId: childId,
                        sessionRepository: container.sessionRepository,
                        childRepository: container.childRepository
                    )
                    interactor = new
                    await new.load()
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            HSMeshGradientBackground(palette: .kidWarm, animated: false)
                .ignoresSafeArea()
                .blendMode(.softLight)
                .accessibilityHidden(true)
                .allowsHitTesting(false)
            RadialGradient(
                colors: [ColorTokens.Brand.primaryLo.opacity(0.5), Color.clear],
                center: .init(x: 0.5, y: 0.36),
                startRadius: 8,
                endRadius: 240
            )
            .ignoresSafeArea()
            .accessibilityHidden(true)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let interactor {
            GeometryReader { geo in
                ScrollView {
                    VStack(spacing: SpacingTokens.sp4) {
                        Spacer(minLength: SpacingTokens.sp4)
                        mascotSection
                        titleSection(state: interactor.state)
                        taskPill(state: interactor.state)
                        badgesRow(state: interactor.state)
                        Spacer(minLength: SpacingTokens.sp5)
                        ctaColumn(interactor: interactor)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height)
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp6)
                }
                .scrollBounceBehavior(.basedOnSize)
                .safeAreaPadding(.bottom, SpacingTokens.sp2)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    // MARK: - Mascot

    private var mascotSection: some View {
        ZStack(alignment: .bottomTrailing) {
            HSMascotView(mood: .waving, size: 176)
                .accessibilityHidden(true)
            Image(systemName: "alarm.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(10)
                .background(
                    Circle()
                        .fill(ColorTokens.Kid.surface)
                        .shadow(color: ColorTokens.Brand.primary.opacity(0.2), radius: 10, y: 4)
                )
                .offset(x: 4, y: 6)
                .accessibilityHidden(true)
        }
        .scaleEffect(mascotAppeared ? 1.0 : 0.78)
        .opacity(mascotAppeared ? 1.0 : 0.0)
        .animation(reduceMotion ? .none : MotionTokens.rewardPop, value: mascotAppeared)
        .onAppear {
            withAnimation(reduceMotion ? .none : MotionTokens.rewardPop) {
                mascotAppeared = true
            }
        }
    }

    // MARK: - Title

    private func titleSection(state: PracticeReminderKidModels.ViewState) -> some View {
        let title: String
        if !state.isLoading && !state.childName.isEmpty {
            // «Маша, пора заниматься!» — персонализированный заголовок.
            title = String(
                format: String(localized: "practiceReminder.hero.title.named", defaultValue: "%@, пора заниматься!"),
                state.childName
            )
        } else {
            title = String(localized: "practiceReminder.hero.title")
        }
        return Text(title)
            .font(TypographyTokens.title(27))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .minimumScaleFactor(0.85)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: - Task pill

    private func taskPill(state: PracticeReminderKidModels.ViewState) -> some View {
        let pillText: String
        if !state.isLoading && !state.targetSound.isEmpty {
            // «Сегодня нас ждёт звук «Р»» — из реального профиля ребёнка.
            pillText = String(
                format: String(localized: "practiceReminder.pill.sound", defaultValue: "Сегодня нас ждёт звук «%@»"),
                state.targetSound
            )
        } else {
            pillText = String(localized: "practiceReminder.hero.subtitle")
        }

        return HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)
            Text(pillText)
                .font(TypographyTokens.body(15).weight(.medium))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .padding(.vertical, SpacingTokens.sp2)
        .padding(.horizontal, SpacingTokens.sp3)
        .background(
            Capsule(style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .overlay(Capsule(style: .continuous).strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                .shadow(color: ColorTokens.Brand.primary.opacity(0.12), radius: 12, y: 6)
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: - Badges

    private func badgesRow(state: PracticeReminderKidModels.ViewState) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            badge(
                icon: "clock.fill",
                value: minutesLabel(state),
                label: String(localized: "practiceReminder.badge.today")
            )
            badge(
                icon: "flame.fill",
                value: streakLabel(state),
                label: String(localized: "practiceReminder.badge.streak")
            )
        }
    }

    private func badge(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .hsSymbolEffect(.pulse, value: value)
            Text(value)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                .fill(ColorTokens.Kid.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                        .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
                )
        )
    }

    /// Минуты: «N мин» при реальных данных, «—» если за сегодня практики нет.
    private func minutesLabel(_ state: PracticeReminderKidModels.ViewState) -> String {
        if state.isLoading { return "…" }
        guard state.minutesToday > 0 else { return "—" }
        return "\(state.minutesToday) мин"
    }

    /// Серия: число при реальных данных, «—» если серии ещё нет.
    private func streakLabel(_ state: PracticeReminderKidModels.ViewState) -> String {
        if state.isLoading { return "…" }
        guard state.streakDays > 0 else { return "—" }
        return "\(state.streakDays)"
    }

    // MARK: - CTA column

    private func ctaColumn(interactor: PracticeReminderKidInteractor) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSButton(
                String(localized: "practiceReminder.cta.action"),
                style: .primary,
                size: .large,
                icon: "play.fill"
            ) {
                hapticService.notification(.success)
                coordinator.navigate(to: .childHome(childId: childId))
            }

            Button {
                hapticService.impact(.light)
                interactor.snooze()
            } label: {
                Text(String(localized: "practiceReminder.snooze"))
                    .font(TypographyTokens.body(16).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .buttonStyle(.plain)
            .opacity(interactor.state.isDismissed ? 0.4 : 1.0)
            .disabled(interactor.state.isDismissed)
            .accessibilityHint(String(localized: "practiceReminder.snooze"))
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

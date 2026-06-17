import SwiftUI

// MARK: - DailyMissionsHubView

struct DailyMissionsHubView: View {

    let childId: String

    @State private var interactor: DailyMissionsHubInteractor?
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

                // Тёплая статичная mesh-подложка (.kidWarm палитра).
                HSMeshGradientBackground(palette: .kidWarm, animated: false)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.30 : 0.55)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                content
            }
            .navigationTitle(Text(String(localized: "missions.nav.title")))
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
                    let new = DailyMissionsHubInteractor(
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

    // MARK: - Tab filter state

    @State private var showAllThemes: Bool = false

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    dateHeader
                    greetingBanner(interactor: interactor)
                    challengeBanner(interactor: interactor)
                    sectionHeader(interactor: interactor)
                    missionsList(interactor: interactor)
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
            .scrollBounceBehavior(.basedOnSize)
        } else {
            ProgressView().controlSize(.large)
        }
    }

    // MARK: - Date header row (эталон kid-hub-list: «Понедельник · 13 июня»)

    private var dateHeader: some View {
        HStack {
            Text(formattedDateLine)
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .minimumScaleFactor(0.85)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            LyalyaMascotView(state: .idle, size: 36)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(formattedDateLine))
    }

    private var formattedDateLine: String {
        let now = Date()
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.dateFormat = "EEEE · d MMMM"
        return df.string(from: now).localizedCapitalized
    }

    // MARK: - Greeting banner with task count

    private func greetingBanner(interactor: DailyMissionsHubInteractor) -> some View {
        let total = DailyMissionsHubModels.Mission.allCases.count
        let done = interactor.state.completed.count
        let remaining = total - done
        return HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.regular) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .pointing, size: 72)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text(String(localized: "missions.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    if remaining > 0 {
                        Text(String(
                            format: String(localized: "missions.greeting.remaining"),
                            remaining
                        ))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                    } else {
                        Text(String(localized: "missions.greeting.allDone"))
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Brand.mint)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                    HSProgressBar(value: interactor.state.progress, style: .kid)
                        .frame(height: 8)
                        .padding(.top, SpacingTokens.micro)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Weekly challenge banner (эталон kid-hub-list: коралловый banner с days-remaining)

    private func challengeBanner(interactor: DailyMissionsHubInteractor) -> some View {
        let done = interactor.state.completed.count
        let total = DailyMissionsHubModels.Mission.allCases.count
        let daysLeft = max(0, Calendar.current.daysUntilEndOfWeek())
        return Button {
            // Tap navigates to WeeklyChallenge — using coordinator
            coordinator.navigate(to: .weeklyChallenge(childId: childId))
        } label: {
            HStack(spacing: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    HStack(spacing: SpacingTokens.sp2) {
                        Text(String(localized: "missions.challenge.badge"))
                            .font(TypographyTokens.caption(11))
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .foregroundStyle(ColorTokens.Brand.butter)
                        Text(String(
                            format: String(localized: "missions.challenge.daysLeft"),
                            daysLeft
                        ))
                        .font(TypographyTokens.caption(11).monospacedDigit())
                        .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(ColorTokens.Overlay.glass))
                    }
                    Text(String(localized: "missions.challenge.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "missions.challenge.subtitle"))
                        .font(TypographyTokens.body(13))
                        .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.80))
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: SpacingTokens.sp1) {
                    Text("\(done)/\(total)")
                        .font(TypographyTokens.headline(18).monospacedDigit())
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                    HSButton(
                        String(localized: "missions.challenge.cta"),
                        style: .secondary,
                        size: .small
                    ) { coordinator.navigate(to: .weeklyChallenge(childId: childId)) }
                    .allowsHitTesting(false)
                }
            }
            .padding(SpacingTokens.regular)
            .background(
                LinearGradient(
                    colors: [ColorTokens.Brand.primary, ColorTokens.Brand.primaryHi],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                    .strokeBorder(ColorTokens.Overlay.highlight, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(String(localized: "missions.challenge.title")))
        .accessibilityHint(Text(String(localized: "missions.challenge.subtitle")))
    }

    /// Заголовок секции с живым счётчиком и фильтр-табами «N задач / Все темы» (эталон kid-hub-list).
    private func sectionHeader(interactor: DailyMissionsHubInteractor) -> some View {
        let done = interactor.state.completed.count
        let total = DailyMissionsHubModels.Mission.allCases.count
        return VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp2) {
                Text(String(localized: "missions.section.today"))
                    .font(TypographyTokens.headline(17))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
                Text(String(
                    format: String(localized: "missions.section.count"),
                    done, total
                ))
                .font(TypographyTokens.caption(12).monospacedDigit())
                .foregroundStyle(ColorTokens.Brand.primary)
                .padding(.horizontal, SpacingTokens.sp2)
                .padding(.vertical, 3)
                .background(Capsule().fill(ColorTokens.Brand.primaryLo.opacity(0.45)))
            }
            // Filter tabs: «N задач» | «Все темы»
            HStack(spacing: SpacingTokens.sp2) {
                filterTab(
                    label: String(
                        format: String(localized: "missions.tab.tasks"),
                        total
                    ),
                    isSelected: !showAllThemes
                ) { showAllThemes = false }
                filterTab(
                    label: String(localized: "missions.tab.allThemes"),
                    isSelected: showAllThemes
                ) { showAllThemes = true }
                Spacer(minLength: 0)
            }
        }
        .padding(.top, SpacingTokens.sp1)
        .accessibilityElement(children: .contain)
    }

    private func filterTab(
        label: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(label)
                .font(TypographyTokens.caption(13).weight(isSelected ? .semibold : .regular))
                .foregroundStyle(
                    isSelected ? ColorTokens.Overlay.onAccent : ColorTokens.Kid.inkMuted
                )
                .padding(.horizontal, SpacingTokens.small)
                .padding(.vertical, SpacingTokens.tiny)
                .background(
                    isSelected
                        ? AnyShapeStyle(ColorTokens.Brand.primary)
                        : AnyShapeStyle(ColorTokens.Kid.surface),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private func missionsList(interactor: DailyMissionsHubInteractor) -> some View {
        // Step 10 Batch A — Pattern 3+4: stagger entrance (fade+scale через
        // scrollTransition) и parallax-drift на каждой mission-карточке.
        VStack(spacing: SpacingTokens.sp2) {
            ForEach(DailyMissionsHubModels.Mission.allCases) { mission in
                missionRow(mission, interactor: interactor)
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                    }
                    .hsParallaxTile(factor: 0.25)
            }
        }
        .animation(reduceMotion ? nil : MotionTokens.settleSpring, value: interactor.state.completed)
    }

    private func missionRow(
        _ mission: DailyMissionsHubModels.Mission,
        interactor: DailyMissionsHubInteractor
    ) -> some View {
        let done = interactor.state.completed.contains(mission)
        return Button {
            hapticService.impact(.light)
            interactor.markCompleted(mission)
            route(for: mission)
        } label: {
            // Выполненная миссия остаётся на нейтральной тёплой поверхности
            // (как в эталоне kid-hub-list): признак «готово» — мятная галочка-акцент
            // справа, без крупной зелёной заливки карточки (off-palette).
            HSCard(style: done
                ? .tinted(ColorTokens.Brand.gold.opacity(0.10))
                : .elevated) {
                HStack(spacing: SpacingTokens.sp3) {
                    Image(systemName: mission.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mission.title)
                            .font(TypographyTokens.headline(15))
                            .foregroundStyle(ColorTokens.Kid.ink)
                        Text(mission.subtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer()
                    Image(systemName: done ? "checkmark.circle.fill" : "chevron.right")
                        .foregroundStyle(done
                                         ? ColorTokens.Semantic.success
                                         : ColorTokens.Kid.inkSoft)
                        .hsSymbolEffect(.bounce, value: done)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(mission.title))
        .accessibilityHint(Text(mission.subtitle))
    }

    private func cta(interactor: DailyMissionsHubInteractor) -> some View {
        HSButton(
            String(localized: "missions.cta.start"),
            style: .primary,
            size: .large,
            icon: "play.fill"
        ) {
            hapticService.notification(.success)
            coordinator.navigate(
                to: .lessonPlayer(templateType: "bingo", childId: childId)
            )
        }
    }

    private func route(for mission: DailyMissionsHubModels.Mission) {
        switch mission {
        case .warmup:
            coordinator.navigate(to: .articulationGym(soundGroup: .sibilant))
        case .soundOfDay:
            coordinator.navigate(to: .soundOfTheDay(childId: childId))
        case .bingo:
            coordinator.navigate(to: .lessonPlayer(templateType: "bingo", childId: childId))
        case .breathing:
            coordinator.navigate(to: .breatheAndSpeak(childId: childId))
        case .story:
            coordinator.navigate(to: .readAloudStory(childId: childId))
        }
    }
}

// MARK: - Calendar extension (local)

private extension Calendar {
    /// Дней до воскресенья включительно (конец недели ru-RU = воскресенье).
    func daysUntilEndOfWeek(from date: Date = Date()) -> Int {
        let weekday = component(.weekday, from: date)
        // weekday: 1=Вс, 2=Пн … 7=Сб (Gregorian)
        // Sunday = 1 → 0 days left; Saturday = 7 → 1 day left; others calculated.
        let remaining = (8 - weekday) % 7
        return remaining
    }
}

// MARK: - Preview

#Preview("DailyMissionsHub — Light") {
    DailyMissionsHubView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("DailyMissionsHub — Dark") {
    DailyMissionsHubView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

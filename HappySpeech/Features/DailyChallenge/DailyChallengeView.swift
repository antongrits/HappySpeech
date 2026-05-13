import OSLog
import SwiftUI

// MARK: - DailyChallengeViewModelHolder

@MainActor
@Observable
final class DailyChallengeViewModelHolder: DailyChallengeDisplayLogic {

    var loadVM: DailyChallengeModels.Load.ViewModel?
    var startSessionVM: DailyChallengeModels.StartSession.ViewModel?
    var toastMessage: String?
    var showToast: Bool = false

    func displayLoad(viewModel: DailyChallengeModels.Load.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayStartSession(viewModel: DailyChallengeModels.StartSession.ViewModel) async {
        self.startSessionVM = viewModel
    }

    func displayShareCompletion(viewModel: DailyChallengeModels.ShareCompletion.ViewModel) async {
        self.toastMessage = viewModel.toastMessage
        self.showToast = true
    }
}

// MARK: - DailyChallengeView (Clean Swift: View)
//
// Block AE batch 2 v21 — Daily Challenge: ежедневная цель для ребёнка.
//
// Layout:
//   1. Hero — приветствие + 3D-маскот Ляля (state: happy)
//   2. Goal card — символ, заголовок, прогресс-бар, label «3 из 10»
//   3. Streak card — flame icon, current/longest streak
//   4. Reward preview — стикер + xp-badge
//   5. CTA — Start (если не выполнено) или Share (если выполнено)
//
// Accessibility:
//   • VoiceOver: каждая карточка — отдельный `accessibilityElement(children: .combine)`.
//   • Dynamic Type: ScrollView root + `.minimumScaleFactor(0.85)` на CTA.
//   • Reduced Motion: убираем pulsing анимации флейма, оставляем opacity-transition.
//   • Touch targets: CTA = 48pt min height.

struct DailyChallengeView: View {

    let childId: String

    @State private var holder = DailyChallengeViewModelHolder()
    @State private var interactor: DailyChallengeInteractor?
    @State private var presenter: DailyChallengePresenter?
    @State private var router: DailyChallengeRouter?
    @State private var showShareSheet: Bool = false
    @State private var flamePulse: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "DailyChallenge.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: SpacingTokens.sectionGap) {
                        if let viewModel = holder.loadVM {
                            heroSection(viewModel: viewModel)
                            goalCard(viewModel: viewModel)
                            streakCard(viewModel: viewModel)
                            rewardCard(viewModel: viewModel)
                            ctaSection(viewModel: viewModel)
                        } else {
                            loadingSection
                        }
                    }
                    .padding(.horizontal, SpacingTokens.screenEdge)
                    .padding(.top, SpacingTokens.sp3)
                    .padding(.bottom, SpacingTokens.sp10)
                }
            }
            .navigationTitle(Text("dailyChallenge.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("dailyChallenge.close.a11y"))
                }
            }
            .overlay(alignment: .top) {
                if holder.showToast, let toast = holder.toastMessage {
                    toastBanner(text: toast)
                        .padding(.top, SpacingTokens.sp2)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(reduceMotion ? nil : .spring(duration: 0.35), value: holder.showToast)
            .sheet(isPresented: $showShareSheet) {
                if let snap = holder.toastMessage {
                    DailyChallengeShareSheet(text: snap)
                        .presentationDetents([.medium])
                }
            }
            .task {
                await setupAndLoad()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Hero

    @ViewBuilder
    private func heroSection(viewModel: DailyChallengeModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(viewModel.heroSubtitle)
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .accessibilityAddTraits(.isHeader)

                    Text("dailyChallenge.hero.tagline")
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: SpacingTokens.sp2)
                LyalyaMascotView(state: .happy, size: 72)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Goal card

    @ViewBuilder
    private func goalCard(viewModel: DailyChallengeModels.Load.ViewModel) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: viewModel.goalSymbol)
                        .font(.title3)
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(ColorTokens.Brand.primary.opacity(0.12))
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.goalTitle)
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)

                        Text(viewModel.goalSubtitle)
                            .font(TypographyTokens.body(13))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()

                    if viewModel.isCompleted {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.title2)
                            .foregroundStyle(ColorTokens.Semantic.success)
                            .accessibilityLabel(Text("dailyChallenge.goal.completed.a11y"))
                    }
                }

                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    HSProgressBar(
                        value: viewModel.goalProgressValue,
                        style: .kid,
                        tint: viewModel.isCompleted
                            ? ColorTokens.Semantic.success
                            : ColorTokens.Brand.primary
                    )
                    Text(viewModel.goalProgressLabel)
                        .font(TypographyTokens.caption(12).monospacedDigit())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Streak card

    @ViewBuilder
    private func streakCard(viewModel: DailyChallengeModels.Load.ViewModel) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.primary.opacity(0.08))) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(ColorTokens.Semantic.warning)
                    .scaleEffect(reduceMotion ? 1.0 : (flamePulse ? 1.08 : 1.0))
                    .animation(
                        reduceMotion
                            ? nil
                            : .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: flamePulse
                    )
                    .accessibilityHidden(true)
                    .onAppear {
                        if !reduceMotion { flamePulse = true }
                    }

                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(viewModel.streakTitle)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    Text(viewModel.longestStreakLabel)
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(1)
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(viewModel.streakAccessibilityLabel))
        .accessibilityHint(Text(viewModel.longestStreakLabel))
    }

    // MARK: - Reward card

    @ViewBuilder
    private func rewardCard(viewModel: DailyChallengeModels.Load.ViewModel) -> some View {
        HSCard(style: .flat) {
            HStack(spacing: SpacingTokens.sp3) {
                rewardSticker(name: viewModel.rewardSticker)

                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text("dailyChallenge.reward.section.title")
                        .font(TypographyTokens.caption(11))
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .foregroundStyle(ColorTokens.Kid.inkMuted)

                    Text(viewModel.rewardTitle)
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)

                    HSBadge(
                        viewModel.rewardSubtitle,
                        style: .filled(ColorTokens.Brand.primary)
                    )
                }
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func rewardSticker(name: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Kid.bgSofter)
                .frame(width: 64, height: 64)

            // Fallback на SF Symbol, если ассета нет в Assets.xcassets
            if let _ = UIImage(named: name) {
                Image(name)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
            } else {
                Image(systemName: "star.fill")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(ColorTokens.Brand.gold)
            }
        }
        .accessibilityHidden(true)
    }

    // MARK: - CTA

    @ViewBuilder
    private func ctaSection(viewModel: DailyChallengeModels.Load.ViewModel) -> some View {
        Button {
            Task { await handleCTA(viewModel: viewModel) }
        } label: {
            HStack {
                Image(systemName: viewModel.isCompleted ? "square.and.arrow.up.fill" : "play.fill")
                    .font(.headline)
                Text(viewModel.ctaTitle)
                    .font(TypographyTokens.cta())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .padding(.horizontal, SpacingTokens.sp4)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityHint(
            Text(viewModel.isCompleted
                 ? "dailyChallenge.cta.share.hint"
                 : "dailyChallenge.cta.start.hint")
        )
    }

    // MARK: - Loading

    private var loadingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ProgressView()
                .controlSize(.large)
            Text("dailyChallenge.loading")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, SpacingTokens.sp10)
    }

    // MARK: - Toast

    @ViewBuilder
    private func toastBanner(text: String) -> some View {
        Text(text)
            .font(TypographyTokens.caption(13))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .padding(.horizontal, SpacingTokens.sp4)
            .padding(.vertical, SpacingTokens.sp2)
            .background(
                Capsule().fill(ColorTokens.Brand.primary)
            )
            .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
            .task {
                try? await Task.sleep(for: .seconds(2.2))
                holder.showToast = false
            }
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = DailyChallengePresenter(displayLogic: holder)
            let statsWorker = DailyChallengeStatsWorker(
                sessionRepository: container.sessionRepository,
                childRepository: container.childRepository
            )
            let interactor = DailyChallengeInteractor(
                statsWorker: statsWorker,
                childRepository: container.childRepository,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = DailyChallengeRouter(
                dismissAction: { [self] in dismiss() },
                startSessionAction: { [self] childId, targetSound in
                    coordinator.navigate(to: .worldMap(childId: childId, targetSound: targetSound))
                },
                shareAction: { [self] _ in
                    showShareSheet = true
                }
            )
        }
        await interactor?.load(request: .init(childId: childId))
    }

    private func handleCTA(viewModel: DailyChallengeModels.Load.ViewModel) async {
        if viewModel.isCompleted {
            await interactor?.shareCompletion(request: .init(childId: childId))
            router?.routeToShareSheet(snapshotText: viewModel.rewardTitle)
        } else {
            let targetSound = interactor?.currentGoal?.targetSound ?? "С"
            await interactor?.startSession(
                request: .init(childId: childId, targetSound: targetSound)
            )
            router?.routeToSession(childId: childId, targetSound: targetSound)
        }
    }
}

// MARK: - DailyChallengeShareSheet (private)

private struct DailyChallengeShareSheet: View {
    let text: String

    var body: some View {
        VStack(spacing: SpacingTokens.sp4) {
            Image(systemName: "square.and.arrow.up.fill")
                .font(.system(size: 48, weight: .bold))
                .foregroundStyle(ColorTokens.Brand.primary)

            Text("dailyChallenge.share.heading")
                .font(TypographyTokens.title(20))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)

            Text(text)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, SpacingTokens.sp4)

            Spacer(minLength: SpacingTokens.sp4)
        }
        .padding(.top, SpacingTokens.sp6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Kid.surface.ignoresSafeArea())
    }
}

// MARK: - Preview

#if DEBUG
#Preview("DailyChallenge / Kid") {
    DailyChallengeView(childId: "preview-child-1")
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
#endif

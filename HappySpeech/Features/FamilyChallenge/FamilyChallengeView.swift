import OSLog
import SwiftUI

// MARK: - FamilyChallengeDisplayLogic

@MainActor
protocol FamilyChallengeDisplayLogic: AnyObject {
    func displayChallenge(viewModel: FamilyChallengeModels.LoadChallenge.ViewModel) async
    func displayClaimedReward(viewModel: FamilyChallengeModels.ClaimReward.ViewModel) async
    func displayShareProgress(viewModel: FamilyChallengeModels.ShareProgress.ViewModel) async
}

// MARK: - Holder

@MainActor
@Observable
final class FamilyChallengeViewModelHolder: FamilyChallengeDisplayLogic {

    var loadVM: FamilyChallengeModels.LoadChallenge.ViewModel?
    var toastMessage: String?
    var confettiShown: Bool = false
    var shareText: String?

    func displayChallenge(viewModel: FamilyChallengeModels.LoadChallenge.ViewModel) async {
        self.loadVM = viewModel
    }

    func displayClaimedReward(viewModel: FamilyChallengeModels.ClaimReward.ViewModel) async {
        self.toastMessage = viewModel.toastMessage
        self.confettiShown = viewModel.confettiShown
    }

    func displayShareProgress(viewModel: FamilyChallengeModels.ShareProgress.ViewModel) async {
        self.shareText = viewModel.shareText
    }
}

// MARK: - FamilyChallengeView

struct FamilyChallengeView: View {

    let parentId: String

    @State private var holder = FamilyChallengeViewModelHolder()
    @State private var interactor: FamilyChallengeInteractor?
    @State private var presenter: FamilyChallengePresenter?
    @State private var router: FamilyChallengeRouter?
    @State private var didBootstrap = false
    @State private var animatedProgress: Double = 0

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.hapticService) private var hapticService

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "FamilyChallenge.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                content
            }
            .navigationTitle(Text("Челлендж недели"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .onChange(of: holder.loadVM?.progressFraction) { _, fraction in
                guard let fraction else { return }
                if reduceMotion {
                    animatedProgress = fraction
                } else {
                    withAnimation(.easeOut(duration: 0.9)) {
                        animatedProgress = fraction
                    }
                }
            }
            .onChange(of: holder.toastMessage) { _, message in
                guard message != nil else { return }
                hapticService.notification(.success)
                Task {
                    try? await Task.sleep(nanoseconds: 1_800_000_000)
                    holder.toastMessage = nil
                }
            }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if let vm = holder.loadVM {
            ScrollView {
                VStack(spacing: SpacingTokens.sp3) {
                    heroCard(vm)
                    progressRing(vm)
                    contributionsSection(vm)
                    streakBadge(vm)
                    actionButtons(vm)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp4)
            }
            .overlay(alignment: .top) { toastOverlay() }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    // MARK: - Hero card

    private func heroCard(_ vm: FamilyChallengeModels.LoadChallenge.ViewModel) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            HStack(spacing: SpacingTokens.sp3) {
                Image(systemName: vm.iconSystemName)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .symbolRenderingMode(.hierarchical)
                    .hsSymbolEffect(.bounce, value: vm.subtitle)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text("\(vm.emojiTag) \(vm.subtitle)")
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(vm.goalLabel)
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(vm.accessibilitySummary))
    }

    // MARK: - Progress ring

    private func progressRing(_ vm: FamilyChallengeModels.LoadChallenge.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.Parent.line, lineWidth: 8)
                    .frame(width: 180, height: 180)
                Circle()
                    .trim(from: 0, to: animatedProgress)
                    .stroke(
                        ColorTokens.Brand.primary,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 180, height: 180)
                VStack(spacing: 2) {
                    Text(vm.progressLabel)
                        .font(TypographyTokens.title(22).monospacedDigit())
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("\(Int((vm.progressFraction * 100).rounded()))%")
                        .font(TypographyTokens.caption(12).monospacedDigit())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Прогресс: \(vm.progressLabel)"))
            .accessibilityValue(Text("\(Int((vm.progressFraction * 100).rounded())) процентов"))
        }
        .padding(.vertical, SpacingTokens.sp2)
    }

    // MARK: - Contributions

    @ViewBuilder
    private func contributionsSection(
        _ vm: FamilyChallengeModels.LoadChallenge.ViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(String(localized: "family.challenge.contributions.title"))
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Parent.ink)
            if vm.contributions.isEmpty {
                // Честное пустое состояние: у семьи ещё нет детей-участников.
                emptyContributionsCard
            } else {
                ForEach(Array(vm.contributions.enumerated()), id: \.element.id) { index, row in
                    contributionRow(row)
                        .hsParallaxTile(factor: 0.3)
                        .scrollTransition(.animated(reduceMotion ? .linear(duration: 0) : .spring(response: 0.5, dampingFraction: 0.85))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0)
                                .scaleEffect(phase.isIdentity ? 1 : 0.96)
                        }
                        .zIndex(Double(vm.contributions.count - index))
                }
            }
        }
    }

    private var emptyContributionsCard: some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "person.2.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .accessibilityHidden(true)
                    Text(String(localized: "family.challenge.empty.title"))
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                }
                Text(String(localized: "family.challenge.empty.message"))
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func contributionRow(_ row: ContributionRowViewModel) -> some View {
        HSCard(style: .flat) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                HStack {
                    Text(row.label)
                        .font(TypographyTokens.headline(15))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer()
                    Text(row.valueLabel)
                        .font(TypographyTokens.body(14).monospacedDigit())
                        .foregroundStyle(ColorTokens.Parent.inkMuted)
                }
                miniProgressBar(fraction: row.progressFraction, isChild: row.isChild)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(row.accessibilityLabel))
    }

    private func miniProgressBar(fraction: Double, isChild: Bool) -> some View {
        let tint = isChild ? ColorTokens.Brand.primary : ColorTokens.Brand.sky
        return GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(ColorTokens.Parent.line)
                RoundedRectangle(cornerRadius: 4)
                    .fill(tint)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, fraction))))
            }
        }
        .frame(height: 6)
    }

    // MARK: - Streak

    private func streakBadge(_ vm: FamilyChallengeModels.LoadChallenge.ViewModel) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.rose.opacity(0.16))) {
            HStack(spacing: SpacingTokens.sp2) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .hsSymbolEffect(.variableColor, value: vm.streakLabel)
                    .accessibilityHidden(true)
                Text(vm.streakLabel)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Actions

    private func actionButtons(_ vm: FamilyChallengeModels.LoadChallenge.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            HSButton(
                String(localized: "family.challenge.share"),
                style: .primary,
                size: .large,
                icon: "square.and.arrow.up"
            ) {
                Task { await shareTapped() }
            }
            .accessibilityHint(Text("Открыть системное окно поделиться прогрессом"))

            if vm.canManage {
                HSButton(
                    String(localized: "family.challenge.change"),
                    style: .secondary,
                    size: .large,
                    icon: "arrow.triangle.2.circlepath"
                ) {
                    Task { await claimTapped() }
                }
                .accessibilityHint(Text("Сменить тип челленджа на следующую неделю"))
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
            }
            .accessibilityLabel(Text("Закрыть"))
        }
    }

    // MARK: - Toast overlay

    @ViewBuilder
    private func toastOverlay() -> some View {
        if let toast = holder.toastMessage {
            HSCard(style: .tinted(ColorTokens.Semantic.success.opacity(0.18))) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(ColorTokens.Semantic.success)
                    Text(toast)
                        .font(TypographyTokens.headline(14))
                        .foregroundStyle(ColorTokens.Parent.ink)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = FamilyChallengePresenter(displayLogic: holder)
        let interactor = FamilyChallengeInteractor(
            realmActor: container.realmActor,
            childRepository: container.childRepository,
            sessionRepository: container.sessionRepository,
            isKidContext: false
        )
        interactor.presenter = presenter
        let router = FamilyChallengeRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.loadChallenge(.init(parentId: parentId))
    }

    private func shareTapped() async {
        guard let interactor else { return }
        await interactor.shareProgress(
            .init(challengeId: holder.loadVM.map { _ in parentId } ?? parentId)
        )
        if let shareText = holder.shareText {
            router?.presentShareSheet(text: shareText)
        }
    }

    private func claimTapped() async {
        guard let interactor else { return }
        await interactor.claimReward(.init(challengeId: parentId))
    }
}

// MARK: - Preview

#Preview("FamilyChallenge — Light") {
    FamilyChallengeView(parentId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("FamilyChallenge — Dark") {
    FamilyChallengeView(parentId: "local-parent")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

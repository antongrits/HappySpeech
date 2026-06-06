import OSLog
import SwiftUI

// MARK: - Holder

@MainActor
@Observable
final class SoundOfTheDayViewModelHolder: SoundOfTheDayDisplayLogic {

    var loadVM: SoundOfTheDayModels.LoadToday.ViewModel?

    func displayLoadToday(viewModel: SoundOfTheDayModels.LoadToday.ViewModel) async {
        self.loadVM = viewModel
    }
}

// MARK: - View

struct SoundOfTheDayView: View {

    let childId: String

    @State private var holder = SoundOfTheDayViewModelHolder()
    @State private var interactor: SoundOfTheDayInteractor?
    @State private var presenter: SoundOfTheDayPresenter?
    @State private var router: SoundOfTheDayRouter?
    @State private var didBootstrap = false

    @Environment(\.exitGame) private var exitGame
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundOfTheDay.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                // Step 10 Batch E — Pattern 1: mesh .kidWarm палитра «звук дня»
                // — тёплый утренний ритуал.
                ColorTokens.Kid.bg.ignoresSafeArea()
                HSMeshGradientBackground(palette: .kidWarm, animated: !reduceMotion)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.18 : 0.30)
                    .blendMode(.softLight)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
                if let vm = holder.loadVM {
                    content(vm)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .animation(reduceMotion ? .none : MotionTokens.spring, value: holder.loadVM?.heroTitle)
            .navigationTitle(Text("sotd.nav.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ vm: SoundOfTheDayModels.LoadToday.ViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                greetingHeader(vm)
                heroCard(vm)
                activitiesSection(vm)
                streakRing(vm)
                Spacer(minLength: SpacingTokens.sp3)
                primaryCta(vm)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp4)
        }
        .accessibilityElement(children: .contain)
    }

    private func greetingHeader(_ vm: SoundOfTheDayModels.LoadToday.ViewModel) -> some View {
        // P1.2: greetingHeader обёрнут в HSCard(.gradientTinted) с Лялей слева.
        HSCard(style: .gradientTinted(GradientTokens.cardRosePrimary), padding: SpacingTokens.sp3) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .waving, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(vm.greeting)
                        .font(TypographyTokens.kidTitle(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.8)
                    Text(vm.subtitle)
                        .font(TypographyTokens.kidBody(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func heroCard(_ vm: SoundOfTheDayModels.LoadToday.ViewModel) -> some View {
        HSCard(style: .gradientTinted(GradientTokens.cardCoralButter), padding: SpacingTokens.sp4) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                // Звук дня — крупная буква-якорь (P1.2, P3: kidDisplay(64))
                HStack(alignment: .center, spacing: SpacingTokens.sp3) {
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.primary.opacity(0.12))
                            .frame(width: 88, height: 88)
                        // P1-FIX: в кружок-якорь подаём ТОЛЬКО букву звука
                        // (vm.soundLetter), а не полный heroTitle «Звук дня: «Р»»,
                        // который kidDisplay(64) обрезал до «З…».
                        Text(vm.soundLetter)
                            .font(TypographyTokens.kidDisplay(64))
                            .foregroundStyle(ColorTokens.Brand.primary)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                        Text(vm.heroTitle)
                            .font(TypographyTokens.kidTitle(22))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(vm.heroReason)
                            .font(TypographyTokens.kidBody(15))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 0)
                    LyalyaMascotView(state: .celebrating, size: 72)
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(vm.accessibilityLabel))
    }

    private func activitiesSection(_ vm: SoundOfTheDayModels.LoadToday.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text("sotd.activities.section.title")
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(vm.activities) { activity in
                    activityChip(activity)
                        // Step 10 Batch E — Pattern 3: scrollTransition stagger
                        // fade+scale на activity chips.
                        .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                            content
                                .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                                .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.94))
                        }
                        // Step 10 Batch E — Pattern 4: parallax на activity tiles.
                        .hsParallaxTile(factor: 0.25)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func activityChip(_ activity: ActivityCard) -> some View {
        Button {
            Task { await selectActivity(activity) }
        } label: {
            VStack(spacing: SpacingTokens.sp1) {
                Image(systemName: activity.systemImage)
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
                Text(activity.title)
                    .font(TypographyTokens.headline(14))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(activity.title))
        .accessibilityHint(Text("sotd.activity.hint"))
    }

    private func streakRing(_ vm: SoundOfTheDayModels.LoadToday.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.Kid.line, lineWidth: 6)
                    .frame(width: 64, height: 64)
                Circle()
                    .trim(from: 0, to: max(0.02, vm.streakProgress))
                    .stroke(
                        ColorTokens.Brand.gold,
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "flame.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    // Step 10 Batch E — Pattern 5: flame pulse — streak alive.
                    .hsSymbolEffect(.pulse, value: vm.streakText)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text("sotd.streak.title")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Text(vm.streakText)
                    .font(TypographyTokens.headline(16).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
        .accessibilityElement(children: .combine)
    }

    private func primaryCta(_ vm: SoundOfTheDayModels.LoadToday.ViewModel) -> some View {
        HSButton(
            vm.primaryCtaTitle,
            style: .primary,
            size: .large,
            icon: "play.fill"
        ) {
            Task { await startDay() }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                exitGame()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text("common.close"))
        }
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = SoundOfTheDayPresenter(displayLogic: holder)
        let router = SoundOfTheDayRouter()
        router.coordinator = coordinator
        let interactor = SoundOfTheDayInteractor(
            presenter: presenter,
            router: router,
            adaptivePlannerService: container.adaptivePlannerService,
            childRepository: container.childRepository,
            childId: childId
        )
        self.presenter = presenter
        self.router = router
        self.interactor = interactor
        await interactor.loadToday(.init(childId: childId))
    }

    private func selectActivity(_ activity: ActivityCard) async {
        interactor?.selectActivity(.init(activity: activity))
    }

    private func startDay() async {
        interactor?.startDay()
    }
}

// MARK: - Preview

#Preview("SoundOfTheDay — Light") {
    SoundOfTheDayView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("SoundOfTheDay — Dark") {
    SoundOfTheDayView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

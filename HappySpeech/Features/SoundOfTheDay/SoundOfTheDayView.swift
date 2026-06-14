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
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                greetingHeader(vm)
                heroCard(vm)
                activitiesSection(vm)
                progressSection(vm)
                primaryCta(vm)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp4)
        }
        .scrollBounceBehavior(.basedOnSize)
        .safeAreaPadding(.bottom, SpacingTokens.sp2)
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
        // kid-sound-detail эталон: крупный фокусный звук-герой слева + Ляля с
        // тёплым пузырём-репликой справа. Soft-lilac glow задаёт «семейный» тон.
        HSCard(style: .gradientTinted(GradientTokens.cardLilacRose), padding: SpacingTokens.sp4) {
            HStack(alignment: .center, spacing: SpacingTokens.sp3) {
                VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                    Text(vm.heroTitle)
                        .font(TypographyTokens.caption(12).weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(ColorTokens.Brand.lilac)
                        .fixedSize(horizontal: false, vertical: true)
                        .minimumScaleFactor(0.85)
                    ZStack {
                        Circle()
                            .fill(ColorTokens.Brand.lilac.opacity(0.14))
                            .frame(width: 104, height: 104)
                        Text(vm.soundLetter)
                            .font(TypographyTokens.kidDisplay(72))
                            .foregroundStyle(ColorTokens.Brand.lilac)
                            .minimumScaleFactor(0.7)
                            .lineLimit(1)
                    }
                    .accessibilityHidden(true)
                    Text(vm.heroReason)
                        .font(TypographyTokens.kidBody(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                VStack(spacing: SpacingTokens.sp1) {
                    Text(soundChantText(vm.soundLetter))
                        .font(TypographyTokens.kidCardTitle(15))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .padding(.horizontal, SpacingTokens.sp2)
                        .padding(.vertical, SpacingTokens.micro)
                        .background(
                            Capsule()
                                .fill(ColorTokens.Kid.surface)
                                .overlay(Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1))
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .accessibilityHidden(true)
                    LyalyaMascotView(state: .celebrating, size: 84)
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
            sectionLabel("sotd.activities.hint.title")
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
                    .fixedSize(horizontal: false, vertical: true)
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

    private func progressSection(_ vm: SoundOfTheDayModels.LoadToday.ViewModel) -> some View {
        // kid-sound-detail эталон: footer-прогресс — золотое кольцо стрика +
        // мягкий gold-track, тёплый подбадривающий текст.
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
                    .hsSymbolEffect(.pulse, value: vm.streakText)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(vm.streakText)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Text("sotd.progress.subtitle")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                track(progress: vm.streakProgress)
                    .padding(.top, SpacingTokens.micro)
            }
            Spacer(minLength: 0)
        }
        .padding(SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }

    /// Тёплая реплика-пузырь Ляли: «р-р-р!» из буквы звука. Для пустой/многобуквенной
    /// буквы — мягкий безопасный фолбэк, без обрезки и пустых строк.
    private func soundChantText(_ letter: String) -> String {
        let trimmed = letter.trimmingCharacters(in: .whitespaces)
        guard let first = trimmed.first else { return "ура!" }
        let s = String(first).lowercased()
        return "\(s)-\(s)-\(s)!"
    }

    private func track(progress: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ColorTokens.Kid.line)
                Capsule()
                    .fill(GradientTokens.celebrationGold)
                    .frame(width: max(8, geo.size.width * min(1, max(0.02, progress))))
            }
        }
        .frame(height: 7)
        .accessibilityHidden(true)
    }

    private func sectionLabel(_ key: LocalizedStringKey) -> some View {
        HStack(spacing: SpacingTokens.tiny) {
            Capsule()
                .fill(ColorTokens.Brand.primaryLo)
                .frame(width: 18, height: 3)
            Text(key)
                .font(TypographyTokens.caption(13).weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Spacer(minLength: 0)
        }
        .padding(.leading, 2)
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

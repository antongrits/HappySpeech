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

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "SoundOfTheDay.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
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
        HStack(spacing: SpacingTokens.sp3) {
            LyalyaMascotView(state: .waving, size: 72)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                Text(vm.greeting)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(vm.subtitle)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            Spacer(minLength: 0)
        }
    }

    private func heroCard(_ vm: SoundOfTheDayModels.LoadToday.ViewModel) -> some View {
        HSCard(style: .tinted(ColorTokens.Brand.butter.opacity(0.18))) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(alignment: .center, spacing: SpacingTokens.sp3) {
                    VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                        Text(vm.heroTitle)
                            .font(TypographyTokens.title(24))
                            .foregroundStyle(ColorTokens.Kid.ink)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                        Text(vm.heroReason)
                            .font(TypographyTokens.body(14))
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                            .lineLimit(nil)
                            .minimumScaleFactor(0.85)
                    }
                    Spacer(minLength: 0)
                    LyalyaMascotView(state: .celebrating, size: 80)
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
                dismiss()
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

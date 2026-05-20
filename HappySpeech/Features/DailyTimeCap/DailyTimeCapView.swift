import OSLog
import SwiftUI

// MARK: - Holder

@MainActor
@Observable
final class DailyTimeCapViewModelHolder: DailyTimeCapDisplayLogic {

    var viewModel: DailyTimeCapModels.Status.ViewModel?

    func displayStatus(viewModel: DailyTimeCapModels.Status.ViewModel) async {
        self.viewModel = viewModel
    }
}

// MARK: - View

struct DailyTimeCapView: View {

    @State private var holder = DailyTimeCapViewModelHolder()
    @State private var interactor: DailyTimeCapInteractor?
    @State private var presenter: DailyTimeCapPresenter?
    @State private var router: DailyTimeCapRouter?
    @State private var didBootstrap = false
    @State private var localEnabled: Bool = false
    @State private var localCap: Int = 30

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "DailyTimeCap.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Parent.bg.ignoresSafeArea()
                if let viewModel = holder.viewModel {
                    content(viewModel)
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(Text(String(localized: "dailyTimeCap.title")))
            .navigationBarTitleDisplayMode(.large)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ viewModel: DailyTimeCapModels.Status.ViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                introCard
                toggleCard(viewModel)
                sliderCard(viewModel)
                progressCard(viewModel)
                privacyNote
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sp3)
            .padding(.bottom, SpacingTokens.sp10)
        }
    }

    // MARK: - Intro

    private var introCard: some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(spacing: SpacingTokens.sp2) {
                    Image(systemName: "clock.badge.checkmark.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(ColorTokens.Brand.sky)
                        .accessibilityHidden(true)
                    Text(String(localized: "dailyTimeCap.intro.title"))
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                }
                Text(String(localized: "dailyTimeCap.intro.body"))
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(nil)
                    .minimumScaleFactor(0.85)
            }
            .padding(SpacingTokens.sp4)
        }
    }

    // MARK: - Toggle

    private func toggleCard(_ viewModel: DailyTimeCapModels.Status.ViewModel) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                Toggle(isOn: enabledBinding) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(String(localized: "dailyTimeCap.toggle.title"))
                            .font(TypographyTokens.headline(16))
                            .foregroundStyle(ColorTokens.Parent.ink)
                        Text(String(localized: "dailyTimeCap.toggle.subtitle"))
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(2)
                            .minimumScaleFactor(0.85)
                    }
                }
                .tint(ColorTokens.Brand.sky)
                .accessibilityHint(String(localized: "dailyTimeCap.toggle.a11y_hint"))
                Text(viewModel.footnote)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .padding(SpacingTokens.sp4)
        }
    }

    // MARK: - Slider

    private func sliderCard(_ viewModel: DailyTimeCapModels.Status.ViewModel) -> some View {
        HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack {
                    Text(String(localized: "dailyTimeCap.slider.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Spacer()
                    Text(localizedMinutes(localCap))
                        .font(TypographyTokens.headline(16).monospacedDigit())
                        .foregroundStyle(ColorTokens.Brand.sky)
                        .accessibilityHidden(true)
                }
                Picker(
                    String(localized: "dailyTimeCap.slider.title"),
                    selection: capBinding(viewModel)
                ) {
                    ForEach(viewModel.availableMinuteOptions, id: \.self) { option in
                        Text(localizedMinutes(option)).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .disabled(!localEnabled)
                .accessibilityLabel(String(localized: "dailyTimeCap.slider.a11y_label"))
                .accessibilityValue(localizedMinutes(localCap))
            }
            .padding(SpacingTokens.sp4)
        }
    }

    // MARK: - Progress

    private func progressCard(_ viewModel: DailyTimeCapModels.Status.ViewModel) -> some View {
        let tint = color(for: viewModel.progressTint)
        return HSCard(style: .elevated) {
            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(String(localized: "dailyTimeCap.progress.title"))
                        .font(TypographyTokens.headline(16))
                        .foregroundStyle(ColorTokens.Parent.ink)
                    Spacer()
                    Text(viewModel.usageLabel)
                        .font(TypographyTokens.body(15).monospacedDigit())
                        .foregroundStyle(tint)
                        .accessibilityLabel(viewModel.usageLabel)
                }
                ProgressView(value: min(1.0, viewModel.progress))
                    .progressViewStyle(.linear)
                    .tint(tint)
                    .accessibilityLabel(viewModel.usageLabel)
                if viewModel.isCapped {
                    HStack(spacing: SpacingTokens.sp1) {
                        Image(systemName: "moon.stars.fill")
                            .foregroundStyle(ColorTokens.Brand.sky)
                            .accessibilityHidden(true)
                        Text(String(localized: "dailyTimeCap.progress.capped_hint"))
                            .font(TypographyTokens.caption(13))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                            .lineLimit(3)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .padding(SpacingTokens.sp4)
        }
    }

    // MARK: - Privacy

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: SpacingTokens.sp1) {
            Image(systemName: "lock.shield")
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .accessibilityHidden(true)
            Text(String(localized: "dailyTimeCap.privacy.note"))
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.sp1)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                router?.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Parent.inkSoft)
            }
            .accessibilityLabel(Text(String(localized: "dailyTimeCap.close.a11y")))
        }
    }

    // MARK: - Bindings

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { localEnabled },
            set: { newValue in
                localEnabled = newValue
                Task { await interactor?.setEnabled(newValue) }
            }
        )
    }

    private func capBinding(_ viewModel: DailyTimeCapModels.Status.ViewModel) -> Binding<Int> {
        Binding(
            get: { localCap },
            set: { newValue in
                guard viewModel.availableMinuteOptions.contains(newValue) else { return }
                localCap = newValue
                Task { await interactor?.setCap(minutes: newValue) }
            }
        )
    }

    // MARK: - Bootstrap

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = DailyTimeCapPresenter(displayLogic: holder)
        let interactor = DailyTimeCapInteractor(
            presenter: presenter,
            tracker: container.dailyUsageTracker
        )
        let router = DailyTimeCapRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.loadStatus()
        // Подтягиваем локальный snapshot из tracker.
        self.localEnabled = container.dailyUsageTracker.isCapEnabled
        self.localCap = container.dailyUsageTracker.capMinutes
    }

    // MARK: - Helpers

    private func color(for tint: DailyTimeCapModels.Status.TintLevel) -> Color {
        switch tint {
        case .green:  return ColorTokens.Semantic.success
        case .yellow: return ColorTokens.Semantic.warning
        case .red:    return ColorTokens.Semantic.error
        }
    }

    private func localizedMinutes(_ minutes: Int) -> String {
        String(localized: "dailyTimeCap.minutes.format")
            .replacingOccurrences(of: "{n}", with: "\(minutes)")
    }
}

// MARK: - Preview

#Preview("DailyTimeCap — Light") {
    DailyTimeCapView()
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

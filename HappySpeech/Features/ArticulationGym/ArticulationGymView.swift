import OSLog
import SwiftUI

// MARK: - ArticulationGymViewModelHolder

@MainActor
@Observable
final class ArticulationGymViewModelHolder: ArticulationGymDisplayLogic {

    var loadVM: ArticulationGymModels.Load.ViewModel?
    var timerVM: ArticulationGymModels.TimerTick.ViewModel?
    var nextVM: ArticulationGymModels.Next.ViewModel?
    var completionVM: ArticulationGymModels.Complete.ViewModel?
    var currentIndex: Int = 0
    var isCompleted: Bool = false

    func displayLoad(viewModel: ArticulationGymModels.Load.ViewModel) async {
        self.loadVM = viewModel
        self.currentIndex = 0
        self.isCompleted = false
        self.completionVM = nil
    }

    func displayTimerTick(viewModel: ArticulationGymModels.TimerTick.ViewModel) async {
        self.timerVM = viewModel
    }

    func displayNext(viewModel: ArticulationGymModels.Next.ViewModel) async {
        self.nextVM = viewModel
        if viewModel.showCompletion {
            self.isCompleted = true
        } else {
            self.currentIndex = viewModel.nextIndex
        }
    }

    func displayComplete(viewModel: ArticulationGymModels.Complete.ViewModel) async {
        self.completionVM = viewModel
        self.isCompleted = true
    }
}

// MARK: - ArticulationGymView (Clean Swift: View)
//
// F-302 v25 — экран «Зарядка для язычка» (детский контур).
//
// Layout:
//   1. Шапка: пикер звуковой группы + прогресс-полоска
//   2. Карточка упражнения: иллюстрация позы + название + инструкция + круговой таймер
//   3. Ляля (HSMascotView) — поддержка во время разминки
//   4. Завершающий экран: анимация + «Начать урок» / «Ещё раз»
//
// Без микрофона, AR, ML. Accessibility: VoiceOver на таймере и кнопках,
// Dynamic Type, Reduced Motion.

struct ArticulationGymView: View {

    let childId: String
    let initialGroup: ArticulationSoundGroup

    @State private var holder = ArticulationGymViewModelHolder()
    @State private var interactor: ArticulationGymInteractor?
    @State private var presenter: ArticulationGymPresenter?
    @State private var router: ArticulationGymRouter?
    @State private var selectedGroup: ArticulationSoundGroup
    @State private var secondsRemaining: Int = 0
    @State private var timerTask: Task<Void, Never>?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    init(childId: String, soundGroup: ArticulationSoundGroup = .hissing) {
        self.childId = childId
        self.initialGroup = soundGroup
        self._selectedGroup = State(initialValue: soundGroup)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()

                if let viewModel = holder.loadVM {
                    if holder.isCompleted {
                        completionView(viewModel: viewModel)
                    } else {
                        gymContent(viewModel: viewModel)
                    }
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
            .navigationTitle(Text("articulationGym.screen.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        stopTimer()
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text("articulationGym.close.a11y"))
                }
            }
            .task {
                await setupAndLoad()
            }
            .onDisappear { stopTimer() }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Gym content

    @ViewBuilder
    private func gymContent(viewModel: ArticulationGymModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp4) {
            HSSegmentedPicker(
                selection: $selectedGroup,
                items: ArticulationSoundGroup.allCases,
                style: .capsule,
                titleProvider: { LocalizedStringKey($0.titleKey) }
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .onChange(of: selectedGroup) { _, newGroup in
                Task { await reloadGroup(newGroup) }
            }

            HSProgressBar(
                value: progressValue(viewModel: viewModel),
                style: .kid,
                tint: ColorTokens.Brand.lilac
            )
            .padding(.horizontal, SpacingTokens.screenEdge)
            .accessibilityLabel(
                Text(
                    String(
                        format: String(localized: "articulationGym.progress.a11y"),
                        holder.currentIndex + 1,
                        viewModel.totalCount
                    )
                )
            )

            if let exercise = currentExercise(viewModel: viewModel) {
                exerciseCard(exercise)
                    .padding(.horizontal, SpacingTokens.screenEdge)
            }

            Spacer()

            HStack {
                Spacer()
                HSMascotView(mood: .encouraging, size: 96)
                    .accessibilityHidden(true)
                    .padding(.trailing, SpacingTokens.sp4)
            }
        }
        .padding(.top, SpacingTokens.sp4)
    }

    @ViewBuilder
    private func exerciseCard(_ exercise: ExerciseViewModel) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: exercise.illustrationSymbol)
                    .font(.system(size: 88, weight: .regular))
                    .foregroundStyle(ColorTokens.Brand.lilac)
                    .frame(maxWidth: .infinity, minHeight: 140)
                    .accessibilityHidden(true)

                Text(exercise.title)
                    .font(TypographyTokens.title(22).weight(.bold))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)

                Text(exercise.instruction)
                    .font(TypographyTokens.body(15))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)

                HSProgressRing(
                    value: holder.timerVM?.ringProgress ?? 0,
                    size: 72,
                    lineWidth: 8,
                    color: ColorTokens.Brand.lilac,
                    label: holder.timerVM?.timerText ?? String(exercise.durationSeconds)
                )
                .accessibilityLabel(
                    Text(
                        holder.timerVM?.timerAccessibilityLabel
                            ?? String.localizedStringWithFormat(
                                String(localized: "articulationGym.timer.a11y"),
                                exercise.durationSeconds
                            )
                    )
                )

                HSButton(
                    String(localized: "articulationGym.skip.button"),
                    style: .ghost,
                    size: .medium
                ) {
                    Task { await advance() }
                }
                .accessibilityHint(Text("articulationGym.skip.hint"))
            }
        }
        .id(exercise.id)
        .transition(reduceMotion ? .identity : .opacity)
        .animation(reduceMotion ? nil : .spring(duration: 0.35), value: exercise.id)
    }

    // MARK: - Completion

    @ViewBuilder
    private func completionView(viewModel: ArticulationGymModels.Load.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp5) {
            Spacer()

            HSMascotView(mood: .celebrating, size: 140)
                .accessibilityHidden(true)

            Text(holder.completionVM?.celebrationText ?? String(localized: "articulationGym.completion.text"))
                .font(TypographyTokens.title(22).weight(.bold))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Spacer()

            VStack(spacing: SpacingTokens.sp3) {
                HSButton(
                    String(localized: "articulationGym.completion.startLesson"),
                    style: .primary,
                    size: .large,
                    icon: "play.fill"
                ) {
                    router?.routeToWorldMap()
                }
                .accessibilityHint(Text("articulationGym.completion.startLesson.hint"))

                HSButton(
                    String(localized: "articulationGym.completion.again"),
                    style: .secondary,
                    size: .large,
                    icon: "arrow.clockwise"
                ) {
                    Task { await reloadGroup(selectedGroup) }
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    // MARK: - Helpers

    private func currentExercise(
        viewModel: ArticulationGymModels.Load.ViewModel
    ) -> ExerciseViewModel? {
        guard holder.currentIndex >= 0, holder.currentIndex < viewModel.exercises.count else {
            return nil
        }
        return viewModel.exercises[holder.currentIndex]
    }

    private func progressValue(viewModel: ArticulationGymModels.Load.ViewModel) -> Double {
        guard viewModel.totalCount > 0 else { return 0 }
        return Double(holder.currentIndex) / Double(viewModel.totalCount)
    }

    // MARK: - Wiring

    private func setupAndLoad() async {
        if interactor == nil {
            let presenter = ArticulationGymPresenter(displayLogic: holder)
            let interactor = ArticulationGymInteractor(
                soundGroup: selectedGroup,
                worker: ArticulationGymWorker(),
                analyticsService: container.analyticsService,
                hapticService: container.hapticService
            )
            interactor.presenter = presenter
            self.presenter = presenter
            self.interactor = interactor
            self.router = ArticulationGymRouter(
                coordinator: coordinator,
                childId: childId,
                dismissAction: { dismiss() }
            )
        }
        await reloadGroup(selectedGroup)
    }

    private func reloadGroup(_ group: ArticulationSoundGroup) async {
        stopTimer()
        selectedGroup = group
        await interactor?.loadGym(request: .init(soundGroup: group))
        startTimerForCurrentExercise()
    }

    private func startTimerForCurrentExercise() {
        stopTimer()
        guard let viewModel = holder.loadVM,
              let exercise = currentExercise(viewModel: viewModel) else { return }
        secondsRemaining = exercise.durationSeconds
        let index = holder.currentIndex
        timerTask = Task { @MainActor in
            await interactor?.timerTick(
                request: .init(exerciseIndex: index, secondsRemaining: secondsRemaining)
            )
            while secondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                secondsRemaining -= 1
                await interactor?.timerTick(
                    request: .init(exerciseIndex: index, secondsRemaining: secondsRemaining)
                )
            }
            if !Task.isCancelled {
                await advance()
            }
        }
    }

    private func advance() async {
        stopTimer()
        await interactor?.nextExercise(request: .init(currentIndex: holder.currentIndex))
        if holder.isCompleted {
            await interactor?.completeGym(request: .init())
        } else {
            startTimerForCurrentExercise()
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }
}

// MARK: - Preview

#if DEBUG
#Preview("ArticulationGym") {
    ArticulationGymView(childId: "preview-child-1", soundGroup: .hissing)
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}
#endif

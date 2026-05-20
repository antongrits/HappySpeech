import OSLog
import SwiftUI

// MARK: - Holder

@MainActor
@Observable
final class LogorhythmicsViewModelHolder: LogorhythmicsDisplayLogic {

    var loadVM: LogorhythmicsModels.LoadExercises.ViewModel?
    var selectVM: LogorhythmicsModels.SelectExercise.ViewModel?
    var beatVM: LogorhythmicsModels.BeatTick.ViewModel?
    var finishVM: LogorhythmicsModels.FinishExercise.ViewModel?
    var phase: Phase = .picking
    var isPlaying: Bool = false

    enum Phase: Equatable {
        case picking
        case ready      // выбрано упражнение, ждём «Старт».
        case playing    // метроном работает, пульс на экране.
        case result
    }

    func displayLoadExercises(viewModel: LogorhythmicsModels.LoadExercises.ViewModel) async {
        self.loadVM = viewModel
        self.phase = .picking
    }

    func displaySelectExercise(viewModel: LogorhythmicsModels.SelectExercise.ViewModel) async {
        self.selectVM = viewModel
        self.phase = .ready
    }

    func displayBeatTick(viewModel: LogorhythmicsModels.BeatTick.ViewModel) async {
        self.beatVM = viewModel
        // phase=.playing управляется самим View через startPlayback (из interactor).
    }

    func displayFinishExercise(viewModel: LogorhythmicsModels.FinishExercise.ViewModel) async {
        self.finishVM = viewModel
        self.phase = .result
        self.isPlaying = false
    }
}

// MARK: - View

struct LogorhythmicsView: View {

    let childId: String

    @State private var holder = LogorhythmicsViewModelHolder()
    @State private var interactor: LogorhythmicsInteractor?
    @State private var presenter: LogorhythmicsPresenter?
    @State private var router: LogorhythmicsRouter?
    @State private var didBootstrap = false
    @State private var ringPulse: Bool = false

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "Logorhythmics.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                switch holder.phase {
                case .picking:  pickingSection
                case .ready:    readySection
                case .playing:  playingSection
                case .result:   resultSection
                }
            }
            .navigationTitle(Text("Логоритмика"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
            .onDisappear {
                interactor?.stopPlayback()
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Picking

    private var pickingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                    if let load = holder.loadVM {
                        ForEach(load.categoriesInOrder, id: \.self) { category in
                            categorySection(
                                category: category,
                                title: load.categoryTitles[category] ?? category.capitalized,
                                items: load.grouped[category] ?? []
                            )
                        }
                    } else {
                        ProgressView().padding()
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
            }
            instructionBar
        }
    }

    private func categorySection(
        category: String,
        title: String,
        items: [LogorhythmicsExercise]
    ) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(title)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: SpacingTokens.sp2)],
                spacing: SpacingTokens.sp2
            ) {
                ForEach(items) { exercise in
                    exerciseButton(exercise, category: category)
                }
            }
        }
    }

    private func exerciseButton(_ exercise: LogorhythmicsExercise, category: String) -> some View {
        Button {
            Task { await selectExercise(exercise.id) }
        } label: {
            VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
                HStack(spacing: SpacingTokens.sp1) {
                    Image(systemName: iconForCategory(category))
                        .font(.system(size: 22))
                        .foregroundStyle(ColorTokens.Brand.butter)
                        .accessibilityHidden(true)
                    Text("\(exercise.bpm) уд/мин")
                        .font(TypographyTokens.caption(11).monospacedDigit())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
                Text(exercise.title)
                    .font(TypographyTokens.headline(15))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.leading)
                Text("С \(exercise.ageMin) лет · \(exercise.totalBeats) долей")
                    .font(TypographyTokens.caption(11))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
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
        .accessibilityLabel(Text(exercise.title))
        .accessibilityHint(Text("Темп \(exercise.bpm) ударов в минуту. Нажми, чтобы открыть."))
    }

    private var instructionBar: some View {
        Text("Выбери chant и двигайся в такт.")
            .font(TypographyTokens.body(14))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.bottom, SpacingTokens.sp3)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Ready

    private var readySection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            if let vm = holder.selectVM {
                exerciseHeader(vm)
                rhymeCard(vm.exercise.rhymeText)
                hintCard(vm.hintMessage)
                Spacer(minLength: 0)
                startButton
            } else {
                ProgressView().padding()
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp3)
    }

    private func exerciseHeader(_ vm: LogorhythmicsModels.SelectExercise.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: iconForCategory(vm.exercise.category))
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Brand.butter)
                .accessibilityHidden(true)
            Text(vm.exercise.title)
                .font(TypographyTokens.title(26))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Text("\(vm.exercise.bpm) уд/мин · \(vm.totalBeats) долей")
                .font(TypographyTokens.caption(12).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func rhymeCard(_ text: String) -> some View {
        Text(text)
            .font(TypographyTokens.headline(18))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(ColorTokens.Kid.surface)
            )
    }

    private func hintCard(_ hint: String) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(ColorTokens.Brand.butter)
                .accessibilityHidden(true)
            Text(hint)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.sm)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
    }

    private var startButton: some View {
        Button {
            Task { await beginPlayback() }
        } label: {
            Label("Старт", systemImage: "play.fill")
                .font(TypographyTokens.headline(17))
                .frame(maxWidth: .infinity, minHeight: 64)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Brand.primary)
                )
                .foregroundStyle(ColorTokens.Overlay.onAccent)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Начать метроном и двигаться в такт."))
    }

    // MARK: - Playing

    private var playingSection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            if let vm = holder.selectVM {
                Text(vm.exercise.title)
                    .font(TypographyTokens.title(22))
                    .foregroundStyle(ColorTokens.Kid.ink)
                rhymeCard(vm.exercise.rhymeText)
                beatRing(vm: holder.beatVM, totalBeats: vm.totalBeats)
                Spacer(minLength: 0)
                stopButton
            }
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.top, SpacingTokens.sp3)
    }

    private func beatRing(
        vm: LogorhythmicsModels.BeatTick.ViewModel?,
        totalBeats: Int
    ) -> some View {
        let beatIndex = vm?.beatIndex ?? 0
        let isStrong = vm?.isStrong ?? false
        let ringColor: Color = isStrong ? ColorTokens.Brand.primary : ColorTokens.Brand.butter
        return VStack(spacing: SpacingTokens.sp3) {
            ZStack {
                Circle()
                    .stroke(ColorTokens.Kid.line, lineWidth: 4)
                    .frame(width: 200, height: 200)
                Circle()
                    .fill(ringColor.opacity(0.18))
                    .frame(width: 200, height: 200)
                    .scaleEffect(reduceMotion ? 1.0 : (ringPulse ? 1.10 : 0.95))
                    .opacity(reduceMotion ? 1.0 : (ringPulse ? 0.6 : 1.0))
                    .animation(
                        reduceMotion ? .none : .easeInOut(duration: 0.18),
                        value: ringPulse
                    )
                if reduceMotion {
                    Circle()
                        .fill(ringColor)
                        .frame(width: 24, height: 24)
                }
                VStack(spacing: 2) {
                    Text("\(beatIndex + 1)")
                        .font(TypographyTokens.title(40).monospacedDigit())
                        .foregroundStyle(ColorTokens.Kid.ink)
                    Text("из \(totalBeats)")
                        .font(TypographyTokens.caption(12).monospacedDigit())
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(vm?.accessibilityLabel ?? "Доля \(beatIndex + 1) из \(totalBeats)"))
        }
        .onChange(of: holder.beatVM?.beatIndex) { _, _ in
            guard !reduceMotion else { return }
            ringPulse = true
            Task {
                try? await Task.sleep(nanoseconds: 140_000_000)
                ringPulse = false
            }
        }
    }

    private var stopButton: some View {
        Button {
            Task { await stopPlayback() }
        } label: {
            Label("Остановить", systemImage: "stop.fill")
                .font(TypographyTokens.headline(17))
                .frame(maxWidth: .infinity, minHeight: 56)
                .background(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .fill(ColorTokens.Semantic.error)
                )
                .foregroundStyle(ColorTokens.Overlay.onAccent)
        }
        .buttonStyle(.plain)
        .accessibilityHint(Text("Закончить упражнение и посмотреть результат."))
    }

    // MARK: - Result

    private var resultSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                if let vm = holder.finishVM {
                    resultHeader(vm)
                    resultStars(vm)
                    resultStats(vm)
                    feedbackCard(vm)
                    actionButtons
                }
            }
            .padding(SpacingTokens.screenEdge)
        }
        .accessibilityElement(children: .contain)
    }

    private func resultHeader(_ vm: LogorhythmicsModels.FinishExercise.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: iconForCategory(vm.exercise.category))
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Brand.butter)
                .accessibilityHidden(true)
            Text(vm.exercise.title)
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
                .multilineTextAlignment(.center)
            Text("Темп \(vm.exercise.bpm) уд/мин")
                .font(TypographyTokens.caption(12).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func resultStars(_ vm: LogorhythmicsModels.FinishExercise.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp1) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < vm.stars ? "star.fill" : "star")
                    .font(.system(size: 36))
                    .foregroundStyle(index < vm.stars
                                     ? ColorTokens.Brand.gold
                                     : ColorTokens.Kid.inkSoft)
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(Text("\(vm.stars) из 3 звёзд"))
    }

    private func resultStats(_ vm: LogorhythmicsModels.FinishExercise.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            HStack {
                Text("Точность ритма")
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                Spacer()
                Text("\(vm.f1Percent)%")
                    .font(TypographyTokens.headline(14).monospacedDigit())
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            Text(vm.hitsLabel)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(vm.detailLabel)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
    }

    private func feedbackCard(_ vm: LogorhythmicsModels.FinishExercise.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text(vm.feedbackTitle)
                .font(TypographyTokens.headline(16))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(vm.feedbackBody)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(vm.accessibilityLabel))
    }

    private var actionButtons: some View {
        HStack(spacing: SpacingTokens.sp2) {
            Button {
                Task { await restartFlow() }
            } label: {
                Text("Ещё chant")
                    .font(TypographyTokens.headline(16))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Kid.surfaceAlt)
                    )
                    .foregroundStyle(ColorTokens.Kid.ink)
            }
            .buttonStyle(.plain)
            Button {
                dismiss()
            } label: {
                Text("Готово")
                    .font(TypographyTokens.headline(16))
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Brand.primary)
                    )
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            if holder.phase == .ready || holder.phase == .playing {
                Button {
                    Task { await backToPicking() }
                } label: {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ColorTokens.Kid.inkSoft)
                }
                .accessibilityLabel(Text("Назад к списку"))
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                interactor?.stopPlayback()
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(ColorTokens.Kid.inkSoft)
            }
            .accessibilityLabel(Text("Закрыть"))
        }
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = LogorhythmicsPresenter(displayLogic: holder)
        let interactor = LogorhythmicsInteractor(presenter: presenter)
        let router = LogorhythmicsRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.loadExercises()
    }

    private func selectExercise(_ id: String) async {
        guard let interactor else { return }
        await interactor.selectExercise(id: id)
    }

    private func beginPlayback() async {
        guard let interactor else { return }
        holder.phase = .playing
        holder.isPlaying = true
        interactor.startPlayback()
    }

    private func stopPlayback() async {
        interactor?.stopPlayback()
        // Forward в finish — если ещё не пришёл сам.
        if let id = holder.selectVM?.exercise.id,
           let exercise = LogorhythmicsCorpus.exercise(id: id) {
            await interactor?.finishForTests(exercise: exercise)
        }
    }

    private func backToPicking() async {
        interactor?.clearSelection()
        holder.selectVM = nil
        holder.beatVM = nil
        holder.phase = .picking
    }

    private func restartFlow() async {
        interactor?.clearSelection()
        holder.selectVM = nil
        holder.beatVM = nil
        holder.finishVM = nil
        holder.phase = .picking
    }

    // MARK: - Helpers

    private func iconForCategory(_ category: String) -> String {
        switch category {
        case "топот":   return "figure.walk"
        case "хлопок":  return "hands.clap.fill"
        case "качание": return "wind"
        default:        return "music.note"
        }
    }
}

// MARK: - Preview

#Preview("Logorhythmics — Light") {
    LogorhythmicsView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("Logorhythmics — Dark") {
    LogorhythmicsView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

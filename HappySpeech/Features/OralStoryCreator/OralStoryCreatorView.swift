import OSLog
import SwiftUI

// MARK: - Holder

@MainActor
@Observable
final class OralStoryCreatorViewModelHolder: OralStoryCreatorDisplayLogic {

    var loadVM: OralStoryCreatorModels.LoadStimuli.ViewModel?
    var selectVM: OralStoryCreatorModels.Select.ViewModel?
    var resultVM: OralStoryCreatorModels.RecordResult.ViewModel?
    var phase: Phase = .selecting
    var isRecording: Bool = false

    enum Phase: Equatable {
        case selecting
        case recording
        case result
    }

    func displayLoadStimuli(viewModel: OralStoryCreatorModels.LoadStimuli.ViewModel) async {
        self.loadVM = viewModel
        self.phase = .selecting
    }

    func displaySelect(viewModel: OralStoryCreatorModels.Select.ViewModel) async {
        self.selectVM = viewModel
    }

    func displayRecordResult(viewModel: OralStoryCreatorModels.RecordResult.ViewModel) async {
        self.resultVM = viewModel
        self.phase = .result
        self.isRecording = false
    }
}

// MARK: - View

struct OralStoryCreatorView: View {

    let childId: String

    @State private var holder = OralStoryCreatorViewModelHolder()
    @State private var interactor: OralStoryCreatorInteractor?
    @State private var presenter: OralStoryCreatorPresenter?
    @State private var router: OralStoryCreatorRouter?
    @State private var didBootstrap = false
    @State private var recordCountdown: Int = 60

    @Environment(\.dismiss) private var dismiss
    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator

    private static let logger = Logger(
        subsystem: "ru.happyspeech", category: "OralStoryCreator.View"
    )

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                switch holder.phase {
                case .selecting:   selectingSection
                case .recording:   recordingSection
                case .result:      resultSection
                }
            }
            .navigationTitle(Text("storyCreator.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task { await bootstrap() }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Selecting

    private var selectingSection: some View {
        VStack(spacing: SpacingTokens.sp3) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: SpacingTokens.sp4) {
                    if let load = holder.loadVM {
                        ForEach(load.categoriesInOrder, id: \.self) { category in
                            categorySection(name: category,
                                            items: load.grouped[category] ?? [])
                        }
                    } else {
                        ProgressView().padding()
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
            if let select = holder.selectVM {
                statusBar(select)
            }
        }
    }

    private func categorySection(name: String, items: [StimulusPicture]) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(name.capitalized)
                .font(TypographyTokens.headline(17))
                .foregroundStyle(ColorTokens.Kid.ink)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: SpacingTokens.sp2)],
                      spacing: SpacingTokens.sp2) {
                ForEach(items) { stimulus in
                    stimulusButton(stimulus)
                }
            }
        }
    }

    private func stimulusButton(_ stimulus: StimulusPicture) -> some View {
        let isSelected = holder.selectVM?.selectedIds.contains(stimulus.id) ?? false
        return Button {
            Task { await interactor?.toggleSelection(stimulus.id) }
        } label: {
            VStack(spacing: SpacingTokens.sp1) {
                Image(systemName: stimulus.symbol)
                    .font(.system(size: 36))
                    .foregroundStyle(isSelected
                                     ? ColorTokens.Overlay.onAccent
                                     : ColorTokens.Brand.rose)
                Text(stimulus.title)
                    .font(TypographyTokens.caption(12))
                    .foregroundStyle(isSelected
                                     ? ColorTokens.Overlay.onAccent
                                     : ColorTokens.Kid.ink)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity, minHeight: 96)
            .padding(SpacingTokens.sp2)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .fill(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: RadiusTokens.card)
                    .strokeBorder(isSelected ? ColorTokens.Brand.primary : ColorTokens.Kid.line,
                                  lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(stimulus.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func statusBar(_ select: OralStoryCreatorModels.Select.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            Text(select.statusMessage)
                .font(TypographyTokens.body(14))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
            Button {
                Task { await beginRecording() }
            } label: {
                Text("storyCreator.button.record")
                    .font(TypographyTokens.headline(17))
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(select.canStartRecording
                                  ? ColorTokens.Brand.primary
                                  : ColorTokens.Kid.surfaceAlt)
                    )
                    .foregroundStyle(select.canStartRecording
                                     ? ColorTokens.Overlay.onAccent
                                     : ColorTokens.Kid.inkSoft)
            }
            .buttonStyle(.plain)
            .disabled(!select.canStartRecording)
            .accessibilityHint(Text(select.statusMessage))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.bottom, SpacingTokens.sp3)
    }

    // MARK: - Recording

    private var recordingSection: some View {
        VStack(spacing: SpacingTokens.sp4) {
            Image(systemName: "mic.fill")
                .font(.system(size: 72))
                .foregroundStyle(ColorTokens.Semantic.error)
            Text("storyCreator.recording.title")
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text("\(recordCountdown)")
                .font(TypographyTokens.title(36).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Button {
                Task { await stopRecording() }
            } label: {
                Text("storyCreator.button.stop")
                    .font(TypographyTokens.headline(18))
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Semantic.error)
                    )
                    .foregroundStyle(ColorTokens.Overlay.onAccent)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .padding(SpacingTokens.screenEdge)
        .task { await runRecordCountdown() }
    }

    private func runRecordCountdown() async {
        recordCountdown = 60
        while recordCountdown > 0, holder.phase == .recording {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            recordCountdown -= 1
        }
        if holder.phase == .recording {
            await stopRecording()
        }
    }

    // MARK: - Result

    private var resultSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SpacingTokens.sp3) {
                if let vm = holder.resultVM {
                    resultHeader(vm)
                    transcriptCard(vm)
                    metricsCard(vm)
                    Button {
                        dismiss()
                    } label: {
                        Text("storyCreator.button.done")
                            .font(TypographyTokens.headline(17))
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
            .padding(SpacingTokens.screenEdge)
        }
    }

    private func resultHeader(_ vm: OralStoryCreatorModels.RecordResult.ViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp1) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 56))
                .foregroundStyle(ColorTokens.Brand.mint)
            Text("storyCreator.result.title")
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(vm.durationLabel)
                .font(TypographyTokens.caption(13).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private func transcriptCard(_ vm: OralStoryCreatorModels.RecordResult.ViewModel) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp1) {
            Text("storyCreator.result.transcript")
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            Text(vm.transcript.isEmpty
                 ? String(localized: "storyCreator.result.empty")
                 : vm.transcript)
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineLimit(nil)
                .multilineTextAlignment(.leading)
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .strokeBorder(ColorTokens.Kid.line, lineWidth: 1)
        )
        .accessibilityLabel(Text(vm.accessibilityLabel))
    }

    private func metricsCard(_ vm: OralStoryCreatorModels.RecordResult.ViewModel) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            metricItem(value: "\(vm.totalWords)", label: "storyCreator.metric.total")
            metricItem(value: "\(vm.uniqueWords)", label: "storyCreator.metric.unique")
            metricItem(value: "\(vm.lexicalDiversityPercent)%", label: "storyCreator.metric.ttr")
        }
        .padding(SpacingTokens.sp3)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(ColorTokens.Kid.surfaceAlt)
        )
    }

    private func metricItem(value: String, label: LocalizedStringResource) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(TypographyTokens.title(20).monospacedDigit())
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(label)
                .font(TypographyTokens.caption(11))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
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
            .accessibilityLabel(Text("storyCreator.close.a11y"))
        }
    }

    // MARK: - Lifecycle

    private func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true
        let presenter = OralStoryCreatorPresenter(displayLogic: holder)
        let interactor = OralStoryCreatorInteractor(
            presenter: presenter,
            audioService: container.audioService,
            asrService: container.asrService,
            realmActor: container.realmActor,
            childId: childId
        )
        let router = OralStoryCreatorRouter()
        router.coordinator = coordinator
        self.presenter = presenter
        self.interactor = interactor
        self.router = router
        await interactor.loadStimuli()
    }

    private func beginRecording() async {
        guard let interactor else { return }
        await interactor.startRecording()
        holder.phase = .recording
        holder.isRecording = true
    }

    private func stopRecording() async {
        guard let interactor, holder.phase == .recording else { return }
        holder.isRecording = false
        await interactor.stopRecordingAndProcess()
    }
}

// MARK: - Preview

#Preview("StoryCreator — Light") {
    OralStoryCreatorView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

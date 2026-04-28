import SwiftUI

// MARK: - FamilyVoiceScene (VIP container)

@MainActor
final class FamilyVoiceScene {
    let interactor: FamilyVoiceInteractor
    let presenter: FamilyVoicePresenter
    let display: FamilyVoiceDisplay

    init(realmActor: RealmActor, pronunciationScorer: (any PronunciationScorerService)? = nil) {
        let display = FamilyVoiceDisplay()
        let presenter = FamilyVoicePresenter()
        let interactor = FamilyVoiceInteractor(
            realmActor: realmActor,
            pronunciationScorer: pronunciationScorer
        )
        presenter.display = display
        interactor.presenter = presenter
        self.display = display
        self.presenter = presenter
        self.interactor = interactor
    }
}

// MARK: - FamilyVoiceDisplay (@Observable ViewModel holder)

@Observable
@MainActor
final class FamilyVoiceDisplay: FamilyVoiceDisplayLogic {
    var viewModel: FamilyVoiceViewModel = FamilyVoiceViewModel(
        mode: .recorder,
        recordingState: .idle,
        selectedWord: FamilyVoiceModels.targetWordsRaw.first ?? "мяч",
        recordings: [],
        currentScore: nil,
        feedback: nil,
        canDone: false,
        waveformLevels: [],
        liveTranscript: nil,
        showFeedback: false,
        feedbackIsCorrect: false,
        toastMessage: nil
    )
    var errorMessage: String?

    func displayRecordings(_ vm: FamilyVoiceViewModel) { viewModel = vm }
    func displayRecordingStarted(_ vm: FamilyVoiceViewModel) { viewModel = vm }
    func displayRecordingStopped(_ vm: FamilyVoiceViewModel) { viewModel = vm }
    func displayPlayback(_ vm: FamilyVoiceViewModel) { viewModel = vm }
    func displayDeletion(_ vm: FamilyVoiceViewModel) { viewModel = vm }
    func displayChildScore(_ vm: FamilyVoiceViewModel) { viewModel = vm }
    func displayWordChanged(_ vm: FamilyVoiceViewModel) { viewModel = vm }
    func displayError(_ message: String) { errorMessage = message }
}

// MARK: - FamilyVoiceView

struct FamilyVoiceView: View {

    @Environment(AppContainer.self) private var container
    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene: FamilyVoiceScene?
    @State private var isRecording = false
    @State private var showDeleteConfirm = false
    @State private var pendingDeleteId: String?
    @State private var showSplitView = false

    // Default parentId — in production pass from ParentHome
    var parentId: String = "local-parent"

    var body: some View {
        NavigationStack {
            Group {
                if let scene {
                    recorderContent(scene: scene)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(ColorTokens.Parent.bg.ignoresSafeArea())
                }
            }
            .navigationTitle(String(localized: "parent_child.recorder.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationDestination(isPresented: $showSplitView) {
                if let scene {
                    FamilyVoiceSplitView(
                        recordings: scene.display.viewModel.recordings,
                        parentId: parentId,
                        realmActor: container.realmActor
                    )
                }
            }
        }
        .task {
            if scene == nil {
                scene = FamilyVoiceScene(
                    realmActor: container.realmActor,
                    pronunciationScorer: container.pronunciationService
                )
            }
            await scene?.interactor.fetchRecordings(.init(parentId: parentId))
        }
    }

    // MARK: - Recorder Content

    @ViewBuilder
    private func recorderContent(scene: FamilyVoiceScene) -> some View {
        let vm = scene.display.viewModel
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.sectionGap) {
                headerCard
                    .padding(.top, SpacingTokens.sp6)

                wordPickerSection(vm: vm, scene: scene)

                recorderSection(vm: vm, scene: scene)

                recordingsListSection(vm: vm, scene: scene)

                doneCTA(vm: vm)
                    .padding(.bottom, SpacingTokens.sp8)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .background(ColorTokens.Parent.bg.ignoresSafeArea())
        .alert(String(localized: "parent_child.error.recording_failed"),
               isPresented: .constant(scene.display.errorMessage != nil)) {
            Button(String(localized: "OK"), role: .cancel) {
                scene.display.errorMessage = nil
            }
        } message: {
            if let msg = scene.display.errorMessage {
                Text(msg)
            }
        }
        .confirmationDialog(
            String(localized: "parent_child.recorder.cta.delete"),
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(String(localized: "parent_child.recorder.cta.delete"), role: .destructive) {
                if let id = pendingDeleteId {
                    Task { await scene.interactor.deleteRecording(.init(recordingId: id)) }
                }
            }
            Button(String(localized: "OK"), role: .cancel) {}
        }
        .scaleEffect(1.0)
        .opacity(1.0)
        .onAppear {
            withAnimation(reduceMotion ? .none : MotionTokens.spring) {}
        }
    }

    // MARK: - [1] Header Card

    private var headerCard: some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 56, weight: .medium))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)

                Text(String(localized: "parent_child.recorder.title"))
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)

                Text(String(localized: "parent_child.recorder.subtitle"))
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
                    .ctaTextStyle()
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.sp4)
        }
        .environment(\.circuitContext, .parent)
    }

    // MARK: - [2] Word Picker Section

    private func wordPickerSection(vm: FamilyVoiceViewModel, scene: FamilyVoiceScene) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text(String(localized: "parent_child.word.picker.label"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Parent.inkMuted)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: SpacingTokens.regular) {
                    ForEach(FamilyVoiceModels.targetWordsRaw, id: \.self) { word in
                        wordChip(word: word, isSelected: vm.selectedWord == word, scene: scene)
                    }
                }
                .padding(.vertical, SpacingTokens.sp1)
            }
        }
    }

    private func wordChip(word: String, isSelected: Bool, scene: FamilyVoiceScene) -> some View {
        Button {
            withAnimation(MotionTokens.spring) {
                scene.interactor.selectWord(word)
            }
        } label: {
            Text(word)
                .font(TypographyTokens.body(15).weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.white : ColorTokens.Parent.ink)
                .padding(.horizontal, SpacingTokens.sp3)
                .padding(.vertical, SpacingTokens.sp2)
                .background(
                    Capsule()
                        .fill(isSelected ? ColorTokens.Brand.primary : ColorTokens.Parent.surface)
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            isSelected ? ColorTokens.Brand.primary : ColorTokens.Parent.inkSoft.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
        .frame(minWidth: 56, minHeight: 36)
        .accessibilityLabel(String(localized: "parent_child.a11y.word_chip_prefix") + word)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    // MARK: - [3] Recorder Section

    private func recorderSection(vm: FamilyVoiceViewModel, scene: FamilyVoiceScene) -> some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.xLarge) {
                HSAudioRecorderView(
                    isListening: $isRecording,
                    state: audioRecorderState(from: vm.recordingState),
                    onToggle: { isOn in
                        Task {
                            if isOn {
                                await scene.interactor.startRecording(
                                    .init(word: vm.selectedWord, parentId: parentId)
                                )
                            } else {
                                await scene.interactor.stopRecording(
                                    .init(word: vm.selectedWord, parentId: parentId)
                                )
                            }
                        }
                    }
                )
                .accessibilityLabel(String(localized: "parent_child.a11y.recorder_button"))

                HSAudioWaveform(amplitudes: vm.waveformLevels)
                    .frame(height: 40)
                    .accessibilityHidden(true)

                HStack(spacing: SpacingTokens.sp3) {
                    let hasRecordingForWord = vm.recordings.contains { $0.word == vm.selectedWord }

                    Button {
                        if let rec = vm.recordings.first(where: { $0.word == vm.selectedWord }) {
                            Task { await scene.interactor.playRecording(.init(recordingId: rec.id)) }
                        }
                    } label: {
                        Label(
                            String(localized: "parent_child.recorder.cta.play"),
                            systemImage: "play.circle"
                        )
                        .font(TypographyTokens.body(15).weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .disabled(!hasRecordingForWord || vm.recordingState == .recording)

                    Button(role: .destructive) {
                        if let rec = vm.recordings.first(where: { $0.word == vm.selectedWord }) {
                            pendingDeleteId = rec.id
                            showDeleteConfirm = true
                        }
                    } label: {
                        Label(
                            String(localized: "parent_child.recorder.cta.delete"),
                            systemImage: "trash"
                        )
                        .font(TypographyTokens.body(15).weight(.medium))
                    }
                    .buttonStyle(.bordered)
                    .tint(ColorTokens.Semantic.error)
                    .disabled(!hasRecordingForWord || vm.recordingState == .recording)
                }
            }
            .padding(SpacingTokens.sp4)
        }
        .environment(\.circuitContext, .parent)
        .onChange(of: vm.recordingState) { _, newState in
            // Keep binding in sync when state changes externally (e.g., AVAudioSession interruption)
            if newState == .idle { isRecording = false }
            if newState == .recording { isRecording = true }
        }
    }

    // MARK: - [4] Recordings List

    private func recordingsListSection(vm: FamilyVoiceViewModel, scene: FamilyVoiceScene) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack {
                Text(String(format: String(localized: "parent_child.recordings.count"), vm.recordings.count))
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Spacer()
                if vm.recordings.count >= FamilyVoiceModels.maxRecordings {
                    Text(String(localized: "parent_child.recordings.max_warning"))
                        .font(TypographyTokens.caption())
                        .foregroundStyle(ColorTokens.Semantic.warning)
                }
            }

            if vm.recordings.isEmpty {
                HSEmptyStateView(
                    icon: "mic.slash",
                    title: String(localized: "parent_child.recordings.empty"),
                    message: ""
                )
                .padding(.vertical, SpacingTokens.sp4)
            } else {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(vm.recordings) { rec in
                        RecordingRowView(
                            recording: rec,
                            onPlay: {
                                Task { await scene.interactor.playRecording(.init(recordingId: rec.id)) }
                            },
                            onDelete: {
                                pendingDeleteId = rec.id
                                showDeleteConfirm = true
                            }
                        )
                        Divider()
                    }
                }
                .background(ColorTokens.Parent.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.card))
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.card)
                        .strokeBorder(ColorTokens.Parent.inkSoft.opacity(0.15), lineWidth: 1)
                )
            }
        }
    }

    // MARK: - [5] Done CTA

    private func doneCTA(vm: FamilyVoiceViewModel) -> some View {
        Button {
            showSplitView = true
        } label: {
            Text(String(localized: "parent_child.recorder.cta.done"))
                .font(TypographyTokens.headline())
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .tint(ColorTokens.Brand.primary)
        .disabled(!vm.canDone)
        .cornerRadius(RadiusTokens.button)
    }

    // MARK: - Helpers

    private func audioRecorderState(from state: RecordingState) -> HSAudioRecorderState {
        switch state {
        case .idle:        return .idle
        case .recording:   return .listening
        case .playingBack: return .processing
        case .error:       return .idle
        }
    }
}

// MARK: - RecordingRowView

private struct RecordingRowView: View {
    let recording: RecordingItemViewModel
    let onPlay: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: SpacingTokens.xLarge) {
            Button(action: onPlay) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "parent_child.recorder.cta.play") + " " + recording.word)

            VStack(alignment: .leading, spacing: 2) {
                Text(recording.word)
                    .font(TypographyTokens.headline())
                    .foregroundStyle(ColorTokens.Parent.ink)
                Text(recording.durationText)
                    .font(TypographyTokens.caption())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.body)
                    .foregroundStyle(ColorTokens.Semantic.error)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "parent_child.recorder.cta.delete") + " " + recording.word)
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .frame(minHeight: 52)
    }
}

// MARK: - Preview

#Preview("FamilyVoiceView") {
    FamilyVoiceView(parentId: "preview-parent")
        .environment(AppContainer.preview())
        .environment(AppCoordinator())
}

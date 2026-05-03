import SwiftUI

// MARK: - FamilyVoiceSplitView

struct FamilyVoiceSplitView: View {

    let recordings: [RecordingItemViewModel]
    var parentId: String = "local-parent"
    let realmActor: RealmActor

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var scene: FamilyVoiceScene?
    @State private var childIsRecording: Bool = false

    // Current word index
    @State private var currentWordIndex: Int = 0

    private var currentWord: String {
        FamilyVoiceModels.targetWordsRaw[safe: currentWordIndex] ?? FamilyVoiceModels.targetWordsRaw[0]
    }

    var body: some View {
        GeometryReader { proxy in
            let isSmallDevice = proxy.size.height < 700
            let childRatio: CGFloat = isSmallDevice ? 0.65 : 0.60

            VStack(spacing: 0) {
                childArea(proxy: proxy, ratio: childRatio)
                    .background(ColorTokens.Kid.bg)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "parent_child.a11y.split_child_area"))
                    .accessibilitySortPriority(2)

                Divider()
                    .overlay(ColorTokens.Kid.line)

                parentArea(proxy: proxy, ratio: 1 - childRatio)
                    .background(ColorTokens.Parent.bg)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(String(localized: "parent_child.a11y.split_parent_area"))
                    .accessibilitySortPriority(1)
            }
        }
        .navigationTitle(String(localized: "parent_child.split.title"))
        .navigationBarTitleDisplayMode(.inline)
        .ignoresSafeArea(edges: .bottom)
        .task {
            if scene == nil {
                scene = FamilyVoiceScene(realmActor: realmActor)
            }
            await scene?.interactor.fetchRecordings(.init(parentId: parentId))
        }
    }

    // MARK: - Child Area (top 60%)

    @ViewBuilder
    private func childArea(proxy: GeometryProxy, ratio: CGFloat) -> some View {
        let vm = scene?.display.viewModel

        ZStack(alignment: .center) {
            ColorTokens.Kid.bg.ignoresSafeArea(edges: .top)

            VStack(spacing: SpacingTokens.xLarge) {
                // [A] Illustration card
                illustrationCard

                // [B] Play parent button
                playParentButton(vm: vm)

                // [C] Record child button
                childRecordButton(vm: vm)

                // [D] Score feedback overlay
                if let vm, vm.showFeedback {
                    feedbackOverlay(vm: vm)
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.8).combined(with: .opacity)
                        )
                        .animation(MotionTokens.bounce, value: vm.showFeedback)
                }
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.sectionGap)
        }
        .frame(height: proxy.size.height * ratio)
    }

    // MARK: - [A] Illustration Card

    private var illustrationCard: some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Group {
                    if let image = UIImage(named: "illustration_\(currentWord)") {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "photo")
                            .resizable()
                            .scaledToFit()
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                }
                .frame(maxWidth: 160, maxHeight: 160)
                .accessibilityLabel(String(localized: "parent_child.a11y.illustration_prefix") + currentWord)

                Text(currentWord)
                    .font(TypographyTokens.kidDisplay(40))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }
            .padding(SpacingTokens.sp3)
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - [B] Play Parent Button

    private func playParentButton(vm: FamilyVoiceViewModel?) -> some View {
        Button {
            if let vm, let rec = vm.recordings.first(where: { $0.word == currentWord }) {
                Task { await scene?.interactor.playRecording(.init(recordingId: rec.id)) }
            }
        } label: {
            Label(
                String(localized: "parent_child.split.cta.play_parent"),
                systemImage: "play.circle.fill"
            )
            .font(TypographyTokens.headline())
            .frame(minWidth: 200, minHeight: 64)
        }
        .buttonStyle(.bordered)
        .tint(ColorTokens.Brand.primary)
        .disabled(vm?.recordings.first(where: { $0.word == currentWord }) == nil)
        .accessibilityHint(String(localized: "parent_child.a11y.play_parent_hint"))
    }

    // MARK: - [C] Child Record Button

    private func childRecordButton(vm: FamilyVoiceViewModel?) -> some View {
        let state: HSAudioRecorderState = {
            guard let vm else { return .idle }
            switch vm.recordingState {
            case .idle:        return .idle
            case .recording:   return .listening
            case .playingBack: return .processing
            case .error:       return .idle
            }
        }()

        return HSAudioRecorderView(
            isListening: $childIsRecording,
            state: state,
            onToggle: { isOn in
                Task {
                    if isOn {
                        let refId = vm?.recordings.first(where: { $0.word == currentWord })?.id ?? ""
                        await scene?.interactor.startChildRecording(
                            .init(word: currentWord, referenceRecordingId: refId)
                        )
                    } else {
                        let refId = vm?.recordings.first(where: { $0.word == currentWord })?.id ?? ""
                        await scene?.interactor.stopChildRecording(
                            .init(word: currentWord, referenceRecordingId: refId)
                        )
                    }
                }
            }
        )
        .frame(minWidth: 80, minHeight: 80)
        .accessibilityLabel(String(localized: "parent_child.a11y.recorder_button"))
    }

    // MARK: - [D] Score Feedback Overlay

    private func feedbackOverlay(vm: FamilyVoiceViewModel) -> some View {
        VStack(spacing: SpacingTokens.sp2) {
            if vm.feedbackIsCorrect {
                HSSticker(type: .goldStar, size: 80)
            }
            Text(vm.feedback ?? "")
                .font(TypographyTokens.headline(20))
                .foregroundStyle(
                    vm.feedbackIsCorrect ? ColorTokens.Semantic.success : ColorTokens.Semantic.warning
                )
                .multilineTextAlignment(.center)
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.card)
                .fill(Color.white.opacity(0.92))
                .shadow(radius: 8)
        )
        .accessibilityAnnouncement(vm.feedback ?? "")
    }

    // MARK: - Parent Area (bottom 40%)

    @ViewBuilder
    private func parentArea(proxy: GeometryProxy, ratio: CGFloat) -> some View {
        let vm = scene?.display.viewModel

        VStack(spacing: SpacingTokens.xLarge) {
            // [E] Transcript or waveform
            transcriptRow(vm: vm)

            // [F] Score row
            scoreRow(vm: vm)

            // [G] Control buttons
            controlButtons(vm: vm)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.sp4)
        .frame(height: proxy.size.height * ratio)
    }

    // MARK: - [E] Transcript Row

    private func transcriptRow(vm: FamilyVoiceViewModel?) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Image(systemName: "text.bubble")
                .font(TypographyTokens.body(16))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .accessibilityHidden(true)

            if let transcript = vm?.liveTranscript, !transcript.isEmpty {
                Text(transcript)
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .lineLimit(2)
                    .animation(.easeInOut(duration: 0.15), value: transcript)
            } else if let vm, !vm.waveformLevels.isEmpty, vm.recordingState == .recording {
                HSAudioWaveform(amplitudes: vm.waveformLevels)
                    .frame(height: 28)
            } else {
                Text("...")
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
        }
    }

    // MARK: - [F] Score Row

    private func scoreRow(vm: FamilyVoiceViewModel?) -> some View {
        HStack {
            if let score = vm?.currentScore {
                Text(String(format: String(localized: "parent_child.split.score.format"), Int(score * 100)))
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(ColorTokens.Parent.ink)

                HSProgressBar(
                    value: Double(score),
                    style: .parent,
                    tint: score >= 0.75 ? ColorTokens.Brand.mint : ColorTokens.Brand.rose
                )
                .frame(maxWidth: 120, maxHeight: 8)
            } else {
                Text(String(format: String(localized: "parent_child.split.score.format"), 0))
                    .font(TypographyTokens.mono(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
            }
        }
    }

    // MARK: - [G] Control Buttons

    private func controlButtons(vm: FamilyVoiceViewModel?) -> some View {
        HStack(spacing: SpacingTokens.sp3) {
            Button {
                scene?.interactor.resetSession(.init())
                currentWordIndex = 0
            } label: {
                Text(String(localized: "parent_child.split.cta.reset"))
                    .font(TypographyTokens.body(15))
                    .frame(minWidth: 80, minHeight: 44)
            }
            .buttonStyle(.bordered)

            Button {
                scene?.interactor.skipWord(.init(currentWord: currentWord))
                advanceWord()
            } label: {
                Text(String(localized: "parent_child.split.cta.skip"))
                    .font(TypographyTokens.body(15))
                    .frame(minWidth: 80, minHeight: 44)
            }
            .buttonStyle(.bordered)

            Button {
                scene?.interactor.nextWord(.init(currentWord: currentWord))
                advanceWord()
            } label: {
                Text(String(localized: "parent_child.split.cta.next_word"))
                    .font(TypographyTokens.body(15).weight(.semibold))
                    .frame(minWidth: 100, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(ColorTokens.Brand.primary)
            .disabled(vm?.currentScore == nil)
        }
    }

    // MARK: - Helpers

    private func advanceWord() {
        withAnimation(reduceMotion ? .none : MotionTokens.spring) {
            currentWordIndex = (currentWordIndex + 1) % FamilyVoiceModels.targetWordsRaw.count
        }
    }
}

// MARK: - Array safe subscript

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Accessibility announcement modifier

private extension View {
    func accessibilityAnnouncement(_ message: String) -> some View {
        self.accessibilityLabel(message)
    }
}

// MARK: - Preview

#Preview("FamilyVoiceSplitView") {
    NavigationStack {
        FamilyVoiceSplitView(
            recordings: [],
            parentId: "preview-parent",
            realmActor: RealmActor()
        )
        .environment(AppCoordinator())
    }
}

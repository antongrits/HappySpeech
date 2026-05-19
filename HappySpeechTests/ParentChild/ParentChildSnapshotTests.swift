@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - ParentChildSnapshotTests
//
// 8 snapshot PNG для FamilyVoice экранов (F4).
// 4 сценария × 2 темы = 8 PNG.
// Хранятся в __Snapshots__/ParentChild/<экран>/<device>_<appearance>.png
//
// Паттерн идентичен FamilyCalendarSnapshotTests / GrammarGameSnapshotTests:
// UIHostingController + UIGraphicsImageRenderer, threshold 55%.
// Frozen ViewModel — без Realm/Firebase/AVAudio.

@MainActor
final class ParentChildSnapshotTests: XCTestCase {

    // MARK: - Device sizes

    private let deviceSize   = CGSize(width: 402, height: 874)   // iPhone 17 Pro
    private let deviceSizeSE = CGSize(width: 375, height: 667)   // iPhone SE 3
    private let deviceName   = "iPhone17Pro"
    private let deviceNameSE = "iPhoneSE3"

    // MARK: - 1. Recorder empty state, iPhone 17 Pro, Light

    func test_familyVoice_recorder_emptyState_iPhone17Pro_Light() throws {
        try record(
            view: makeView(scenario: .recorderEmpty),
            screen: "recorder_emptyState",
            device: deviceName, size: deviceSize,
            appearance: ("Light", .light)
        )
    }

    // MARK: - 2. Recorder empty state, iPhone 17 Pro, Dark

    func test_familyVoice_recorder_emptyState_iPhone17Pro_Dark() throws {
        try record(
            view: makeView(scenario: .recorderEmpty),
            screen: "recorder_emptyState",
            device: deviceName, size: deviceSize,
            appearance: ("Dark", .dark)
        )
    }

    // MARK: - 3. Recorder with 3 recordings, iPhone 17 Pro, Light

    func test_familyVoice_recorder_with3recordings_iPhone17Pro_Light() throws {
        try record(
            view: makeView(scenario: .recorderWith3Recordings),
            screen: "recorder_3recordings",
            device: deviceName, size: deviceSize,
            appearance: ("Light", .light)
        )
    }

    // MARK: - 4. Recorder with 3 recordings, iPhone 17 Pro, Dark

    func test_familyVoice_recorder_with3recordings_iPhone17Pro_Dark() throws {
        try record(
            view: makeView(scenario: .recorderWith3Recordings),
            screen: "recorder_3recordings",
            device: deviceName, size: deviceSize,
            appearance: ("Dark", .dark)
        )
    }

    // MARK: - 5. Split idle, iPhone 17 Pro, Light

    func test_familyVoice_split_idle_iPhone17Pro_Light() throws {
        try record(
            view: makeSplitView(scenario: .splitIdle),
            screen: "split_idle",
            device: deviceName, size: deviceSize,
            appearance: ("Light", .light)
        )
    }

    // MARK: - 6. Split idle, iPhone 17 Pro, Dark

    func test_familyVoice_split_idle_iPhone17Pro_Dark() throws {
        try record(
            view: makeSplitView(scenario: .splitIdle),
            screen: "split_idle",
            device: deviceName, size: deviceSize,
            appearance: ("Dark", .dark)
        )
    }

    // MARK: - 7. Split with score, iPhone SE 3, Light

    func test_familyVoice_split_scoring_iPhoneSE_Light() throws {
        try record(
            view: makeSplitView(scenario: .splitWithScore),
            screen: "split_scoring",
            device: deviceNameSE, size: deviceSizeSE,
            appearance: ("Light", .light)
        )
    }

    // MARK: - 8. Split with score, iPhone SE 3, Dark

    func test_familyVoice_split_scoring_iPhoneSE_Dark() throws {
        try record(
            view: makeSplitView(scenario: .splitWithScore),
            screen: "split_scoring",
            device: deviceNameSE, size: deviceSizeSE,
            appearance: ("Dark", .dark)
        )
    }

    // MARK: - View Factory

    private enum RecorderScenario {
        case recorderEmpty
        case recorderWith3Recordings
    }

    private enum SplitScenario {
        case splitIdle
        case splitWithScore
    }

    private func makeView(scenario: RecorderScenario) -> some View {
        FamilyVoiceSnapshotWrapper(viewModel: recorderViewModel(for: scenario))
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
            .environment(\.circuitContext, .parent)
    }

    private func makeSplitView(scenario: SplitScenario) -> some View {
        FamilyVoiceSplitSnapshotWrapper(viewModel: splitViewModel(for: scenario))
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
    }

    // MARK: - ViewModel builders

    private func recorderViewModel(for scenario: RecorderScenario) -> FamilyVoiceViewModel {
        switch scenario {
        case .recorderEmpty:
            return FamilyVoiceViewModel(
                mode: .recorder,
                recordingState: .idle,
                selectedWord: "мяч",
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

        case .recorderWith3Recordings:
            return FamilyVoiceViewModel(
                mode: .recorder,
                recordingState: .idle,
                selectedWord: "рыба",
                recordings: [
                    RecordingItemViewModel(
                        id: "r-1", word: "мяч",
                        durationText: "0:03", recordedAt: Date(),
                        audioFilePath: "family_recordings/r-1.m4a"
                    ),
                    RecordingItemViewModel(
                        id: "r-2", word: "собака",
                        durationText: "0:05", recordedAt: Date(),
                        audioFilePath: "family_recordings/r-2.m4a"
                    ),
                    RecordingItemViewModel(
                        id: "r-3", word: "рыба",
                        durationText: "0:04", recordedAt: Date(),
                        audioFilePath: "family_recordings/r-3.m4a"
                    )
                ],
                currentScore: nil,
                feedback: nil,
                canDone: true,
                waveformLevels: [0.2, 0.4, 0.6, 0.8, 0.5, 0.3],
                liveTranscript: nil,
                showFeedback: false,
                feedbackIsCorrect: false,
                toastMessage: nil
            )
        }
    }

    private func splitViewModel(for scenario: SplitScenario) -> FamilyVoiceViewModel {
        switch scenario {
        case .splitIdle:
            return FamilyVoiceViewModel(
                mode: .split,
                recordingState: .idle,
                selectedWord: "мяч",
                recordings: [
                    RecordingItemViewModel(
                        id: "r-1", word: "мяч",
                        durationText: "0:03", recordedAt: Date(),
                        audioFilePath: "family_recordings/r-1.m4a"
                    )
                ],
                currentScore: nil,
                feedback: nil,
                canDone: true,
                waveformLevels: [],
                liveTranscript: nil,
                showFeedback: false,
                feedbackIsCorrect: false,
                toastMessage: nil
            )

        case .splitWithScore:
            return FamilyVoiceViewModel(
                mode: .split,
                recordingState: .idle,
                selectedWord: "шар",
                recordings: [
                    RecordingItemViewModel(
                        id: "r-1", word: "шар",
                        durationText: "0:04", recordedAt: Date(),
                        audioFilePath: "family_recordings/r-1.m4a"
                    )
                ],
                currentScore: 0.85,
                feedback: "Отлично! Попробуй ещё раз.",
                canDone: true,
                waveformLevels: [],
                liveTranscript: "шар",
                showFeedback: true,
                feedbackIsCorrect: true,
                toastMessage: nil
            )
        }
    }

    // MARK: - Rendering engine (идентичен FamilyCalendarSnapshotTests)

    private func render<V: View>(
        _ view: V,
        size: CGSize,
        style: UIUserInterfaceStyle
    ) -> UIImage {
        SnapshotTestHelper.renderView(view, size: size, style: style)
    }

    private func record<V: View>(
        view: V,
        screen: String,
        device: String,
        size: CGSize,
        appearance: (String, UIUserInterfaceStyle)
    ) throws {
        let (appearanceName, style) = appearance
        let image = render(view, size: size, style: style)
        let url = SnapshotTestHelper.snapshotURL(
            testClass: Self.self,
            category: "ParentChild",
            screen: screen,
            device: device,
            appearance: appearanceName
        )
        let label = "\(screen)·\(device)·\(appearanceName)"
        try SnapshotTestHelper.assertPixelMatch(image, referenceURL: url, label: label)
    }
}

// MARK: - FamilyVoiceSnapshotWrapper

/// Frozen-обёртка для Recorder snapshot: рендерит UI из FamilyVoiceViewModel без bootstrap.
private struct FamilyVoiceSnapshotWrapper: View {
    let viewModel: FamilyVoiceViewModel

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: SpacingTokens.sectionGap) {
                    headerCard
                        .padding(.top, SpacingTokens.sp6)
                    wordPickerSection
                    recordingListSection
                    doneCTA
                        .padding(.bottom, SpacingTokens.sp8)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
            .background(ColorTokens.Parent.bg.ignoresSafeArea())
            .navigationTitle("Голосовые образцы")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environment(\.circuitContext, .parent)
    }

    private var headerCard: some View {
        HSCard(style: .elevated) {
            VStack(spacing: SpacingTokens.sp3) {
                Image(systemName: "waveform.circle")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .accessibilityHidden(true)
                Text("Голосовые образцы")
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Parent.ink)
                    .multilineTextAlignment(.center)
                Text("Запишите слова, чтобы ребёнок мог повторить за вами")
                    .font(TypographyTokens.body())
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(SpacingTokens.sp4)
        }
        .environment(\.circuitContext, .parent)
    }

    private var wordPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.regular) {
                ForEach(FamilyVoiceModels.targetWordsRaw, id: \.self) { word in
                    let isSelected = viewModel.selectedWord == word
                    Text(word)
                        .font(TypographyTokens.body(15).weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white : ColorTokens.Parent.ink)
                        .padding(.horizontal, SpacingTokens.sp3)
                        .padding(.vertical, SpacingTokens.sp2)
                        .background(Capsule().fill(isSelected ? ColorTokens.Brand.primary : ColorTokens.Parent.surface))
                }
            }
            .padding(.vertical, SpacingTokens.sp1)
        }
    }

    private var recordingListSection: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            Text("\(viewModel.recordings.count) записей")
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Parent.inkMuted)

            if viewModel.recordings.isEmpty {
                HSEmptyStateView(
                    icon: "mic.slash",
                    title: "Нет записей",
                    message: ""
                )
                .padding(.vertical, SpacingTokens.sp4)
            } else {
                VStack(spacing: SpacingTokens.sp2) {
                    ForEach(viewModel.recordings) { rec in
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(ColorTokens.Brand.primary)
                                .frame(minWidth: 44, minHeight: 44)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(rec.word)
                                    .font(TypographyTokens.headline())
                                    .foregroundStyle(ColorTokens.Parent.ink)
                                Text(rec.durationText)
                                    .font(TypographyTokens.caption())
                                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                            }
                            Spacer()
                            Image(systemName: "trash")
                                .font(.body)
                                .foregroundStyle(ColorTokens.Semantic.error)
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .padding(.horizontal, SpacingTokens.sp4)
                        .frame(minHeight: 52)
                        Divider()
                    }
                }
                .background(ColorTokens.Parent.surface,
                            in: RoundedRectangle(cornerRadius: RadiusTokens.card))
            }
        }
    }

    private var doneCTA: some View {
        Text("Готово — начать занятие")
            .font(TypographyTokens.headline())
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(viewModel.canDone ? ColorTokens.Brand.primary : ColorTokens.Parent.inkSoft)
            .foregroundStyle(Color.white)
            .cornerRadius(RadiusTokens.button)
            .opacity(viewModel.canDone ? 1.0 : 0.4)
    }
}

// MARK: - FamilyVoiceSplitSnapshotWrapper

/// Frozen-обёртка для Split snapshot: рендерит разделённый экран из ViewModel без bootstrap.
private struct FamilyVoiceSplitSnapshotWrapper: View {
    let viewModel: FamilyVoiceViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Детская зона (60%)
                childArea
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 380)
                    .background(ColorTokens.Kid.bg)

                Divider()
                    .overlay(ColorTokens.Kid.line)

                // Родительская зона (40%)
                parentArea
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 240)
                    .background(ColorTokens.Parent.bg)
            }
            .navigationTitle("Занятие вместе")
            .navigationBarTitleDisplayMode(.inline)
            .ignoresSafeArea(edges: .bottom)
        }
    }

    private var childArea: some View {
        VStack(spacing: SpacingTokens.xLarge) {
            // Слово
            Text(viewModel.selectedWord)
                .font(TypographyTokens.title(48))
                .foregroundStyle(ColorTokens.Kid.ink)
                .padding(.top, SpacingTokens.sp6)
                .accessibilityLabel("Слово: \(viewModel.selectedWord)")

            // Кнопка записи ребёнка
            ZStack {
                Circle()
                    .fill(ColorTokens.Brand.primary)
                    .frame(width: 88, height: 88)
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }
            .accessibilityLabel("Записать голос ребёнка")

            // Feedback overlay (если есть)
            if viewModel.showFeedback, let feedback = viewModel.feedback {
                HStack(spacing: SpacingTokens.small) {
                    Image(systemName: viewModel.feedbackIsCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(viewModel.feedbackIsCorrect
                                         ? ColorTokens.Semantic.success
                                         : ColorTokens.Semantic.error)
                    Text(feedback)
                        .font(TypographyTokens.headline())
                        .foregroundStyle(ColorTokens.Kid.ink)
                }
                .padding(SpacingTokens.regular)
                .background(ColorTokens.Kid.surface,
                            in: RoundedRectangle(cornerRadius: RadiusTokens.card))
            }

            // Score (если есть)
            if let score = viewModel.currentScore {
                Text("\(Int(score * 100))%")
                    .font(TypographyTokens.title(32))
                    .foregroundStyle(score >= 0.75
                                     ? ColorTokens.Semantic.success
                                     : ColorTokens.Semantic.warning)
                    .accessibilityLabel("Результат: \(Int(score * 100)) процентов")
            }

            Spacer()
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
    }

    private var parentArea: some View {
        VStack(spacing: SpacingTokens.regular) {
            Text("Ваш образец")
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Parent.inkMuted)

            // Кнопка воспроизведения образца
            Button {} label: {
                Label("Воспроизвести", systemImage: "play.circle")
                    .font(TypographyTokens.body(15).weight(.medium))
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.recordings.isEmpty)

            Spacer()
        }
        .padding(SpacingTokens.sp4)
    }
}

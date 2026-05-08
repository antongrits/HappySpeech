import SwiftUI

// MARK: - FluencyDiaryView (kid interface)
//
// Child records speech for ~2 min. No dysfluency numbers shown to kid —
// only a neutral "Молодец!" completion. Numbers are parent-only.

struct FluencyDiaryView: View {

    @Environment(AppContainer.self) private var container
    @State private var interactor: FluencyDiaryInteractor?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()

            if let interactor {
                content(interactor: interactor)
            } else {
                ProgressView()
            }
        }
        .navigationTitle(String(localized: "stuttering.exercise.diary.title"))
        .navigationBarTitleDisplayMode(.inline)
        .environment(\.circuitContext, .kid)
        .task {
            interactor = FluencyDiaryInteractor(
                storageWorker: DiaryStorageWorker(realmActor: container.realmActor)
            )
            interactor?.startSession()
        }
        .onDisappear {
            interactor?.stopRecording()
        }
    }

    @ViewBuilder
    private func content(interactor: FluencyDiaryInteractor) -> some View {
        if interactor.display.showComplete {
            completionView
        } else {
            recordingView(interactor: interactor)
        }
    }

    private var completionView: some View {
        VStack(spacing: SpacingTokens.sp6) {
            LyalyaMascotView(state: .celebrating, size: 120)
                .accessibilityHidden(true)

            Text(String(localized: "stuttering.feedback.complete"))
                .font(TypographyTokens.title(24))
                .foregroundStyle(ColorTokens.Kid.ink)

            HSButton(
                String(localized: "general.done"),
                style: .primary,
                action: { dismiss() }
            )
            .frame(height: 56)
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .transition(.opacity.combined(with: .scale))
    }

    private func recordingView(interactor: FluencyDiaryInteractor) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: SpacingTokens.sp5) {
                mascotSection(interactor: interactor)
                instructionSection
                analysisBanner(interactor: interactor)
                textBlock(interactor: interactor)
                waveformCard(interactor: interactor)
                recordButton(interactor: interactor)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
            .padding(.vertical, SpacingTokens.sp5)
        }
    }

    @ViewBuilder
    private func analysisBanner(interactor: FluencyDiaryInteractor) -> some View {
        let icon = interactor.display.isStubAnalysis ? "info.circle" : "checkmark.circle"
        let key: LocalizedStringResource = interactor.display.isStubAnalysis
            ? "stuttering.diary.stub_banner"
            : "stuttering.diary.whisperkit_active"
        HSLiquidGlassCard(
            style: .tinted(
                interactor.display.isStubAnalysis
                    ? ColorTokens.Semantic.warningBg
                    : ColorTokens.Brand.mint.opacity(0.18)
            ),
            padding: SpacingTokens.sp3
        ) {
            Label(String(localized: key), systemImage: icon)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func mascotSection(interactor: FluencyDiaryInteractor) -> some View {
        LyalyaMascotView(
            state: interactor.display.isRecording ? .happy : .idle,
            size: 100
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .accessibilityHidden(true)
    }

    private var instructionSection: some View {
        Text(String(localized: "stuttering.diary.instruction"))
            .font(TypographyTokens.title(24))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
    }

    private func textBlock(interactor: FluencyDiaryInteractor) -> some View {
        HSLiquidGlassCard(style: .elevated, padding: SpacingTokens.sp4) {
            Text(interactor.display.currentText)
                .font(TypographyTokens.body(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineSpacing(TypographyTokens.LineSpacing.relaxed * 1.5)
                .lineLimit(nil)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func waveformCard(interactor: FluencyDiaryInteractor) -> some View {
        HSLiquidGlassCard(
            style: .tinted(ColorTokens.Brand.primary.opacity(0.12)),
            padding: SpacingTokens.sp4
        ) {
            VStack(spacing: SpacingTokens.sp2) {
                HSAudioWaveform(
                    amplitudes: interactor.display.isRecording
                        ? interactor.display.waveformLevels
                        : [],
                    style: .recording,
                    tint: ColorTokens.Brand.primary
                )
                .frame(height: 56)
                .opacity(interactor.display.isRecording ? 1 : 0.3)
                .animation(reduceMotion ? nil : MotionTokens.outQuick, value: interactor.display.isRecording)

                if interactor.display.isRecording {
                    Text(String(localized: "stuttering.diary.recording_hint"))
                        .font(TypographyTokens.caption(12))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .accessibilityHidden(true)
    }

    private func recordButton(interactor: FluencyDiaryInteractor) -> some View {
        HSButton(
            interactor.display.isRecording
                ? String(localized: "stuttering.diary.cta.stop")
                : String(localized: "stuttering.diary.cta.start"),
            style: interactor.display.isRecording ? .danger : .primary,
            icon: interactor.display.isRecording ? "stop.fill" : "mic.fill",
            isLoading: interactor.display.isAnalyzing,
            action: {
                if interactor.display.isRecording {
                    interactor.stopRecording()
                } else {
                    Task { await interactor.startRecording() }
                }
            }
        )
        .frame(height: 64)
        .accessibilityLabel(
            interactor.display.isRecording
                ? String(localized: "Остановить запись, кнопка")
                : String(localized: "Начать запись")
        )
        .accessibilityHint(
            interactor.display.isRecording
                ? ""
                : String(localized: "Прочти текст вслух, я буду слушать")
        )
    }
}

// MARK: - Preview

#Preview("FluencyDiaryView") {
    NavigationStack {
        FluencyDiaryView()
    }
    .environment(\.circuitContext, .kid)
}

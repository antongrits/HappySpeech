import SwiftUI

// MARK: - FluencyDiaryView (kid interface)
//
// Child records speech for ~2 min. No dysfluency numbers shown to kid —
// only a neutral "Молодец!" completion. Numbers are parent-only.

struct FluencyDiaryView: View {

    @Environment(AppContainer.self) private var container
    @State private var interactor: FluencyDiaryInteractor?
    @Environment(\.dismiss) private var dismiss

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
            HSMascotView(mood: .celebrating)
                .frame(width: 120, height: 120)

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
        VStack(spacing: SpacingTokens.sp5) {
            mascotSection(interactor: interactor)
            instructionSection
            analysisBanner(interactor: interactor)
            textBlock(interactor: interactor)
            waveformSection(interactor: interactor)
            recordButton(interactor: interactor)
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.sp5)
    }

    @ViewBuilder
    private func analysisBanner(interactor: FluencyDiaryInteractor) -> some View {
        if interactor.display.isStubAnalysis {
            Label(
                String(localized: "stuttering.diary.stub_banner"),
                systemImage: "info.circle"
            )
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.leading)
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(ColorTokens.Kid.surfaceAlt)
            )
            .accessibilityElement(children: .combine)
        } else {
            Label(
                String(localized: "stuttering.diary.whisperkit_active"),
                systemImage: "checkmark.circle"
            )
            .font(TypographyTokens.caption(12))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.leading)
            .padding(SpacingTokens.sp3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.sm, style: .continuous)
                    .fill(ColorTokens.Kid.surfaceAlt)
            )
            .accessibilityElement(children: .combine)
        }
    }

    private func mascotSection(interactor: FluencyDiaryInteractor) -> some View {
        HSMascotView(mood: interactor.display.isRecording ? .happy : .idle)
            .frame(width: 100, height: 100)
            .frame(maxWidth: .infinity)
    }

    private var instructionSection: some View {
        Text(String(localized: "stuttering.diary.instruction"))
            .font(TypographyTokens.title(24))
            .foregroundStyle(ColorTokens.Kid.ink)
            .multilineTextAlignment(.center)
    }

    private func textBlock(interactor: FluencyDiaryInteractor) -> some View {
        HSCard(style: .elevated, padding: SpacingTokens.sp4) {
            Text(interactor.display.currentText)
                .font(TypographyTokens.body(18))
                .foregroundStyle(ColorTokens.Kid.ink)
                .lineSpacing(TypographyTokens.LineSpacing.relaxed * 1.5)
                .lineLimit(nil)
        }
    }

    private func waveformSection(interactor: FluencyDiaryInteractor) -> some View {
        HSAudioWaveform(
            amplitudes: interactor.display.isRecording
                ? interactor.display.waveformLevels
                : [],
            style: .recording,
            tint: ColorTokens.Brand.primary
        )
        .frame(height: 56)
        .opacity(interactor.display.isRecording ? 1 : 0.3)
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

import OSLog
import SwiftUI

// MARK: - RepeatAfterModelLiveTranscriptView
//
// v31 Волна D Ф.4 — визуальная подсветка слов, которые ребёнок произносит
// в режиме `repeat-after-model`. Подписывается на `SpeechAnalyzerService`
// и отрисовывает текущий партиал-транскрипт.
//
// Контракт UI:
//   • Активен только когда `isActive == true` (Interactor выставляет на
//     фазе .recording).
//   • Жёстко гейтится `circuitContext == .kid`: показывается только в
//     детском контуре.
//   • Reduced Motion / Dynamic Type / VoiceOver — учтены.
//
// На iOS 26 (когда Speech.SpeechAnalyzer станет полностью доступным) UI
// автоматически получит низко-задержечный поток. Сейчас на WhisperKit-
// фолбэке отображается «слушаю…» (плейсхолдер).

struct RepeatAfterModelLiveTranscriptView: View {

    /// Активен ли стрим — обычно `phase == .recording`.
    let isActive: Bool

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var transcript: String = ""
    @State private var isFinal: Bool = false
    @State private var streamTask: Task<Void, Never>?

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "RepeatAfterModel.LiveTranscript"
    )

    var body: some View {
        Group {
            if isActive {
                content
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isActive)
        .onChange(of: isActive) { _, newValue in
            if newValue {
                startListening()
            } else {
                stopListening()
            }
        }
        .onDisappear { stopListening() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(transcript.isEmpty ? "" : transcript))
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: SpacingTokens.sp2) {
            Image(systemName: "waveform.and.mic")
                .font(.title3)
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)
            Text(displayText)
                .font(TypographyTokens.headline(17).monospacedDigit())
                .foregroundStyle(isFinal ? ColorTokens.Kid.ink : ColorTokens.Kid.inkMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, SpacingTokens.sp4)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            Capsule().fill(ColorTokens.Kid.surface.opacity(0.95))
        )
        .overlay(
            Capsule().strokeBorder(ColorTokens.Kid.line, lineWidth: 1.5)
        )
    }

    private var displayText: String {
        if transcript.isEmpty {
            return String(localized: "speechAnalyzer.listening")
        }
        return transcript
    }

    // MARK: - Stream wiring

    private func startListening() {
        stopListening()
        let service = container.speechAnalyzerService
        streamTask = Task { [service] in
            do {
                let stream = try await service.startLiveTranscript()
                for await event in stream {
                    await MainActor.run {
                        transcript = event.transcript
                        isFinal = event.isFinal
                    }
                }
            } catch {
                Self.logger.warning(
                    "Live transcript failed: \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func stopListening() {
        let service = container.speechAnalyzerService
        streamTask?.cancel()
        streamTask = nil
        Task { [service] in
            await service.stopLiveTranscript()
        }
        transcript = ""
        isFinal = false
    }
}

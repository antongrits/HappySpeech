import SwiftUI
import OSLog

// MARK: - VisualAcousticView
//
// "Визуально-акустическая обратная связь": ребёнок видит эталонную форму
// waveform (статичная) и свою "волну" (анимированная). Реальная запись
// микрофона живёт в AudioService; здесь — демо-режим с псевдо-случайной
// волной, которую ребёнок подтверждает кнопкой "Похоже".

struct VisualAcousticView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @Environment(AppContainer.self) private var container
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var userSimilarity: Float = 0.0
    @State private var isRecording: Bool = false
    @State private var animationPhase: Double = 0.0

    private let logger = Logger(subsystem: "ru.happyspeech", category: "VisualAcoustic")

    var body: some View {
        VStack(spacing: SpacingTokens.large) {
            header
            referenceWave
            userWave
            controlRow
            Spacer()
        }
        .padding(SpacingTokens.screenEdge)
    }

    private var header: some View {
        VStack(spacing: 2) {
            Text(String(localized: "visual.title"))
                .font(TypographyTokens.title(22))
                .foregroundStyle(ColorTokens.Kid.ink)
            Text(String(localized: "visual.subtitle.\(activity.soundTarget)"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
    }

    private var referenceWave: some View {
        waveView(color: ColorTokens.Brand.primary,
                 label: String(localized: "visual.reference"),
                 phase: 0,
                 amplitude: 30)
    }

    private var userWave: some View {
        waveView(color: Color.green,
                 label: String(localized: "visual.you"),
                 phase: animationPhase,
                 amplitude: isRecording ? 40 : 10)
    }

    private func waveView(color: Color, label: String, phase: Double, amplitude: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: SpacingTokens.tiny) {
            Text(label)
                .font(TypographyTokens.caption(12))
                .foregroundStyle(ColorTokens.Kid.inkMuted)
            GeometryReader { geo in
                Path { path in
                    let width = geo.size.width
                    let midY = geo.size.height / 2
                    path.move(to: CGPoint(x: 0, y: midY))
                    for x in stride(from: 0.0, to: Double(width), by: 1.0) {
                        let y = midY + sin((x + phase * 40) / 20) * amplitude
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(color, lineWidth: 2)
            }
            .frame(height: 80)
        }
    }

    private var controlRow: some View {
        HStack(spacing: SpacingTokens.medium) {
            HSButton(
                isRecording ? String(localized: "visual.stop")
                            : String(localized: "visual.record"),
                style: .primary,
                action: toggleRecording
            )
            HSButton(String(localized: "visual.done"), style: .secondary) {
                finish()
            }
        }
    }

    private func toggleRecording() {
        isRecording.toggle()
        container.soundService.playUISound(.tap)
        if isRecording {
            if !reduceMotion {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    animationPhase = 10
                }
            }
        } else {
            // Fake similarity scoring: if they recorded >1 sec, assume fair attempt.
            userSimilarity = Float.random(in: 0.55...0.9)
        }
    }

    private func finish() {
        let s = userSimilarity > 0 ? userSimilarity : 0.5
        logger.info("visual score=\(s, privacy: .public)")
        onComplete(s)
    }
}

#Preview {
    VisualAcousticView(
        activity: SessionActivity(
            id: "preview", gameType: .visualAcoustic, lessonId: "l1",
            soundTarget: "Р", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
    .environment(AppContainer.preview())
}

import SwiftUI

// MARK: - BreathingView
//
// Breathing exercise — child blows at microphone / pretends to blow, and a
// 3D balloon / dandelion grows/shrinks with the air pressure. The current
// implementation is a minimum-playable stub with timer-driven progress
// so SessionShell can drive it end-to-end; real AVAudioEngine RMS hookup
// lives in `AudioAmplitudeService` (wired from AppContainer).

struct BreathingView: View {

    let activity: SessionActivity
    let onComplete: (Float) -> Void

    @State private var elapsed: TimeInterval = 0
    @State private var timer: Timer?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let targetDuration: TimeInterval = 12.0

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Text(String(localized: "Дуй!"))
                .font(TypographyTokens.title())
                .foregroundStyle(ColorTokens.Kid.ink)

            Circle()
                .fill(ColorTokens.Brand.primary.opacity(0.3))
                .frame(width: ballSize, height: ballSize)
                .overlay(Text("🎈").font(.system(size: 60)))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.6), value: elapsed)

            HSProgressBar(value: progress)
                .frame(height: 8)
                .padding(.horizontal, SpacingTokens.screenEdge)

            Text(String(localized: "Звук: \(activity.soundTarget)"))
                .font(TypographyTokens.caption())
                .foregroundStyle(ColorTokens.Kid.inkMuted)
        }
        .padding()
        .onAppear(perform: start)
        .onDisappear(perform: stop)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "Дыхательное упражнение. Дуй в микрофон."))
    }

    private var progress: Double { min(elapsed / targetDuration, 1.0) }
    private var ballSize: CGFloat { 80 + CGFloat(progress) * 140 }

    private func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            Task { @MainActor in
                elapsed += 0.25
                if elapsed >= targetDuration {
                    stop()
                    onComplete(0.9)
                }
            }
        }
    }

    private func stop() {
        timer?.invalidate()
        timer = nil
    }
}

#Preview {
    BreathingView(
        activity: SessionActivity(
            id: "preview", gameType: .breathing, lessonId: "l1",
            soundTarget: "С", difficulty: 1, isCompleted: false, score: nil
        ),
        onComplete: { _ in }
    )
}

import OSLog
import Particles
import SwiftUI

// MARK: - SessionCompleteViewComponents
//
// Подкомпоненты `SessionCompleteView`: stagger-modifier, achievement-popup,
// confetti, share-sheet и Preview'ы. Извлечено из `SessionCompleteView.swift`
// (Block K.3 v16) для удержания LOC ≤700.
// Доступ — internal (для других файлов того же модуля).

// MARK: - StaggeredAppear

struct StaggeredAppear: ViewModifier {
    let visible: Bool
    let index: Int
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 18)
            .animation(
                reduceMotion
                    ? nil
                    : .spring(response: 0.45, dampingFraction: 0.78)
                        .delay(Double(index) * 0.10),
                value: visible
            )
    }
}

// MARK: - AchievementPopupView

struct AchievementPopupView: View {
    let info: UnlockedAchievementInfo
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: SpacingTokens.medium) {
            Image(systemName: info.iconName)
                .font(TypographyTokens.kidDisplay(52))
                .foregroundStyle(ColorTokens.Brand.gold)
                .padding(SpacingTokens.medium)
                .background(ColorTokens.Brand.gold.opacity(0.15), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: SpacingTokens.tiny) {
                Text(String(localized: "sessionComplete.achievement.popup.title"))
                    .font(TypographyTokens.caption(12).weight(.semibold))
                    .foregroundStyle(ColorTokens.Brand.gold)
                    .textCase(.uppercase)
                    .tracking(0.6)

                Text(info.title)
                    .font(TypographyTokens.title(20))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)

                Text(info.description)
                    .font(TypographyTokens.body(14))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .minimumScaleFactor(0.85)
            }

            HSButton(String(localized: "sessionComplete.achievement.popup.cta"), style: .primary) {
                onDismiss()
            }
        }
        .padding(SpacingTokens.xLarge)
        .frame(maxWidth: 320)
        .background(ColorTokens.Kid.surface, in: RoundedRectangle(cornerRadius: RadiusTokens.xl))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ColorTokens.Overlay.dimmerHeavy.ignoresSafeArea())
        .onTapGesture { onDismiss() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(
            "\(String(localized: "sessionComplete.achievement.popup.title")): \(info.title)"
        )
    }
}

// MARK: - ConfettiCanvasView

/// Конфетти через swiftui-particles (benlmyers/swiftui-particles, MIT).
/// Рендерит разноцветный confetti burst при высоком результате сессии.
/// Использует Emitter API из Particles 1.0.0:
///   from: .top → to: .bottom, emitForever(intensity:), particleLifetime, emitSpread.
struct ConfettiCanvasView: View {

    private let confettiColors: [Color] = [
        ColorTokens.Brand.gold,
        ColorTokens.Brand.primary,
        ColorTokens.Brand.lilac,
        ColorTokens.Feedback.correct,
        ColorTokens.Brand.butter
    ]

    var body: some View {
        Emitter(from: .top, to: .bottom) {
            Confetti(confettiColors, size: .large)
        }
        .emitForever(intensity: 40)
        .particleLifetime(3.0)
        .emitSpread(0.8)
        .accessibilityHidden(true)
    }
}

// MARK: - Share Sheet

struct SessionCompleteShareSheet: UIViewControllerRepresentable {
    let text: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [text], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Previews

#Preview("SessionComplete — Perfect") {
    SessionCompleteView(
        result: .sample,
        onContinue: {},
        onReplay: {}
    )
}

#Preview("SessionComplete — Encouraging") {
    SessionCompleteView(
        result: SessionResult(
            score: 0.42,
            starsEarned: 1,
            gameTitle: "Свистящие С",
            soundTarget: "С",
            attempts: 8,
            correctAttempts: 4,
            hintsUsed: 3,
            durationSec: 360,
            nextLessonTitle: nil
        ),
        onContinue: {},
        onReplay: {}
    )
}

#Preview("SessionComplete — 2 Stars") {
    SessionCompleteView(
        result: SessionResult(
            score: 0.71,
            starsEarned: 2,
            gameTitle: "Шипящие Ш",
            soundTarget: "Ш",
            attempts: 10,
            correctAttempts: 7,
            hintsUsed: 1,
            durationSec: 480,
            nextLessonTitle: "Повторение звука Ш — слоги"
        ),
        onContinue: {},
        onReplay: {}
    )
}

import GroupActivities
import SwiftUI

// MARK: - SharePlaySessionView
//
// View активной SharePlay-сессии.
// Отображается поверх LessonPlayerView как overlay.
//
// Показывает:
//   - Количество и аватары участников
//   - Счёт удалённого участника (из SyncMessage.roundComplete)
//   - Анимацию Ляли при lyalyaCelebration
//   - Кнопку завершения сессии
//
// Примечание: голосовой анализ (PronunciationScorer) работает локально
// на каждом устройстве — только результаты синхронизируются.

struct SharePlaySessionView: View {

    // MARK: - Input

    let controller: FamilyShareplayController
    let lesson: SharePlayLessonItem
    let onMessage: (SyncMessage) -> Void
    let onEnd: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - State

    @State private var remoteChildLabel: String?
    @State private var showCelebration = false
    @State private var remoteScoreText: String?

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Шапка с участниками
            participantsBar

            // Удалённый результат — появляется при roundComplete
            if let scoreText = remoteScoreText {
                remoteScoreOverlay(scoreText)
            }

            // Анимация праздника — при lyalyaCelebration
            if showCelebration && !reduceMotion {
                celebrationOverlay
            }
        }
        .task {
            // Принимаем входящие сообщения и передаём родителю
            for await message in controller.incomingMessages() {
                handleMessage(message)
                onMessage(message)
            }
        }
    }

    // MARK: - Subviews

    private var participantsBar: some View {
        HStack(spacing: SpacingTokens.sp3) {
            // Иконка SharePlay
            Image(systemName: "shareplay")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)

            // Метка участников
            if let label = remoteChildLabel {
                Text(label)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .transition(.opacity)
            } else {
                Text(
                    String(
                        format: String(localized: "shareplay.participants.many"),
                        controller.participants.count
                    )
                )
                .font(TypographyTokens.caption(13))
                .foregroundStyle(ColorTokens.Parent.inkMuted)
                .lineLimit(1)
            }

            Spacer()

            // Кнопка завершения
            Button(action: onEnd) {
                HStack(spacing: 4) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                    Text(String(localized: "shareplay.session.end"))
                        .font(TypographyTokens.caption(12))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, SpacingTokens.sp3)
                .padding(.vertical, SpacingTokens.sp1)
                .background(ColorTokens.Brand.primary, in: Capsule())
            }
            .accessibilityLabel(String(localized: "shareplay.session.end"))
        }
        .padding(.horizontal, SpacingTokens.screenEdge)
        .padding(.vertical, SpacingTokens.sp2)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.top, SpacingTokens.sp2)
        .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    @ViewBuilder
    private func remoteScoreOverlay(_ text: String) -> some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Text(text)
                    .font(TypographyTokens.headline(16))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.horizontal, SpacingTokens.sp4)
                    .padding(.vertical, SpacingTokens.sp2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
                    .shadow(color: .black.opacity(0.1), radius: 6)
                    .transition(.scale.combined(with: .opacity))
                Spacer()
            }
            .padding(.bottom, SpacingTokens.sp6)
        }
    }

    private var celebrationOverlay: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                VStack(spacing: SpacingTokens.sp2) {
                    Text("🎉")
                        .font(.system(size: 48))
                    Text(String(localized: "shareplay.celebration.together"))
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .multilineTextAlignment(.center)
                }
                .padding(SpacingTokens.sp4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.lg))
                .shadow(color: .black.opacity(0.12), radius: 10)
                Spacer()
            }
            .padding(.bottom, SpacingTokens.sp8)
        }
        .transition(.scale.combined(with: .opacity))
        .zIndex(10)
    }

    // MARK: - Message handling

    private func handleMessage(_ message: SyncMessage) {
        switch message.kind {
        case .roundComplete(_, let score):
            let pct = Int(score * 100)
            remoteScoreText = String(
                format: String(localized: "shareplay.remote.scored"),
                pct
            )
            // Скрываем через 3 секунды
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    remoteScoreText = nil
                }
            }

        case .lyalyaCelebration:
            withAnimation(reduceMotion ? nil : .spring(response: 0.5)) {
                showCelebration = true
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    showCelebration = false
                }
            }

        case .participantReady:
            withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.2)) {
                remoteChildLabel = String(localized: "shareplay.remote.ready")
            }

        case .sessionComplete(let score):
            let pct = Int(score * 100)
            withAnimation(reduceMotion ? nil : .spring(response: 0.4)) {
                remoteScoreText = String(
                    format: String(localized: "shareplay.remote.final_score"),
                    pct
                )
            }

        default:
            break
        }
    }
}

// MARK: - Preview

#Preview("SharePlay Session View") {
    let ctrl = FamilyShareplayController()
    let lesson = SharePlayLessonItem(
        id: "sp-001",
        title: String(localized: "shareplay.lesson.sound_s"),
        soundId: "с",
        templateKind: "repeatAfterModel"
    )
    return ZStack {
        ColorTokens.Parent.bg.ignoresSafeArea()
        VStack {
            SharePlaySessionView(
                controller: ctrl,
                lesson: lesson,
                onMessage: { _ in },
                onEnd: {}
            )
        }
    }
}

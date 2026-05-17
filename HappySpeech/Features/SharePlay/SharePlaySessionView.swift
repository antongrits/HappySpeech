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
                .font(TypographyTokens.body(15))
                .foregroundStyle(ColorTokens.Brand.primary)
                .accessibilityHidden(true)

            // Метка участников
            if let label = remoteChildLabel {
                Text(label)
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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
                .minimumScaleFactor(0.85)
            }

            Spacer(minLength: SpacingTokens.sp2)

            // Кнопка завершения
            Button(action: onEnd) {
                HStack(spacing: SpacingTokens.micro) {
                    Image(systemName: "xmark")
                        .font(TypographyTokens.caption(12))
                    Text(String(localized: "shareplay.session.end"))
                        .font(TypographyTokens.caption(12))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .foregroundStyle(ColorTokens.Overlay.onAccent)
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
        .shadow(color: ColorTokens.Overlay.shadow, radius: 6, y: 2)
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SpacingTokens.sp4)
                    .padding(.vertical, SpacingTokens.sp2)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.md))
                    .shadow(color: ColorTokens.Overlay.shadow, radius: 6)
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
                    // H v18 — Ляля celebrating вместо SF Symbol party.popper
                    // для соответствия комментарию в шапке файла.
                    LyalyaMascotView(state: .celebrating, size: 80)
                        .accessibilityHidden(true)
                    Text(String(localized: "shareplay.celebration.together"))
                        .font(TypographyTokens.headline(17))
                        .foregroundStyle(ColorTokens.Brand.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(SpacingTokens.sp4)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: RadiusTokens.lg))
                .shadow(color: ColorTokens.Overlay.shadow, radius: 10)
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

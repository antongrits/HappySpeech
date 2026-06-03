import AVKit
import OSLog
import SwiftUI

// MARK: - CutscenePlayerView
//
// Fullscreen-плеер нарративной кат-сцены поверх `AppCoordinatorView`
// (`fullScreenCover`). 9:16-видео на чёрном фоне с озвучкой Ляли.
//
// Стратегия деградации (graceful — никогда не падает):
//   1. Reduce Motion ИЛИ видеофайл отсутствует → статичный постер + субтитр-
//      карточка с текстом озвучки + кнопка «Дальше». Если нет ни видео, ни
//      постера-imageset — мягкий нейтральный градиент-фон (плеер не падает).
//   2. Иначе → AVPlayer fullscreen .aspectRatio(.fit), автозапуск, наблюдение
//      AVPlayerItemDidPlayToEndTime → onFinish. Кнопка «Пропустить» ≥56pt.
//
// onFinish ВСЕГДА закрывает сцену через `cutsceneService.pop()` (который
// помечает её seen). Skip и «досмотрел до конца» эквивалентны.

struct CutscenePlayerView: View {

    // MARK: - Inputs

    let cutscene: Cutscene
    /// Вызывается при skip ИЛИ завершении видео ИЛИ нажатии «Дальше» в фолбэке.
    let onFinish: () -> Void

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppContainer.self) private var container

    // MARK: - State

    @State private var player: AVPlayer?
    @State private var showSkip: Bool = false
    @State private var didResolveVideo: Bool = false
    @State private var videoURL: URL?

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CutscenePlayerView")

    /// Размер touch-target для kids (Apple HIG): ≥56pt.
    private let skipTouchTarget: CGFloat = 56

    // MARK: - Body

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            content
        }
        .task { await resolveAndStart() }
        .onDisappear { player?.pause() }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if useStaticFallback {
            staticFallback
        } else if let player {
            videoContent(player: player)
        } else {
            // Видео ещё резолвится — нейтральный чёрный экран с прогрессом, чтобы
            // первый кадр не мигал.
            ProgressView()
                .controlSize(.large)
                .tint(ColorTokens.Overlay.onAccent)
                .accessibilityHidden(true)
        }
    }

    /// Использовать статичный фолбэк (постер + субтитр), если включён Reduce
    /// Motion ИЛИ видеофайл отсутствует.
    private var useStaticFallback: Bool {
        reduceMotion || (didResolveVideo && videoURL == nil)
    }

    // MARK: - Video

    @ViewBuilder
    private func videoContent(player: AVPlayer) -> some View {
        ZStack {
            VideoPlayer(player: player)
                .aspectRatio(9.0 / 16.0, contentMode: .fit)
                .ignoresSafeArea()
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .AVPlayerItemDidPlayToEndTime,
                        object: player.currentItem
                    )
                ) { _ in
                    finish()
                }
                .accessibilityLabel(Text(String(localized: cutsceneVoiceoverKey)))

            skipButton
        }
    }

    // MARK: - Static fallback (poster + subtitle)

    private var staticFallback: some View {
        ZStack {
            posterLayer

            VStack {
                Spacer()
                subtitleCard
                nextButton
                    .padding(.top, SpacingTokens.regular)
                    .padding(.bottom, SpacingTokens.xLarge)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)

            skipButton
        }
        .accessibilityElement(children: .contain)
    }

    /// Постер-imageset. Если ассета нет — мягкий нейтральный градиент (не падаем).
    @ViewBuilder
    private var posterLayer: some View {
        if UIImage(named: cutscene.posterAssetName) != nil {
            Image(cutscene.posterAssetName)
                .resizable()
                .scaledToFill()
                .ignoresSafeArea()
                .accessibilityHidden(true)
        } else {
            LinearGradient(
                colors: [
                    ColorTokens.Brand.lilac.opacity(0.55),
                    ColorTokens.Brand.sky.opacity(0.45)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .overlay(
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(ColorTokens.Overlay.onAccent.opacity(0.85))
                    .accessibilityHidden(true)
            )
        }
    }

    private var subtitleCard: some View {
        Text(String(localized: cutsceneVoiceoverKey))
            .font(TypographyTokens.body(17))
            .foregroundStyle(ColorTokens.Overlay.onAccent)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, SpacingTokens.large)
            .padding(.vertical, SpacingTokens.regular)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: RadiusTokens.lg)
                    .fill(ColorTokens.Overlay.dimmerHeavy)
            )
    }

    private var nextButton: some View {
        Button {
            finish()
        } label: {
            Text(String(localized: "cutscene.next"))
                .font(TypographyTokens.body(17).weight(.semibold))
                .foregroundStyle(ColorTokens.Overlay.onAccent)
                .frame(maxWidth: .infinity, minHeight: skipTouchTarget)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .background(
                    Capsule().fill(ColorTokens.Brand.primary)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(String(localized: "cutscene.next")))
        .accessibilityAddTraits(.isButton)
    }

    // MARK: - Skip button (≥56pt, top-trailing)

    private var skipButton: some View {
        VStack {
            HStack {
                Spacer()
                if showSkip || useStaticFallback {
                    Button {
                        finish()
                    } label: {
                        Label(
                            String(localized: "cutscene.skip"),
                            systemImage: "forward.fill"
                        )
                        .labelStyle(.titleAndIcon)
                        .font(TypographyTokens.body(15).weight(.medium))
                        .foregroundStyle(ColorTokens.Overlay.onAccent)
                        .padding(.horizontal, SpacingTokens.regular)
                        .frame(minWidth: skipTouchTarget, minHeight: skipTouchTarget)
                        .background(
                            Capsule().fill(ColorTokens.Overlay.dimmerHeavy)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String(localized: "cutscene.skip.accessibility")))
                    .accessibilityAddTraits(.isButton)
                    .transition(reduceMotion ? .identity : .opacity)
                }
            }
            .padding(.trailing, SpacingTokens.screenEdge)
            .padding(.top, SpacingTokens.regular)
            Spacer()
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: showSkip)
    }

    // MARK: - Lifecycle

    private func resolveAndStart() async {
        let url = container.videoPlayerService.videoURL(for: cutscene.videoResourceName)
        videoURL = url
        didResolveVideo = true

        // В Reduce-Motion видео не автозапускаем — показываем постер+субтитр.
        guard !reduceMotion, let url else {
            if url == nil {
                logger.info("cutscene '\(cutscene.id, privacy: .public)' video missing — static fallback")
            }
            showSkip = true
            return
        }

        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.play()
        player = avPlayer

        // Кнопка «Пропустить» появляется через 1 с, чтобы не перекрывать первый кадр.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.0))
            showSkip = true
        }
    }

    private func finish() {
        player?.pause()
        onFinish()
    }

    private var cutsceneVoiceoverKey: String.LocalizationValue {
        String.LocalizationValue(cutscene.voiceoverKey)
    }
}

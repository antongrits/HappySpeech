import AVKit
import OSLog
import SwiftUI

// MARK: - StoryPlayerView
//
// AVPlayer с субтитрами поверх (Text overlay) и кнопкой «Пропустить».
//
// Стратегия деградации:
//   1. videoURL != nil → AVPlayer (MP4 из бандла)
//   2. videoURL == nil → placeholder градиент с текстом описания
//
// Reduced Motion: скрывает transition-анимации появления/исчезновения overlay.

struct StoryPlayerView: View {

    // MARK: - API

    /// ID видео из video-manifest.json (например "intro", "celebrate_star3").
    let videoID: String

    /// Субтитры отображаются поверх видео в нижней части.
    let subtitle: String?

    /// Колбэк вызывается когда пользователь нажимает «Пропустить» или видео заканчивается.
    let onDismiss: (() -> Void)?

    // MARK: - Private state

    @State private var player: AVPlayer?
    @State private var isPlaying: Bool = false
    @State private var showSkip: Bool = false
    @State private var isVisible: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let service: any VideoPlayerServiceProtocol
    private let logger = Logger(subsystem: "ru.happyspeech", category: "StoryPlayerView")

    // MARK: - Init

    init(
        videoID: String,
        subtitle: String? = nil,
        onDismiss: (() -> Void)? = nil,
        service: any VideoPlayerServiceProtocol = MockVideoPlayerService()
    ) {
        self.videoID = videoID
        self.subtitle = subtitle
        self.onDismiss = onDismiss
        self.service = service
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            playerOrPlaceholder
                .clipShape(RoundedRectangle(cornerRadius: 20))

            subtitleOverlay

            skipButton
        }
        .scaleEffect(isVisible ? 1 : 0.95)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(reduceMotion ? .none : MotionTokens.spring) {
                isVisible = true
            }
            setupPlayer()
            scheduleSkipButton()
        }
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: - Player or placeholder

    @ViewBuilder
    private var playerOrPlaceholder: some View {
        if let player {
            VideoPlayer(player: player)
                .disabled(false)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: .AVPlayerItemDidPlayToEndTime,
                        object: player.currentItem
                    )
                ) { _ in
                    onDismiss?()
                }
        } else {
            placeholderView
        }
    }

    // MARK: - Placeholder (когда MP4 не найден)

    private var placeholderView: some View {
        let entry = service.manifest(for: videoID)
        return ZStack {
            LinearGradient(
                colors: [Color("BrandPrimary", bundle: nil).opacity(0.7),
                         Color("BrandSky", bundle: nil).opacity(0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            VStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.white.opacity(0.8))
                if let desc = entry?.description {
                    Text(desc)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .lineLimit(nil)
                        .minimumScaleFactor(0.85)
                }
            }
        }
        .aspectRatio(16 / 9, contentMode: .fit)
    }

    // MARK: - Subtitle overlay

    @ViewBuilder
    private var subtitleOverlay: some View {
        if let subtitle, !subtitle.isEmpty {
            Text(subtitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.6))
                )
                .padding(.bottom, 52)
                .padding(.horizontal, 16)
                .lineLimit(nil)
                .minimumScaleFactor(0.85)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Skip button

    private var skipButton: some View {
        HStack {
            Spacer()
            if showSkip {
                Button {
                    player?.pause()
                    onDismiss?()
                } label: {
                    Label(
                        String(localized: "story_player.skip"),
                        systemImage: "forward.fill"
                    )
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.5))
                    )
                }
                .transition(reduceMotion ? .identity : .opacity)
                .padding(.trailing, 16)
                .padding(.bottom, 12)
                .accessibilityLabel(String(localized: "story_player.skip.accessibility"))
            }
        }
        .animation(reduceMotion ? .none : MotionTokens.outQuick, value: showSkip)
    }

    // MARK: - Setup

    private func setupPlayer() {
        guard let url = service.videoURL(for: videoID) else {
            logger.info("MP4 для '\(videoID)' не найден — показываем placeholder")
            return
        }
        let item = AVPlayerItem(url: url)
        let avPlayer = AVPlayer(playerItem: item)
        avPlayer.play()
        player = avPlayer
        isPlaying = true
    }

    private func scheduleSkipButton() {
        // Кнопка «Пропустить» появляется через 1 сек чтобы не мешать первому кадру
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            showSkip = true
        }
    }
}

// MARK: - Preview

#Preview("StoryPlayerView — placeholder") {
    StoryPlayerView(
        videoID: "intro",
        subtitle: "Привет! Я Ляля — твой помощник в мире звуков!",
        onDismiss: { },
        service: MockVideoPlayerService()
    )
    .padding(24)
}

#Preview("StoryPlayerView — без субтитров") {
    StoryPlayerView(
        videoID: "celebrate_star3",
        onDismiss: { },
        service: MockVideoPlayerService()
    )
    .padding(24)
}

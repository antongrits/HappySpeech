import AVKit
import SwiftUI

// MARK: - ArticulationVideoPlayerView
//
// Встраиваемый плеер side-view артикуляционной схемы.
// Показывается в SoundDictionary detail sheet для звуков С, Ш, Р, Л.
//
// Видео: Resources/Videos/Articulation/programmatic/*.mp4
// Источник: Remotion, программная анимация (научно корректные профили по Фомичёвой).
//
// Lifecycle: плеер создаётся на месте, auto-play при появлении, зацикленный.
// Не использует AVPlayerViewController (нет системных контролов — дизайн чистый).
//
// Reduced Motion: при reduceMotion видео ставится на паузу на первом кадре (статичное).

struct ArticulationVideoPlayerView: View {

    let videoSlug: VideoCatalog.ArticulationDemo
    let soundLetter: String

    @State private var player: AVPlayer?
    @State private var looper: AVPlayerLooper?
    @State private var isReady: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            // Section header
            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: "mouth.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text("soundDictionary.detail.articulationVideo.label")
                    .font(TypographyTokens.caption(11))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                Spacer()
                // «Программная схема» badge
                Text(String(localized: "soundDictionary.detail.articulationVideo.badge"))
                    .font(TypographyTokens.caption(9))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(ColorTokens.Brand.primary.opacity(0.12)))
            }

            // Video container 16:9
            ZStack {
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Brand.butter.opacity(0.25))
                    .aspectRatio(16 / 9, contentMode: .fit)

                if let player {
                    VideoPlayer(player: player)
                        .disabled(true)
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                        .allowsHitTesting(false)
                } else {
                    // Loading placeholder
                    VStack(spacing: SpacingTokens.sp2) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.system(size: 36))
                            .foregroundStyle(ColorTokens.Brand.primary.opacity(0.4))
                        Text(String(localized: "soundDictionary.detail.articulationVideo.loading"))
                            .font(TypographyTokens.caption(12))
                            .foregroundStyle(ColorTokens.Parent.inkMuted)
                    }
                    .aspectRatio(16 / 9, contentMode: .fit)
                }
            }
            .accessibilityLabel(
                Text(
                    String(
                        format: String(localized: "soundDictionary.detail.articulationVideo.a11y"),
                        soundLetter
                    )
                )
            )

            // Subtitle
            Text(String(localized: "soundDictionary.detail.articulationVideo.subtitle"))
                .font(TypographyTokens.caption(10))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .lineLimit(nil)
        }
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Brand.butter.opacity(0.15))
        )
        .task {
            await setupPlayer()
        }
        .onDisappear {
            player?.pause()
        }
    }

    // MARK: - Private

    private func setupPlayer() async {
        guard let url = VideoCatalog.url(for: .articulation(videoSlug)) else { return }
        let item = AVPlayerItem(url: url)
        let queuePlayer = AVQueuePlayer()
        let playerLooper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        self.looper = playerLooper
        self.player = queuePlayer
        if !reduceMotion {
            queuePlayer.play()
        } else {
            // Reduced motion: show first frame only
            queuePlayer.seek(to: .zero, completionHandler: { _ in })
        }
    }
}

// MARK: - ArticulationVideoSlug mapping

extension VideoCatalog.ArticulationDemo {
    /// Возвращает programmatic side-view профиль для данного звука (если есть).
    static func profileDemo(forCyrillic cyrillic: String) -> VideoCatalog.ArticulationDemo? {
        switch cyrillic {
        case "С", "Сь", "Ц":
            return .articulationSProfile
        case "З", "Зь":
            return .articulationZProfile
        case "Ш", "Ч", "Щ":
            return .articulationShProfile
        case "Ж":
            return .articulationZhProfile
        case "Р", "Рь":
            return .articulationRProfile
        case "Л", "Ль":
            return .articulationLProfile
        default:
            return nil
        }
    }
}

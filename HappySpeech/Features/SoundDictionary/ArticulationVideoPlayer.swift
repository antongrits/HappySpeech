import AVKit
import SwiftUI

// MARK: - ArticulationVideoPlayerView
//
// Встраиваемый плеер side-view артикуляционной схемы. Показывается в
// SoundDictionary detail карточке артикуляции.
//
// Два источника:
//  • Veo (8 звуков Р/Л/Ш/С/Ж/Ч/Щ/З) — профессиональная 3D-анимация
//    сагиттального разреза рта (Google Veo 3.1), Resources/Videos/Articulation/veo/.
//  • Программные профили (Remotion) — Resources/Videos/Articulation/programmatic/.
//
// Видео без звука: эталонное произношение (Chirp3) проигрывается отдельной
// CTA «Прослушать» в detail sheet.
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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Профессиональная Veo-демонстрация → другой заголовок/бейдж/подпись.
    private var isVeo: Bool { videoSlug.isVeo }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            // Section header
            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: "mouth.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text(isVeo
                    ? "soundDictionary.detail.articulationVideo.veo.label"
                    : "soundDictionary.detail.articulationVideo.label")
                    .font(TypographyTokens.caption(11))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                Text(isVeo
                    ? String(localized: "soundDictionary.detail.articulationVideo.veo.badge")
                    : String(localized: "soundDictionary.detail.articulationVideo.badge"))
                    .font(TypographyTokens.caption(9))
                    .foregroundStyle(ColorTokens.Brand.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
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
                        format: String(localized: isVeo
                            ? "soundDictionary.detail.articulationVideo.veo.a11y"
                            : "soundDictionary.detail.articulationVideo.a11y"),
                        soundLetter
                    )
                )
            )

            // Subtitle
            Text(String(localized: isVeo
                ? "soundDictionary.detail.articulationVideo.veo.subtitle"
                : "soundDictionary.detail.articulationVideo.subtitle"))
                .font(TypographyTokens.caption(10))
                .foregroundStyle(ColorTokens.Parent.inkSoft)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
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
    /// Профессиональная Veo-демонстрация «как двигается язык» для звука (если есть).
    /// Набор из 8 звуков (Р/Л/Ш/С/Ж/Ч/Щ/З) по `veo_manifest.json`. Для остальных
    /// звуков (мягкие пары, Ц и пр.) — `nil`, показывается только 3D-модель.
    static func veoDemo(forCyrillic cyrillic: String) -> VideoCatalog.ArticulationDemo? {
        switch cyrillic.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "Р": return .veoR
        case "Л": return .veoL
        case "Ш": return .veoSh
        case "С": return .veoS
        case "Ж": return .veoZh
        case "Ч": return .veoCh
        case "Щ": return .veoShch
        case "З": return .veoZ
        default: return nil
        }
    }
}

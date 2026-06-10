import SwiftUI

// MARK: - Articulation3DCard
//
// Карточка с интерактивной 3D-моделью артикуляции для SoundDictionary detail.
// Показывает вращаемый сагиттальный разрез головы с позой языка для звука,
// SwiftUI-оверлей с подсказкой позы и научными индикаторами (звонкость,
// поднятое мягкое нёбо), а также сегмент-переключатель «3D / Видео», если
// для звука есть и видео-схема.
//
// Reduced Motion: морфинг и авто-движения отключаются (поза ставится мгновенно).

struct Articulation3DCard: View {

    /// Кириллическая буква звука (как в SoundDictionary title), напр. «Ш».
    let cyrillic: String
    /// Слаг видео-схемы, если есть (для сегмент-переключателя на видео-фоллбэк).
    let videoSlug: VideoCatalog.ArticulationDemo?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = .model

    private enum Mode: Hashable {
        case model
        case video
    }

    private var sound: ArticulationSound {
        ArticulationSound.fromCyrillic(cyrillic) ?? .neutral
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            header

            if mode == .model {
                modelStage
            } else if let videoSlug {
                ArticulationVideoPlayerView(videoSlug: videoSlug, soundLetter: cyrillic)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(SpacingTokens.sp4)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md)
                .fill(ColorTokens.Parent.bg)
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: SpacingTokens.sp1) {
            Image(systemName: "cube.transparent.fill")
                .font(.system(size: 13))
                .foregroundStyle(ColorTokens.Brand.primary)
            Text("articulation3d.title")
                .font(TypographyTokens.caption(11))
                .textCase(.uppercase)
                .tracking(0.5)
                .foregroundStyle(ColorTokens.Parent.inkMuted)

            Spacer()

            if videoSlug != nil {
                Picker("articulation3d.mode.picker", selection: $mode) {
                    Text("articulation3d.mode.model").tag(Mode.model)
                    Text("articulation3d.mode.video").tag(Mode.video)
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .accessibilityLabel(Text("articulation3d.mode.picker"))
            }
        }
    }

    // MARK: 3D model stage

    private var modelStage: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Brand.butter.opacity(0.22))

                ArticulationScene3DView(sound: sound, reduceMotion: reduceMotion)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                    .accessibilityElement()
                    .accessibilityLabel(Text("articulation3d.a11y.scene"))
                    .accessibilityValue(Text(sound.localizedHint))

                // Подсказка «вращай пальцем» (мелкая, не мешает).
                if !reduceMotion {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.draw.fill")
                            .font(.system(size: 10))
                        Text("articulation3d.hint.rotate")
                            .font(TypographyTokens.caption(9))
                    }
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(ColorTokens.Parent.surface.opacity(0.85)))
                    .padding(SpacingTokens.sp2)
                    .allowsHitTesting(false)
                }
            }
            .aspectRatio(4 / 3, contentMode: .fit)

            poseLabel
            indicators
        }
    }

    // MARK: Pose label + indicators (SwiftUI-оверлей, не текст внутри 3D)

    private var poseLabel: some View {
        Text(sound.localizedHint)
            .font(TypographyTokens.body(13))
            .foregroundStyle(ColorTokens.Parent.ink)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var indicators: some View {
        HStack(spacing: SpacingTokens.sp2) {
            // Поднятое мягкое нёбо — у всех ротовых русских согласных.
            indicatorChip(
                systemImage: "arrow.up.circle.fill",
                titleKey: "articulation3d.indicator.velum",
                tint: ColorTokens.Brand.lilac
            )

            // Звонкость.
            indicatorChip(
                systemImage: sound.isVoiced ? "waveform.path" : "waveform",
                titleKey: sound.isVoiced
                    ? "articulation3d.indicator.voiced"
                    : "articulation3d.indicator.voiceless",
                tint: sound.isVoiced ? ColorTokens.Brand.rose : ColorTokens.Parent.inkMuted
            )
        }
    }

    private func indicatorChip(
        systemImage: String,
        titleKey: LocalizedStringKey,
        tint: Color
    ) -> some View {
        HStack(spacing: 5) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .foregroundStyle(tint)
            Text(titleKey)
                .font(TypographyTokens.caption(10))
                .foregroundStyle(ColorTokens.Parent.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

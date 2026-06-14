import SwiftUI

// MARK: - Articulation3DCard
//
// Карточка артикуляции для SoundDictionary detail. Два режима показа уклада:
//  • «Видео» — профессиональное Veo-видео (8 звуков Р/Л/Ш/С/Ж/Ч/Щ/З), основной
//    визуал «как двигается язык» (медицинская демонстрация, Google Veo).
//  • «Настоящий рот» — интерактивная вращаемая 3D-модель рта для рассматривания.
//
// Если у звука есть Veo-видео — стартуем на «Видео» и показываем сегмент-
// переключатель с обоими режимами. Если видео нет — показываем только «Настоящий
// рот» (3D) без переключателя.
//
// Reduced Motion: авто-движения и автоплей видео отключаются (учитывается внутри
// плеера и 3D-сцены).

struct Articulation3DCard: View {

    /// Кириллическая буква звука (как в SoundDictionary title), напр. «Ш».
    let cyrillic: String
    /// Слаг видео-демонстрации, если есть (Veo для 8 звуков или nil).
    let videoSlug: VideoCatalog.ArticulationDemo?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode

    private enum Mode: Hashable {
        case video
        case realMouth
    }

    /// Есть ли профессиональное Veo-видео для этого звука.
    private var hasVideo: Bool { videoSlug != nil }

    init(cyrillic: String, videoSlug: VideoCatalog.ArticulationDemo?) {
        self.cyrillic = cyrillic
        self.videoSlug = videoSlug
        // Есть видео → оно стартовый визуал; иначе — сразу 3D-модель.
        _mode = State(initialValue: videoSlug != nil ? .video : .realMouth)
    }

    private var sound: ArticulationSound {
        ArticulationSound.fromCyrillic(cyrillic) ?? .neutral
    }

    var body: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            header

            switch mode {
            case .video:
                if let videoSlug {
                    ArticulationVideoPlayerView(videoSlug: videoSlug, soundLetter: cyrillic)
                    poseLabel
                    indicators
                } else {
                    realMouthStage
                }
            case .realMouth:
                realMouthStage
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
    //
    // Заголовок + (если есть видео) полноширинный сегмент-переключатель режимов.
    // Переключатель вынесен на отдельную строку и растянут на всю ширину, чтобы
    // оба сегмента (особенно длинный «Настоящий рот») не обрезались на узком SE
    // (375pt). Без видео переключатель не нужен — показывается только 3D.

    private var header: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            HStack(spacing: SpacingTokens.sp1) {
                Image(systemName: "lungs.fill")
                    .font(TypographyTokens.caption(13))
                    .foregroundStyle(ColorTokens.Brand.primary)
                Text("articulation3d.title")
                    .font(TypographyTokens.caption(11))
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                Spacer(minLength: 0)
            }

            if hasVideo {
                Picker("articulation3d.mode.picker", selection: $mode) {
                    Text("articulation3d.mode.video").tag(Mode.video)
                    Text("articulation3d.mode.realMouth").tag(Mode.realMouth)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text("articulation3d.mode.picker"))
            }
        }
    }

    // MARK: Real-mouth stage (вращаемая 3D-модель)

    private var realMouthStage: some View {
        VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: RadiusTokens.md)
                    .fill(ColorTokens.Brand.butter.opacity(0.22))

                ArticulationScene3DView(reduceMotion: reduceMotion)
                    .clipShape(RoundedRectangle(cornerRadius: RadiusTokens.md))
                    .accessibilityElement()
                    .accessibilityLabel(Text("articulation3d.a11y.scene"))

                if !reduceMotion {
                    HStack(spacing: 4) {
                        Image(systemName: "hand.draw.fill")
                            .font(TypographyTokens.caption(10))
                        Text("articulation3d.hint.rotate")
                            .font(TypographyTokens.caption(9))
                    }
                    .foregroundStyle(ColorTokens.Parent.inkMuted)
                    .padding(.horizontal, SpacingTokens.tiny)
                    .padding(.vertical, SpacingTokens.micro)
                    .background(Capsule().fill(ColorTokens.Parent.surface.opacity(0.85)))
                    .padding(SpacingTokens.sp2)
                    .allowsHitTesting(false)
                }
            }
            .aspectRatio(4 / 3, contentMode: .fit)

            poseLabel
            indicators
            attribution
        }
    }

    // MARK: Attribution (CC-BY 4.0 для исходной 3D-модели)

    private var attribution: some View {
        Text("articulation3d.attribution")
            .font(TypographyTokens.caption(9))
            .foregroundStyle(ColorTokens.Parent.inkMuted)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Pose label + indicators

    private var poseLabel: some View {
        Text(sound.localizedHint)
            .font(TypographyTokens.body(13))
            .foregroundStyle(ColorTokens.Parent.ink)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var indicators: some View {
        HStack(spacing: SpacingTokens.sp2) {
            indicatorChip(
                systemImage: "arrow.up.circle.fill",
                titleKey: "articulation3d.indicator.velum",
                tint: ColorTokens.Brand.lilac
            )
            indicatorChip(
                systemImage: sound.isVoiced ? "waveform.path" : "waveform",
                titleKey: sound.isVoiced
                    ? "articulation3d.indicator.voiced"
                    : "articulation3d.indicator.voiceless",
                tint: sound.isVoiced ? ColorTokens.Brand.gold : ColorTokens.Parent.inkMuted
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
                .font(TypographyTokens.caption(11))
                .foregroundStyle(tint)
            Text(titleKey)
                .font(TypographyTokens.caption(10))
                .foregroundStyle(ColorTokens.Parent.ink)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, SpacingTokens.tiny)
        .padding(.vertical, 5)
        .background(Capsule().fill(tint.opacity(0.12)))
    }
}

// MARK: - Preview

#Preview("Card — Ш") {
    Articulation3DCard(cyrillic: "Ш", videoSlug: nil)
        .padding()
        .background(ColorTokens.Parent.bg)
}

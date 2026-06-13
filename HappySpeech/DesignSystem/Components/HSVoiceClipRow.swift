import SwiftUI

// MARK: - HSWaveformThumbnail
//
// Статичная «миниатюра волны» для строки сохранённой записи (эталон
// parent-voice: clip-wave). Высоты баров детерминированы по seed (id строки),
// поэтому одинаковы между перерисовками и не зависят от случайности — это
// визуальный декор строки, НЕ фабрикация аудио-амплитуд.
//
// `progress` (0…1) заливает левую часть волны акцентом — режим
// «сейчас играет». Декоративный элемент: помечен accessibilityHidden.

/// Декоративная статичная миниатюра звуковой волны для строки записи.
public struct HSWaveformThumbnail: View {

    private let seed: Int
    private let progress: Double
    private let tint: Color
    private let softTint: Color
    private let barCount: Int

    public init(
        seed: Int,
        progress: Double = 0,
        tint: Color,
        softTint: Color,
        barCount: Int = 30
    ) {
        self.seed = seed
        self.progress = max(0, min(1, progress))
        self.tint = tint
        self.softTint = softTint
        self.barCount = barCount
    }

    public var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 2
            let barWidth = max(
                1.5,
                (geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
            )
            HStack(alignment: .center, spacing: spacing) {
                ForEach(0..<barCount, id: \.self) { i in
                    let h = Self.height(index: i, seed: seed)
                    let filled = Double(i) / Double(barCount) < progress
                    RoundedRectangle(cornerRadius: barWidth / 2, style: .continuous)
                        .fill(filled ? tint : softTint)
                        .frame(width: barWidth, height: max(3, h * geo.size.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .accessibilityHidden(true)
    }

    /// Детерминированная высота бара (0.22…1.0) — линейный конгруэнтный
    /// генератор, как в эталоне (стабильно для одного seed).
    private static func height(index: Int, seed: Int) -> CGFloat {
        var s = UInt32(truncatingIfNeeded: seed &* 2654435761 &+ index &* 40503)
        s = (s &* 9301 &+ 49297) % 233280
        let r = CGFloat(s) / 233280
        return 0.22 + r * r * 0.78
    }
}

// MARK: - HSVoiceClipRow
//
// Строка сохранённой голосовой записи (эталон parent-voice: clip-row):
// круглая кнопка play/pause + миниатюра волны + заголовок/дата + длительность.
// Состояние «сейчас играет» подсвечивает рамку и заливает кнопку акцентом.

/// Строка сохранённой записи с миниатюрой волны, кнопкой воспроизведения
/// и метаданными (заголовок · дата, длительность).
public struct HSVoiceClipRow: View {

    private let title: String
    private let subtitle: String?
    private let durationText: String
    private let isPlaying: Bool
    private let progress: Double
    private let accessibilityLabel: String
    private let onPlay: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        subtitle: String? = nil,
        durationText: String,
        isPlaying: Bool,
        progress: Double = 0,
        accessibilityLabel: String,
        onPlay: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.durationText = durationText
        self.isPlaying = isPlaying
        self.progress = progress
        self.accessibilityLabel = accessibilityLabel
        self.onPlay = onPlay
    }

    /// Детерминированный seed из содержимого строки (FNV-1a). Не зависит от
    /// рандомизированного `String.hashValue`, поэтому форма волны стабильна
    /// между запусками и в snapshot-тестах.
    private var seed: Int {
        var hash: UInt32 = 2166136261
        for byte in (title + durationText).utf8 {
            hash ^= UInt32(byte)
            hash = hash &* 16777619
        }
        return Int(hash & 0x7FFF_FFFF)
    }

    public var body: some View {
        HStack(spacing: SpacingTokens.sp3) {
            Button(action: onPlay) {
                ZStack {
                    Circle()
                        .fill(isPlaying
                              ? ColorTokens.Parent.accent
                              : ColorTokens.Parent.accent.opacity(0.001))
                        .overlay(
                            Circle().strokeBorder(
                                ColorTokens.Parent.accent,
                                lineWidth: isPlaying ? 0 : 1.5
                            )
                        )
                        .frame(width: 42, height: 42)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(isPlaying
                                         ? ColorTokens.Overlay.onAccent
                                         : ColorTokens.Parent.accent)
                        .hsSymbolEffect(.bounce, value: isPlaying)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(isPlaying
                ? String(localized: "voice.clip.pause.a11y")
                : String(localized: "voice.clip.play.a11y")))

            VStack(alignment: .leading, spacing: SpacingTokens.sp2) {
                HSWaveformThumbnail(
                    seed: seed,
                    progress: isPlaying ? progress : 0,
                    tint: ColorTokens.Parent.accent,
                    softTint: ColorTokens.Parent.accent.opacity(0.28)
                )
                .frame(height: 26)

                HStack(spacing: SpacingTokens.sp2) {
                    Text(rowTitle)
                        .font(TypographyTokens.caption(13).weight(.semibold))
                        .foregroundStyle(ColorTokens.Parent.ink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Spacer(minLength: SpacingTokens.sp2)
                    Text(durationText)
                        .font(TypographyTokens.caption(12).monospacedDigit())
                        .foregroundStyle(ColorTokens.Parent.inkSoft)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, SpacingTokens.sp3)
        .padding(.vertical, SpacingTokens.sp3)
        .background(
            RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                .fill(ColorTokens.Parent.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: RadiusTokens.md, style: .continuous)
                        .strokeBorder(
                            isPlaying
                                ? ColorTokens.Parent.accent.opacity(0.45)
                                : ColorTokens.Parent.line,
                            lineWidth: 1
                        )
                )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    private var rowTitle: String {
        if let subtitle, !subtitle.isEmpty {
            return "\(title) · \(subtitle)"
        }
        return title
    }
}

// MARK: - Preview

#if DEBUG
#Preview("HSVoiceClipRow") {
    VStack(spacing: 12) {
        HSVoiceClipRow(
            title: "Голос мамы",
            subtitle: "вчера",
            durationText: "0:12",
            isPlaying: true,
            progress: 0.4,
            accessibilityLabel: "Голос мамы, вчера, 12 секунд"
        ) {}
        HSVoiceClipRow(
            title: "Сказка на ночь",
            subtitle: "3 дня назад",
            durationText: "1:24",
            isPlaying: false,
            accessibilityLabel: "Сказка на ночь, 3 дня назад, 1 минута 24 секунды"
        ) {}
    }
    .padding()
    .background(ColorTokens.Parent.bg)
    .environment(\.circuitContext, .parent)
}
#endif

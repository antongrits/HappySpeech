import SwiftUI

// MARK: - SpectrogramCanvasView

/// SwiftUI Canvas-рендер спектрограммы с TimelineView для 60 fps анимации.
///
/// Отображает mel-частотные кадры в виде цветных столбиков:
/// низкие magnitude → холодный (синий) цвет, высокие → тёплый (красный).
///
/// Автоматически переключается на ``StaticSpectrogramView`` при `accessibilityReduceMotion`.
///
/// ## Accessibility
/// - `accessibilityLabel` описывает содержимое (live или эталонная).
/// - Поддерживает Dynamic Type (размер не влияет — только Canvas).
///
/// ## See Also
/// - ``SpectrogramVisualizerView``
/// - ``StaticSpectrogramView``
public struct SpectrogramCanvasView: View {

    // MARK: - API

    /// Спектрограмма для рендера.
    public let spectrogram: Spectrogram

    /// Accessibility-метка.
    public let label: String

    /// Живая запись (true) или эталон (false) — влияет на Reduce Motion behaviour.
    public let isLive: Bool

    /// Цветовая тема.
    public var style: SpectrogramStyle

    /// Конфигурация нормализации.
    public var renderConfig: SpectrogramRenderConfig

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Init

    public init(
        spectrogram: Spectrogram,
        label: String,
        isLive: Bool = false,
        style: SpectrogramStyle = .neutral,
        renderConfig: SpectrogramRenderConfig = .defaultConfig
    ) {
        self.spectrogram = spectrogram
        self.label = label
        self.isLive = isLive
        self.style = style
        self.renderConfig = renderConfig
    }

    // MARK: - Body

    public var body: some View {
        Group {
            if reduceMotion && isLive {
                StaticSpectrogramView(spectrogram: spectrogram, style: style)
            } else if spectrogram.frames.isEmpty {
                emptyStateView
            } else {
                animatedCanvas
            }
        }
        .accessibilityLabel(label)
        .accessibilityHint(
            isLive
            ? String(localized: "spectrogram.canvas.hint.live",
                     defaultValue: "Живая запись голоса")
            : String(localized: "spectrogram.canvas.hint.reference",
                     defaultValue: "Эталонный образец звука")
        )
    }

    // MARK: - Animated canvas

    @ViewBuilder
    private var animatedCanvas: some View {
        if isLive {
            TimelineView(.animation) { _ in
                canvas
            }
        } else {
            canvas
        }
    }

    private var canvas: some View {
        Canvas { context, size in
            drawSpectrogram(context: context, size: size, spectrogram: spectrogram)
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hue: style.lowHue / 360.0, saturation: 0.15, brightness: 0.2).opacity(0.4))
            Text(
                isLive
                ? String(localized: "spectrogram.empty.live", defaultValue: "Говори...")
                : String(localized: "spectrogram.empty.reference", defaultValue: "Нет эталона")
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Drawing

    private func drawSpectrogram(context: GraphicsContext, size: CGSize, spectrogram: Spectrogram) {
        guard !spectrogram.frames.isEmpty else { return }

        let nTimeBins = spectrogram.frames.count
        let nFreqBins = spectrogram.frames[0].count

        guard nFreqBins > 0 else { return }

        let barWidth = size.width / CGFloat(nTimeBins)
        let binHeight = size.height / CGFloat(nFreqBins)

        for (timeIdx, frame) in spectrogram.frames.enumerated() {
            let x = CGFloat(timeIdx) * barWidth
            for (freqIdx, magnitude) in frame.enumerated() {
                let y = size.height - CGFloat(freqIdx + 1) * binHeight
                let normalized = normalizedMagnitude(magnitude)
                let color = colorFromMagnitude(normalized, style: style)
                let rect = CGRect(
                    x: x,
                    y: y,
                    width: barWidth + 1.0,
                    height: binHeight + 1.0
                )
                context.fill(Path(rect), with: .color(color))
            }
        }
    }

    // MARK: - Color mapping

    /// Нормализует log-mel значение в диапазон [0, 1].
    private func normalizedMagnitude(_ magnitude: Float) -> Float {
        let range = renderConfig.logMax - renderConfig.logMin
        guard range > 0 else { return 0 }
        return max(0, min(1, (magnitude - renderConfig.logMin) / range))
    }

    /// Переводит нормализованное значение [0, 1] в цвет через HSB градиент.
    private func colorFromMagnitude(_ normalized: Float, style: SpectrogramStyle) -> Color {
        let hue = style.lowHue + Double(normalized) * (style.highHue - style.lowHue)
        let wrappedHue = ((hue.truncatingRemainder(dividingBy: 360)) + 360)
            .truncatingRemainder(dividingBy: 360) / 360.0
        return Color(
            hue: wrappedHue,
            saturation: renderConfig.saturation,
            brightness: renderConfig.brightness * Double(0.3 + 0.7 * normalized)
        )
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SpectrogramCanvasView — эталон") {
    let mockFrames = (0..<50).map { (_: Int) in
        (0..<40).map { (_: Int) in Float.random(in: -2...2) }
    }
    let mock = Spectrogram(frames: mockFrames, sampleRate: 16_000, duration: 1.5)

    SpectrogramCanvasView(
        spectrogram: mock,
        label: "Ляля",
        isLive: false,
        style: .forest
    )
    .frame(width: 300, height: 120)
    .clipShape(RoundedRectangle(cornerRadius: 16))
    .padding()
}
#endif

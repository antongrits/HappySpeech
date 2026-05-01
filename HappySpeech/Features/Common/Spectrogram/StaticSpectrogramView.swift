import SwiftUI

// MARK: - StaticSpectrogramView

/// Статичный снимок спектрограммы без анимации.
///
/// Используется как fallback при `accessibilityReduceMotion` или когда
/// живая анимация недоступна. Рендерит первый/последний кадр спектрограммы
/// или заглушку-placeholder, если кадров нет.
///
/// ## Accessibility
/// - Полностью без анимации.
/// - Отображает ту же цветовую информацию что и ``SpectrogramCanvasView``.
///
/// ## See Also
/// - ``SpectrogramCanvasView``
/// - ``SpectrogramVisualizerView``
public struct StaticSpectrogramView: View {

    // MARK: - API

    /// Спектрограмма для отображения.
    public let spectrogram: Spectrogram

    /// Цветовая тема.
    public let style: SpectrogramStyle

    /// Конфигурация нормализации.
    public var renderConfig: SpectrogramRenderConfig

    // MARK: - Init

    public init(
        spectrogram: Spectrogram,
        style: SpectrogramStyle = .neutral,
        renderConfig: SpectrogramRenderConfig = .defaultConfig
    ) {
        self.spectrogram = spectrogram
        self.style = style
        self.renderConfig = renderConfig
    }

    // MARK: - Body

    public var body: some View {
        Canvas { context, size in
            drawStaticFrame(context: context, size: size)
        }
        .accessibilityLabel(
            String(localized: "spectrogram.static.label",
                   defaultValue: "Статичная спектрограмма")
        )
        .accessibilityHint(
            String(localized: "spectrogram.static.hint",
                   defaultValue: "Анимация отключена в настройках доступности")
        )
    }

    // MARK: - Drawing

    private func drawStaticFrame(context: GraphicsContext, size: CGSize) {
        // Берём средний кадр (репрезентативный снимок).
        let representativeFrame: [Float]

        if spectrogram.frames.isEmpty {
            representativeFrame = makePlaceholderFrame()
        } else {
            let midIndex = spectrogram.frames.count / 2
            representativeFrame = spectrogram.frames[midIndex]
        }

        let nFreqBins = representativeFrame.count
        guard nFreqBins > 0 else { return }

        // Рисуем вертикальные столбики — по одному на каждый частотный бин.
        let barWidth = size.width / CGFloat(nFreqBins)

        for (freqIdx, magnitude) in representativeFrame.enumerated() {
            let x = CGFloat(freqIdx) * barWidth

            let normalized = normalizedMagnitude(magnitude)
            let barHeight = size.height * CGFloat(normalized) * 0.85 + size.height * 0.15
            let y = size.height - barHeight

            let color = colorFromMagnitude(normalized, style: style)
            let rect = CGRect(x: x, y: y, width: barWidth - 1.0, height: barHeight)
            context.fill(Path(rect), with: .color(color))
        }
    }

    // MARK: - Placeholder

    /// Демонстрационный кадр для случая, когда спектрограммы нет.
    private func makePlaceholderFrame() -> [Float] {
        (0..<Spectrogram.melBinCount).map { bin in
            let normalized = Float(bin) / Float(Spectrogram.melBinCount)
            // Мягкая горка — даёт красивую градиентную заглушку.
            let envelope = sin(Float.pi * normalized)
            return renderConfig.logMin + envelope * (renderConfig.logMax - renderConfig.logMin)
        }
    }

    // MARK: - Color helpers

    private func normalizedMagnitude(_ magnitude: Float) -> Float {
        let range = renderConfig.logMax - renderConfig.logMin
        guard range > 0 else { return 0 }
        return max(0, min(1, (magnitude - renderConfig.logMin) / range))
    }

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
#Preview("StaticSpectrogramView — заглушка") {
    StaticSpectrogramView(spectrogram: .empty, style: .ocean)
        .frame(width: 300, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
}

#Preview("StaticSpectrogramView — с данными") {
    let frames = [(0..<40).map { Float($0) / 20.0 - 1.0 }]
    let spec = Spectrogram(frames: frames, sampleRate: 16_000, duration: 0.032)
    StaticSpectrogramView(spectrogram: spec, style: .forest)
        .frame(width: 300, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
}
#endif

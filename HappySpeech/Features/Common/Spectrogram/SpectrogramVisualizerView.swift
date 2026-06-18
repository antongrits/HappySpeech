import Combine
import OSLog
import SwiftUI

// MARK: - SpectrogramVisualizerView

/// Главный компонент визуализации спектрограммы — эталон (Ляля) vs живая запись.
///
/// Компонует две панели:
/// - Верхняя: эталонная спектрограмма Ляли (референс).
/// - Нижняя: живая запись ребёнка (обновляется в реальном времени).
///
/// Запускает ``SpectrogramAudioRecorder`` при появлении View,
/// останавливает при исчезновении. Полностью уважает Reduce Motion —
/// живая панель переключается на ``StaticSpectrogramView``.
///
/// ## Использование
/// ```swift
/// SpectrogramVisualizerView(referenceSpectrogram: lyalyaSpectrogram)
/// ```
///
/// ## COPPA / Kid circuit
/// - Никаких сетевых вызовов.
/// - Аудио не сохраняется на диск.
/// - Данные уничтожаются при onDisappear.
///
/// ## See Also
/// - ``SpectrogramCanvasView``
/// - ``SpectrogramAudioRecorder``
public struct SpectrogramVisualizerView: View {

    // MARK: - API

    /// Эталонная спектрограмма (голос Ляли). Если nil — показывает заглушку.
    public let referenceSpectrogram: Spectrogram?

    /// Цветовая тема.
    public var style: SpectrogramStyle

    // MARK: - Private State

    @State private var liveSpectrogram: Spectrogram = .empty
    @State private var isRecording: Bool = false
    @State private var recorder: SpectrogramAudioRecorder = SpectrogramAudioRecorder()
    @State private var cancellable: AnyCancellable?
    @State private var recordingError: SpectrogramError?
    @State private var showError: Bool = false

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Logger

    private let logger = Logger(subsystem: "ru.happyspeech", category: "SpectrogramVisualizerView")

    // Контент-палитра визуализации (читаемость на тёмном data-viz холсте, где
    // системный `.primary` нечитаем), не UI-chrome — forbidden_color_literal
    // отключён намеренно для этих определений.
    // swiftlint:disable forbidden_color_literal
    private enum VizTextPalette {
        static let dividerLabel = Color(red: 0.93, green: 0.84, blue: 0.76)
        static let panelTitle = Color(red: 1.0, green: 0.95, blue: 0.90)
    }
    // swiftlint:enable forbidden_color_literal

    // MARK: - Init

    public init(
        referenceSpectrogram: Spectrogram? = nil,
        style: SpectrogramStyle = .warm
    ) {
        self.referenceSpectrogram = referenceSpectrogram
        self.style = style
    }

    // MARK: - Body

    public var body: some View {
        VStack(spacing: 12) {
            // Верхняя панель — Ляля (эталон)
            referencePanel

            // Разделитель
            comparisonDivider

            // Нижняя панель — живая запись
            livePanel
        }
        .padding(SpacingTokens.regular)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(vizCanvasBackground)
        )
        .task {
            await startRecording()
        }
        .onDisappear {
            Task { await stopRecording() }
        }
        .alert(
            String(localized: "spectrogram.error.title", defaultValue: "Ошибка микрофона"),
            isPresented: $showError,
            presenting: recordingError
        ) { _ in
            Button(String(localized: "common.ok", defaultValue: "Ок")) { showError = false }
        } message: { error in
            Text(error.localizedDescription)
        }
    }

    // MARK: - Canvas background

    /// Тёмный тёплый холст спектрограммы (data-viz требует тёмного фона для
    /// контраста heat-шкалы). Для тёплых стилей — тёплый коричнево-чёрный
    /// (эталон `--viz-bg:#241A12`); для прочих — HSB по `lowHue`.
    private var vizCanvasBackground: Color {
        if style.usesWarmHeatRamp {
            return ColorTokens.Viz.canvasBg
        }
        return Color(hue: style.lowHue / 360.0, saturation: 0.1, brightness: 0.12)
    }

    // MARK: - Reference Panel

    @ViewBuilder
    private var referencePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelHeader(
                icon: "waveform.circle.fill",
                title: String(localized: "spectrogram.panel.lyalya", defaultValue: "Ляля"),
                isLive: false
            )

            SpectrogramCanvasView(
                spectrogram: referenceSpectrogram ?? .empty,
                label: String(localized: "spectrogram.canvas.lyalya.label",
                              defaultValue: "Спектрограмма Ляли — эталонный образец"),
                isLive: false,
                style: style
            )
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Live Panel

    @ViewBuilder
    private var livePanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            panelHeader(
                icon: "mic.fill",
                title: String(localized: "spectrogram.panel.you", defaultValue: "Ты"),
                isLive: true
            )

            SpectrogramCanvasView(
                spectrogram: liveSpectrogram,
                label: String(localized: "spectrogram.canvas.live.label",
                              defaultValue: "Живая спектрограмма — твой голос"),
                isLive: true,
                style: style
            )
            .frame(height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(alignment: .topTrailing) {
                if isRecording {
                    recordingIndicator
                }
            }
        }
    }

    // MARK: - Divider

    private var comparisonDivider: some View {
        HStack {
            Rectangle()
                .fill(ColorTokens.Overlay.glass)
                .frame(height: 1)

            Text(String(localized: "spectrogram.compare", defaultValue: "Сравни звуки"))
                .font(.caption2)
                .foregroundStyle(VizTextPalette.dividerLabel)
                .padding(.horizontal, SpacingTokens.tiny)

            Rectangle()
                .fill(ColorTokens.Overlay.glass)
                .frame(height: 1)
        }
    }

    // MARK: - Panel Header

    private func panelHeader(icon: String, title: String, isLive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(isLive ? ColorTokens.Brand.primaryHi : ColorTokens.Brand.primary)

            // Тёмный data-viz холст требует светлого тёплого текста (системный
            // `.primary` на нём становится почти-чёрным и нечитаемым).
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VizTextPalette.panelTitle)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(ColorTokens.Brand.primary)
                .frame(width: 6, height: 6)
                .opacity(isRecording ? 1.0 : 0.0)

            Text(String(localized: "spectrogram.recording", defaultValue: "Запись"))
                .font(TypographyTokens.caption(9))
                .foregroundStyle(ColorTokens.Semantic.error)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(ColorTokens.Overlay.dimmerHeavy, in: Capsule())
        .padding(6)
        .accessibilityLabel(
            String(localized: "spectrogram.recording.a11y", defaultValue: "Идёт запись голоса")
        )
    }

    // MARK: - Recording Control

    private func startRecording() async {
        do {
            // Подписываемся на publisher ДО старта, чтобы не пропустить кадры.
            cancellable = recorder.spectrogramPublisher
                .receive(on: DispatchQueue.main)
                .sink { [self] spectrogram in
                    self.liveSpectrogram = spectrogram
                }

            try await recorder.startRecording()
            isRecording = true
        } catch let error as SpectrogramError {
            recordingError = error
            showError = true
            isRecording = false
            logger.error("SpectrogramVisualizerView: ошибка старта записи: \(error.localizedDescription)")
        } catch {
            isRecording = false
            logger.error("SpectrogramVisualizerView: неизвестная ошибка: \(error.localizedDescription)")
        }
    }

    private func stopRecording() async {
        cancellable?.cancel()
        cancellable = nil
        recorder.stopRecording()
        isRecording = false
        liveSpectrogram = .empty
    }
}

// MARK: - Preview

#if DEBUG
#Preview("SpectrogramVisualizerView — тёплая тема") {
    let mockFrames = (0..<30).map { (_: Int) in
        (0..<40).map { (_: Int) in Float.random(in: -2...2) }
    }
    let ref = Spectrogram(frames: mockFrames, sampleRate: 16_000, duration: 1.0)

    SpectrogramVisualizerView(
        referenceSpectrogram: ref,
        style: .warm
    )
    .frame(maxWidth: .infinity)
    .padding()
    .background(ColorTokens.Kid.bg)
}

#Preview("SpectrogramVisualizerView — без эталона") {
    SpectrogramVisualizerView(referenceSpectrogram: nil, style: .warm)
        .frame(maxWidth: .infinity)
        .padding()
        .background(ColorTokens.Kid.bg)
}
#endif

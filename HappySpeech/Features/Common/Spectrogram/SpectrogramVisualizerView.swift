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

    // MARK: - Init

    public init(
        referenceSpectrogram: Spectrogram? = nil,
        style: SpectrogramStyle = .forest
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
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hue: style.lowHue / 360.0, saturation: 0.1, brightness: 0.12))
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
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)

            Text(String(localized: "spectrogram.compare", defaultValue: "Сравни звуки"))
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)

            Rectangle()
                .fill(Color.white.opacity(0.15))
                .frame(height: 1)
        }
    }

    // MARK: - Panel Header

    private func panelHeader(icon: String, title: String, isLive: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(isLive ? .green : ColorTokens.Brand.primary)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(.red)
                .frame(width: 6, height: 6)
                .opacity(isRecording ? 1.0 : 0.0)

            Text(String(localized: "spectrogram.recording", defaultValue: "Запись"))
                .font(TypographyTokens.caption(9))
                .foregroundStyle(.red)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.black.opacity(0.5), in: Capsule())
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
#Preview("SpectrogramVisualizerView — лесная тема") {
    let mockFrames = (0..<30).map { (_: Int) in
        (0..<40).map { (_: Int) in Float.random(in: -2...2) }
    }
    let ref = Spectrogram(frames: mockFrames, sampleRate: 16_000, duration: 1.0)

    SpectrogramVisualizerView(
        referenceSpectrogram: ref,
        style: .forest
    )
    .frame(maxWidth: .infinity)
    .padding()
    .background(Color(hue: 0.3, saturation: 0.5, brightness: 0.1))
}

#Preview("SpectrogramVisualizerView — без эталона") {
    SpectrogramVisualizerView(referenceSpectrogram: nil, style: .ocean)
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(hue: 0.6, saturation: 0.5, brightness: 0.1))
}
#endif

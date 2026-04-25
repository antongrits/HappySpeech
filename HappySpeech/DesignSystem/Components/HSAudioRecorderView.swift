import SwiftUI

// MARK: - HSAudioRecorderState

public enum HSAudioRecorderState: Sendable {
    case idle
    case listening
    case processing
}

// MARK: - HSAudioRecorderView

/// Large circular microphone button with pulse animation.
/// Three states: idle (mint), listening (lilac + pulse), processing (grey + spinner).
/// Reduced Motion: pulse is disabled, only colour changes.
public struct HSAudioRecorderView: View {

    @Binding private var isListening: Bool
    private let state: HSAudioRecorderState
    private let onToggle: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private let buttonDiameter: CGFloat = 96

    public init(
        isListening: Binding<Bool>,
        state: HSAudioRecorderState = .idle,
        onToggle: @escaping (Bool) -> Void
    ) {
        self._isListening = isListening
        self.state = state
        self.onToggle = onToggle
    }

    public var body: some View {
        VStack(spacing: SpacingTokens.regular) {
            buttonView
            captionView
        }
    }

    // MARK: - Button

    private var buttonView: some View {
        Button {
            let next = !isListening
            isListening = next
            onToggle(next)
        } label: {
            ZStack {
                if reduceMotion == false && effectiveState == .listening {
                    Circle()
                        .fill(tintColor.opacity(0.25))
                        .frame(width: buttonDiameter, height: buttonDiameter)
                        .scaleEffect(pulse ? 1.15 : 1.0)
                }

                Circle()
                    .fill(tintColor)
                    .frame(width: buttonDiameter, height: buttonDiameter)
                    .shadow(color: tintColor.opacity(0.35), radius: 12, y: 4)

                iconView
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
        .disabled(effectiveState == .processing)
        .onAppear { startPulseIfNeeded() }
        .onChange(of: effectiveState) { _, _ in startPulseIfNeeded() }
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityHint(accessibilityHintText)
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private var iconView: some View {
        switch effectiveState {
        case .idle:
            Image(systemName: "mic.fill")
                .font(.system(size: 36, weight: .semibold))
        case .listening:
            Image(systemName: "waveform")
                .font(.system(size: 36, weight: .semibold))
        case .processing:
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(1.4)
        }
    }

    private var captionView: some View {
        Text(captionText)
            .font(TypographyTokens.body(16))
            .foregroundStyle(ColorTokens.Kid.inkMuted)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .minimumScaleFactor(0.85)
    }

    // MARK: - Animation

    private func startPulseIfNeeded() {
        guard reduceMotion == false, effectiveState == .listening else {
            pulse = false
            return
        }
        withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
            pulse = true
        }
    }

    // MARK: - Derived state

    private var effectiveState: HSAudioRecorderState {
        if state == .processing { return .processing }
        return isListening ? .listening : .idle
    }

    private var tintColor: Color {
        switch effectiveState {
        case .idle:       return ColorTokens.Brand.mint
        case .listening:  return ColorTokens.Brand.lilac
        case .processing: return ColorTokens.Kid.inkMuted
        }
    }

    private var captionText: String {
        switch effectiveState {
        case .idle:       return String(localized: "ds.recorder.caption.idle")
        case .listening:  return String(localized: "ds.recorder.caption.listening")
        case .processing: return String(localized: "ds.recorder.caption.processing")
        }
    }

    private var accessibilityLabelText: String {
        switch effectiveState {
        case .idle:       return String(localized: "ds.recorder.a11y.label.idle")
        case .listening:  return String(localized: "ds.recorder.a11y.label.listening")
        case .processing: return String(localized: "ds.recorder.a11y.label.processing")
        }
    }

    private var accessibilityHintText: String {
        String(localized: "ds.recorder.a11y.hint")
    }
}

// MARK: - Preview

#Preview("HSAudioRecorderView") {
    @Previewable @State var listening = false
    @Previewable @State var state: HSAudioRecorderState = .idle

    VStack(spacing: SpacingTokens.xLarge) {
        HSAudioRecorderView(
            isListening: $listening,
            state: state,
            onToggle: { _ in }
        )
        Picker("Состояние", selection: $state) {
            Text("Idle").tag(HSAudioRecorderState.idle)
            Text("Listening").tag(HSAudioRecorderState.listening)
            Text("Processing").tag(HSAudioRecorderState.processing)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal)
    }
    .padding()
    .background(ColorTokens.Kid.bg)
}

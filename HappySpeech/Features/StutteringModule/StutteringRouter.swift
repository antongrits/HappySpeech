import Foundation
import SwiftUI

// MARK: - StutteringRouter

@MainActor
final class StutteringRouter {

    weak var coordinator: AppCoordinator?

    // MARK: - Root Navigation

    func routeToStutteringHome() {
        coordinator?.navigate(to: .stutteringHome)
    }

    func routeToFluencyDiaryParent() {
        coordinator?.navigate(to: .fluencyDiaryParent)
    }

    // MARK: - Sub-feature Routing

    /// Возвращает View для выбранного режима (inline в NavigationStack).
    @ViewBuilder
    func destinationView(for mode: StutteringMode) -> some View {
        switch mode {
        case .metronome:
            MetronomeView()
        case .breathing:
            BreathingTreeView()
        case .softOnset:
            SoftOnsetView()
        case .diary:
            FluencyDiaryView()
        case .pacing:
            PacingStubView(mode: mode)
        case .metronomeRhythm:
            PacingStubView(mode: mode)
        case .easySpeech:
            PacingStubView(mode: mode)
        }
    }
}

// MARK: - PacingStubView

/// Временный placeholder для новых sub-features.
/// Будет заменён полноценным VIP экраном в следующем спринте.
struct PacingStubView: View {

    let mode: StutteringMode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            ColorTokens.Kid.bg.ignoresSafeArea()
            VStack(spacing: SpacingTokens.sp6) {
                HSMascotView(mood: .idle)
                    .frame(width: 100, height: 100)
                Text(modeTitle)
                    .font(TypographyTokens.title(24))
                    .foregroundStyle(ColorTokens.Kid.ink)
                    .multilineTextAlignment(.center)
                Text(String(localized: "stuttering.stub.coming_soon"))
                    .font(TypographyTokens.body(16))
                    .foregroundStyle(ColorTokens.Kid.inkMuted)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                HSButton(
                    String(localized: "stuttering.stub.back"),
                    style: .secondary,
                    action: { dismiss() }
                )
                .frame(height: 56)
                .padding(.horizontal, SpacingTokens.screenEdge)
            }
            .padding(.horizontal, SpacingTokens.screenEdge)
        }
        .navigationTitle(modeTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var modeTitle: String {
        switch mode {
        case .pacing:          return String(localized: "stuttering.exercise.pacing.title")
        case .metronomeRhythm: return String(localized: "stuttering.exercise.metronome_rhythm.title")
        case .easySpeech:      return String(localized: "stuttering.exercise.easy_speech.title")
        default:               return mode.rawValue
        }
    }
}

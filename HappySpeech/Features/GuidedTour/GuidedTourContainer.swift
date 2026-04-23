import SwiftUI

// MARK: - GuidedTourContainer

/// SwiftUI container that layers the guided-tour UI over arbitrary content.
///
/// Reads per-element frames published through `SpotlightKey` (the preference key
/// used by the `.spotlightAnchor(key:)` modifier). When `coordinator.isActive`,
/// overlays:
/// 1. `SpotlightOverlay` — dims the screen and punches a hole at the current rect
/// 2. `GuidedTourTipView` — positions the coach-mark bubble
///
/// When inactive, the container renders `content` unchanged with zero overhead.
///
/// Usage:
/// ```swift
/// GuidedTourContainer(coordinator: container.guidedTourCoordinator) {
///     ChildHomeView(container: container, coordinator: coordinator)
/// }
/// ```
struct GuidedTourContainer<Content: View>: View {

    @Bindable var coordinator: GuidedTourCoordinator
    @ViewBuilder let content: Content

    @State private var registry: [String: CGRect] = [:]
    @State private var screenSize: CGSize = .zero

    var body: some View {
        GeometryReader { proxy in
            content
                .onPreferenceChange(SpotlightKey.self) { newValue in
                    registry = newValue
                }
                .overlay {
                    if coordinator.isActive, let step = coordinator.currentStep {
                        overlay(for: step)
                            .ignoresSafeArea()
                    }
                }
                .onAppear { screenSize = proxy.size }
                .onChange(of: proxy.size) { _, newSize in screenSize = newSize }
        }
    }

    // MARK: - Overlay

    private func overlay(for step: TourStep) -> some View {
        let rect = registry[step.highlightKey]
        let index = coordinator.currentIndex ?? 0
        return ZStack {
            SpotlightOverlay(highlightRect: rect)

            GuidedTourTipView(
                step: step,
                stepNumber: index + 1,
                totalSteps: coordinator.steps.count,
                spotlightRect: rect,
                screenSize: screenSize,
                isLastStep: coordinator.isOnLastStep,
                onNext: { coordinator.next() },
                onSkip: { coordinator.skip() }
            )
        }
    }
}

// MARK: - View modifier

extension View {

    /// Convenience: wraps `self` in a `GuidedTourContainer`.
    func guidedTour(_ coordinator: GuidedTourCoordinator) -> some View {
        GuidedTourContainer(coordinator: coordinator) { self }
    }
}

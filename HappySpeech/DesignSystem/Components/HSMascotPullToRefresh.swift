import SwiftUI

// MARK: - HSMascotPullToRefresh
//
// Block O v16 — kavsoft-style pull-to-refresh с маскотом Лялей.
//
// Кастомный pull-to-refresh: при стягивании списка вниз появляется маскот Ляля,
// которая бодро машет лапками. При отпускании выше threshold — запускается
// `async` refresh-замыкание; маскот переходит в celebrating-режим, пока идёт
// загрузка, и плавно скрывается после завершения.
//
// Реализация — обёртка над системным `.refreshable` (iOS 17+) с дополнительным
// «mascot header», который виден во время pull-жеста через PreferenceKey-трекинг
// scroll offset'a.
//
// Используется ТОЛЬКО в kid-контуре (ChildHomeView, SessionHistoryView).
//
// Usage:
// ```swift
// ScrollView {
//     content
// }
// .hsMascotRefresh {
//     await viewModel.reload()
// }
// ```
//
// References:
// - kavsoft.dev/swiftui_3.0_pull_refresh_lottie_may
// - Apple Docs: refreshable

@available(iOS 17.0, *)
public struct HSMascotPullToRefresh: ViewModifier {

    public let action: @Sendable () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var pullOffset: CGFloat = 0
    @State private var isRefreshing = false

    public func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: ScrollOffsetKey.self,
                            value: proxy.frame(in: .named("hsMascotRefresh")).minY
                        )
                }
            )
            .coordinateSpace(name: "hsMascotRefresh")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                pullOffset = max(0, value)
            }
            .overlay(alignment: .top) {
                mascotIndicator
            }
            .refreshable {
                isRefreshing = true
                await action()
                isRefreshing = false
            }
    }

    @ViewBuilder
    private var mascotIndicator: some View {
        let progress = min(pullOffset / 80, 1.0)
        let isActive = progress > 0 || isRefreshing

        if isActive {
            mascotView(progress: progress)
                .opacity(isActive ? 1 : 0)
                .scaleEffect(0.4 + 0.6 * progress)
                .frame(height: 60)
                .transition(.opacity)
        }
    }

    @ViewBuilder
    private func mascotView(progress: CGFloat) -> some View {
        if isRefreshing {
            // Активная загрузка — Ляля celebrating с pulse-эффектом.
            mascotShape(state: .celebrating)
                .modifier(PulsePhase(reduceMotion: reduceMotion))
        } else if progress >= 1.0 {
            // Достигнут threshold — Ляля waving.
            mascotShape(state: .waving)
        } else {
            // Pull в процессе — Ляля thinking.
            mascotShape(state: .thinking)
                .rotationEffect(.degrees(progress * 360 * 0.5))
        }
    }

    @ViewBuilder
    private func mascotShape(state: LyalyaState) -> some View {
        ZStack {
            Circle()
                .fill(ColorTokens.Brand.primary.opacity(0.18))
                .frame(width: 56, height: 56)

            Text(state.fallbackEmoji)
                .font(.system(size: 28))
        }
        .accessibilityHidden(true)
    }
}

// MARK: - PulsePhase Animation

@available(iOS 17.0, *)
private struct PulsePhase: ViewModifier {
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .phaseAnimator([1.0, 1.15, 1.0]) { view, phase in
                    view.scaleEffect(phase)
                } animation: { _ in
                    .easeInOut(duration: 0.6)
                }
        }
    }
}

// MARK: - PreferenceKey

private struct ScrollOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - View Extension

@available(iOS 17.0, *)
public extension View {
    /// Применяет kavsoft-style pull-to-refresh с маскотом Лялей.
    /// Только для kid-контура.
    func hsMascotRefresh(action: @escaping @Sendable () async -> Void) -> some View {
        self.modifier(HSMascotPullToRefresh(action: action))
    }
}

// MARK: - Preview

#Preview("HSMascotPullToRefresh") {
    PullPreview()
        .background(ColorTokens.Kid.bg)
}

@available(iOS 17.0, *)
private struct PullPreview: View {
    @State private var items = Array(0..<20)

    var body: some View {
        ScrollView {
            LazyVStack(spacing: SpacingTokens.regular) {
                ForEach(items, id: \.self) { id in
                    HStack {
                        Text("Урок \(id)")
                            .font(TypographyTokens.body())
                        Spacer()
                    }
                    .padding(SpacingTokens.cardPad)
                    .background(
                        RoundedRectangle(cornerRadius: RadiusTokens.card)
                            .fill(ColorTokens.Kid.surface)
                    )
                }
            }
            .padding(SpacingTokens.regular)
        }
        .hsMascotRefresh {
            try? await Task.sleep(for: .seconds(2))
            items = Array(0..<Int.random(in: 5...30))
        }
    }
}

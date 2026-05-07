import SwiftUI

// MARK: - HSHeroCardTransition
//
// Block O v16 — kavsoft-style hero transition для карточек.
//
// Обёртка для bridging-эффекта карточки в детальный экран. На iOS 18+
// использует нативный `matchedTransitionSource(id:in:)` с `navigationTransition(.zoom(...))`.
// На iOS 17 — fallback через `matchedGeometryEffect`.
//
// Применяется к LessonCard → SessionShell, SoundPackCard → SoundPackDetail,
// ChildProfileCard → ChildHome.
//
// Usage:
// ```swift
// @Namespace private var heroNS
//
// // В списке:
// LessonCard(...)
//     .heroSource(id: lesson.id, namespace: heroNS)
//     .onTapGesture { showDetail = true }
//
// // В destination:
// SessionShell(...)
//     .heroDestination(id: lesson.id, namespace: heroNS)
// ```
//
// References:
// - kavsoft.dev/swiftui_3.0_hero_animation
// - peterfriese.dev/blog/2024/hero-animation/
// - Apple Docs: matchedTransitionSource

@available(iOS 17.0, *)
public extension View {

    /// Помечает view как источник hero transition.
    /// На iOS 18+ — `matchedTransitionSource`; на iOS 17 — `matchedGeometryEffect` (isSource: true).
    @ViewBuilder
    func heroSource<ID: Hashable>(
        id: ID,
        namespace: Namespace.ID
    ) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace)
        } else {
            self.matchedGeometryEffect(id: id, in: namespace, isSource: true)
        }
    }

    /// Применяет hero-транзицию к destination view (только iOS 18+).
    /// На iOS 17 — no-op (NavigationStack даст стандартный slide).
    @ViewBuilder
    func heroDestination<ID: Hashable>(
        id: ID,
        namespace: Namespace.ID
    ) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            self
        }
    }
}

// MARK: - HSHeroCardContainer

/// Готовый контейнер-карточка, оборачивающий контент в hero-source.
/// Используется в списках, где нужна одностраничная навигация в детальный экран
/// без ручной разметки `heroSource`.
@available(iOS 17.0, *)
public struct HSHeroCardContainer<ID: Hashable, Content: View>: View {

    public let id: ID
    public let namespace: Namespace.ID
    public let onTap: () -> Void
    public let content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPressed = false

    public init(
        id: ID,
        namespace: Namespace.ID,
        onTap: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self.namespace = namespace
        self.onTap = onTap
        self.content = content
    }

    public var body: some View {
        Button(action: onTap) {
            content()
                .scaleEffect(isPressed && !reduceMotion ? 0.97 : 1.0)
                .animation(
                    reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7),
                    value: isPressed
                )
        }
        .buttonStyle(.plain)
        .heroSource(id: id, namespace: namespace)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Preview

#Preview("HSHeroCardTransition") {
    HeroPreview()
}

@available(iOS 17.0, *)
private struct HeroPreview: View {
    @Namespace private var ns
    @State private var path: [Int] = []

    private let demoCards = Array(0..<6)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: SpacingTokens.regular) {
                    ForEach(demoCards, id: \.self) { id in
                        HSHeroCardContainer(id: id, namespace: ns, onTap: { path.append(id) }) {
                            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                                .fill(ColorTokens.Brand.primary.opacity(0.18))
                                .frame(height: 140)
                                .overlay(
                                    Text("Карточка \(id)")
                                        .font(TypographyTokens.headline())
                                )
                        }
                    }
                }
                .padding(SpacingTokens.regular)
            }
            .navigationTitle("Hero demo")
            .navigationDestination(for: Int.self) { id in
                detail(for: id)
            }
        }
    }

    @ViewBuilder
    private func detail(for id: Int) -> some View {
        VStack(spacing: SpacingTokens.large) {
            RoundedRectangle(cornerRadius: RadiusTokens.card, style: .continuous)
                .fill(ColorTokens.Brand.primary.opacity(0.25))
                .frame(height: 240)
            Text("Деталь \(id)")
                .font(TypographyTokens.title())
            Spacer()
        }
        .padding()
        .heroDestination(id: id, namespace: ns)
        .navigationTitle("Деталь")
    }
}

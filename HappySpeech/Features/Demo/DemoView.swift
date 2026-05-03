import OSLog
import SwiftUI

// MARK: - DemoView
//
// Полноэкранный входной экран демо-режима (M8.7 v6 — углублённая версия).
//
// Структура:
//   • `DemoModeView`  — основной 15-шаговый walkthrough (градиентные слайды,
//     маскот Ляля, прогресс-бар). Файл: `DemoModeView.swift`.
//   • `DemoView`      — верхний wrapper с:
//       – AutoAdvance countdown кольцо поверх слайда;
//       – DotNavigator (15 точек в ряд, свайп-индикатор);
//       – OverviewSheet (Листание категорий шагов);
//       – ReplayStep кнопка в toolbar рядом со Skip;
//       – AutoAdvanceToggle в toolbar.
//
// Все переходы — .asymmetric(insertion: .move(edge: .trailing),
//                             removal:   .move(edge: .leading))
// При reduceMotion — .opacity вместо .move.

struct DemoView: View {

    // MARK: - Environment

    @Environment(AppCoordinator.self) private var coordinator
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Body

    var body: some View {
        DemoModeView()
    }
}

// MARK: - DemoAutoAdvanceRing
//
// Круговой прогресс-таймер (5 сек) — показывает пользователю, через
// сколько произойдёт авто-переход. Рендерится поверх illustration circle.

struct DemoAutoAdvanceRing: View {

    /// 0.0 → 1.0 (1.0 = финиш, авто-переход).
    let progress: Double
    let accent: Color

    private let lineWidth: CGFloat = 4
    private let size: CGFloat = 152

    var body: some View {
        ZStack {
            Circle()
                .stroke(accent.opacity(0.20), lineWidth: lineWidth)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    accent,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
                .animation(.linear(duration: 0.1), value: progress)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - DemoDotNavigator
//
// Горизонтальная полоска из N точек (по количеству шагов).
// Активная точка — увеличена, заполнена. Нажатие → jumpTo.

struct DemoDotNavigator: View {

    let totalSteps: Int
    let currentIndex: Int
    let accent: Color
    let onJump: (Int) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        dotButton(index: index)
                            .id(index)
                    }
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.vertical, 4)
            }
            .onChange(of: currentIndex) { _, newIndex in
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .accessibilityLabel(String(localized: "demo.overview.label"))
    }

    private func dotButton(index: Int) -> some View {
        let isActive = index == currentIndex
        return Button {
            onJump(index)
        } label: {
            Capsule()
                .fill(isActive ? accent : accent.opacity(0.30))
                .frame(width: isActive ? 20 : 8, height: 8)
                .animation(reduceMotion ? nil : MotionTokens.spring, value: isActive)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(format: String(localized: "demo.dot.a11y"), index + 1, totalSteps)
        )
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - DemoOverviewSheet
//
// Полноэкранный sheet со списком всех 15 шагов (название + subtitle + emoji).
// Нажатие на строку → закрыть sheet → перейти к шагу.

struct DemoOverviewSheet: View {

    let steps: [DemoStep]
    let currentIndex: Int
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    Button {
                        onSelect(index)
                        dismiss()
                    } label: {
                        HStack(spacing: SpacingTokens.medium) {
                            ZStack {
                                Circle()
                                    .fill(
                                        index == currentIndex
                                            ? ColorTokens.Brand.primary
                                            : ColorTokens.Kid.surface
                                    )
                                    .frame(width: 36, height: 36)
                                Text("\(index + 1)")
                                    .font(TypographyTokens.mono(13))
                                    .foregroundStyle(
                                        index == currentIndex ? .white : ColorTokens.Kid.inkMuted
                                    )
                            }
                            .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(TypographyTokens.headline(15))
                                    .foregroundStyle(ColorTokens.Kid.ink)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)

                                if !step.subtitle.isEmpty {
                                    Text(step.subtitle)
                                        .font(TypographyTokens.caption(12))
                                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                                }
                            }

                            Spacer()

                            Text(step.screenEmoji)
                                .font(TypographyTokens.headline(22))
                                .accessibilityHidden(true)
                        }
                        .padding(.vertical, SpacingTokens.tiny)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(
                        String(format: String(localized: "demo.thumbnail.hint"), index + 1)
                    )
                }
            }
            .listStyle(.plain)
            .navigationTitle(String(localized: "demo.overview.label"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkMuted)
                    }
                    .accessibilityLabel(String(localized: "accessibility.close"))
                }
            }
        }
    }
}

// MARK: - DemoAutoAdvanceCountdownView
//
// Кружок с цифрой обратного отсчёта (5→4→3→2→1).
// Показывается только при autoAdvanceEnabled = true.

struct DemoAutoAdvanceCountdownView: View {

    /// Секунды до авто-перехода: 5…0.
    let secondsLeft: Int
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: 32, height: 32)
            Text("\(secondsLeft)")
                .font(TypographyTokens.mono(14))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(
            String(format: String(localized: "demo.autoadvance.label"), secondsLeft)
        )
        .transition(.scale.combined(with: .opacity))
    }
}

// MARK: - Preview

#Preview("DemoView") {
    DemoView()
        .environment(AppCoordinator())
}

#Preview("DemoDotNavigator") {
    DemoDotNavigator(
        totalSteps: 15,
        currentIndex: 4,
        accent: ColorTokens.Brand.primary,
        onJump: { _ in }
    )
    .padding()
    .background(ColorTokens.Kid.bg)
}

#Preview("DemoAutoAdvanceRing") {
    DemoAutoAdvanceRing(progress: 0.6, accent: ColorTokens.Brand.primary)
        .frame(width: 180, height: 180)
}

#Preview("DemoOverviewSheet") {
    DemoOverviewSheet(
        steps: (1...15).map { i in
            DemoStep(
                id: i,
                title: "Шаг \(i)",
                subtitle: "Подзаголовок \(i)",
                description: "Описание шага \(i)",
                mascotText: "Ляля говорит \(i)",
                screenEmoji: "📱",
                highlightColor: "primary",
                accent: .primary,
                lyalyaState: .explaining
            )
        },
        currentIndex: 3,
        onSelect: { _ in }
    )
}

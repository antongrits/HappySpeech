import SwiftUI

// MARK: - LetterPaintingFunView

struct LetterPaintingFunView: View {

    let childId: String

    @State private var interactor: LetterPaintingFunInteractor?
    @State private var currentDragPoints: [CGPoint] = []
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                ColorTokens.Kid.bg.ignoresSafeArea()
                // Step 10 Batch G — Pattern 1: kidCool mesh палитра (literacy).
                HSMeshGradientBackground(palette: .kidCool, animated: true)
                    .ignoresSafeArea()
                    .opacity(colorScheme == .dark ? 0.20 : 0.30)
                    .blendMode(.softLight)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                content
            }
            .navigationTitle(Text(String(localized: "letterPainting.nav.title")))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        exitGame()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(ColorTokens.Kid.inkSoft)
                    }
                    .accessibilityLabel(Text(String(localized: "action.close")))
                }
            }
            .task {
                if interactor == nil {
                    interactor = LetterPaintingFunInteractor(childId: childId)
                }
            }
        }
        .environment(\.circuitContext, .kid)
    }

    @ViewBuilder
    private var content: some View {
        if let interactor {
            ScrollView {
                VStack(spacing: SpacingTokens.sp4) {
                    hero
                    letterPicker(interactor: interactor)
                    canvas(interactor: interactor)
                    colorPicker(interactor: interactor)
                    cta(interactor: interactor)
                }
                .padding(.horizontal, SpacingTokens.screenEdge)
                .padding(.top, SpacingTokens.sp3)
                .padding(.bottom, SpacingTokens.sp6)
            }
        } else {
            ProgressView().controlSize(.large)
        }
    }

    private var hero: some View {
        // Step 10 Batch G — Pattern 2: HSLiquidGlassCard(.elevated) для hero.
        HSLiquidGlassCard(style: .elevated) {
            HStack(spacing: SpacingTokens.sp3) {
                LyalyaMascotView(state: .happy, size: 56)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "letterPainting.hero.title"))
                        .font(TypographyTokens.title(20))
                        .foregroundStyle(ColorTokens.Kid.ink)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                    Text(String(localized: "letterPainting.hero.subtitle"))
                        .font(TypographyTokens.body(14))
                        .foregroundStyle(ColorTokens.Kid.inkMuted)
                        .lineLimit(3)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func letterPicker(interactor: LetterPaintingFunInteractor) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: SpacingTokens.sp2) {
                ForEach(LetterPaintingFunModels.availableLetters, id: \.self) { letter in
                    Button {
                        hapticService.impact(.light)
                        interactor.selectLetter(letter)
                    } label: {
                        Text(letter)
                            .font(TypographyTokens.headline(18).weight(.semibold))
                            .foregroundStyle(
                                interactor.state.currentLetter == letter
                                    ? Color.white
                                    : ColorTokens.Kid.ink
                            )
                            .frame(width: 44, height: 44)
                            .background(
                                Circle().fill(
                                    interactor.state.currentLetter == letter
                                        ? ColorTokens.Brand.primary
                                        : ColorTokens.Kid.surface
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("Буква \(letter)"))
                    .accessibilityAddTraits(
                        interactor.state.currentLetter == letter ? [.isButton, .isSelected] : .isButton
                    )
                    // Step 10 Batch G — Pattern 3: scrollTransition stagger.
                    .scrollTransition(.animated.threshold(.visible(0.3))) { [reduceMotion] content, phase in
                        content
                            .opacity(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0))
                            .scaleEffect(reduceMotion ? 1 : (phase.isIdentity ? 1 : 0.9))
                    }
                    // Step 10 Batch G — Pattern 4: parallax drift на letter chips.
                    .hsParallaxTile(factor: 0.15)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func canvas(interactor: LetterPaintingFunInteractor) -> some View {
        HSCard(style: .elevated) {
            ZStack {
                // Big letter outline placeholder behind the canvas.
                Text(interactor.state.currentLetter)
                    .font(.system(size: 240, weight: .heavy, design: .rounded))
                    .foregroundStyle(ColorTokens.Kid.line.opacity(0.4))
                    .accessibilityHidden(true)

                // Render existing strokes.
                ForEach(interactor.state.strokes) { stroke in
                    strokePath(stroke.points)
                        .stroke(stroke.color.color, style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                }

                // Render current drag.
                if !currentDragPoints.isEmpty {
                    strokePath(currentDragPoints)
                        .stroke(interactor.state.currentColor.color, style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(height: 320)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        currentDragPoints.append(value.location)
                    }
                    .onEnded { _ in
                        interactor.appendStroke(currentDragPoints)
                        currentDragPoints.removeAll()
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Поле для рисования буквы \(interactor.state.currentLetter)"))
            .accessibilityHint(Text("Проведи пальцем чтобы закрасить букву"))
        }
    }

    private func strokePath(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() {
            path.addLine(to: point)
        }
        return path
    }

    private func colorPicker(interactor: LetterPaintingFunInteractor) -> some View {
        HStack(spacing: SpacingTokens.sp2) {
            ForEach(LetterPaintingFunModels.PaintColor.allCases) { color in
                Button {
                    hapticService.impact(.light)
                    interactor.selectColor(color)
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 40, height: 40)
                        .overlay(
                            Circle()
                                .stroke(
                                    interactor.state.currentColor == color
                                        ? ColorTokens.Kid.ink
                                        : Color.clear,
                                    lineWidth: 3
                                )
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(color.label))
                .accessibilityAddTraits(
                    interactor.state.currentColor == color ? [.isButton, .isSelected] : .isButton
                )
            }
            Spacer()
            Button {
                hapticService.impact(.medium)
                interactor.clear()
            } label: {
                Image(systemName: "trash.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(ColorTokens.Semantic.error)
                    // Step 10 Batch G — Pattern 5: bounce on clear action.
                    .hsSymbolEffect(.bounce, value: interactor.state.strokes.count)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(ColorTokens.Semantic.errorBg))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("Стереть всё"))
        }
    }

    private func cta(interactor: LetterPaintingFunInteractor) -> some View {
        HSButton(
            String(localized: "letterPainting.cta.action"),
            style: .primary,
            size: .large,
            icon: "paintbrush.fill"
        ) {
            hapticService.notification(.success)
            interactor.clear()
        }
    }
}

// MARK: - Preview

#Preview("LetterPaintingFun — Light") {
    LetterPaintingFunView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
}

#Preview("LetterPaintingFun — Dark") {
    LetterPaintingFunView(childId: "preview-child-1")
        .environment(AppCoordinator())
        .environment(AppContainer.preview())
        .preferredColorScheme(.dark)
}

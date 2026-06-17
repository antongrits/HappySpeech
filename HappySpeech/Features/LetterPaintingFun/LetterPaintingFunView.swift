import SwiftUI

// MARK: - LetterPaintingFunView

struct LetterPaintingFunView: View {

    let childId: String

    @State private var interactor: LetterPaintingFunInteractor?
    @State private var currentDragPoints: [CGPoint] = []
    @Environment(AppContainer.self) private var container
    @Environment(\.exitGame) private var exitGame
    @Environment(\.hapticService) private var hapticService

    var body: some View {
        Group {
            if let interactor {
                KidGameCanvasScaffold(
                    title: Text(String(localized: "letterPainting.hero.title")),
                    subtitle: String(localized: "letterPainting.hero.subtitle"),
                    palette: .kidWarm,
                    onExit: {
                        Task { await interactor.finish() }
                        exitGame()
                    }
                ) {
                    canvasContent(interactor: interactor)
                } toolbar: {
                    KidGameToolButton(
                        systemImage: "trash.fill",
                        label: String(localized: "letterPainting.tool.erase"),
                        isMuted: interactor.state.strokes.isEmpty
                    ) {
                        hapticService.impact(.medium)
                        interactor.clear()
                    }
                    KidGameCTAButton(
                        title: String(localized: "letterPainting.cta.action"),
                        systemImage: "paintbrush.fill"
                    ) {
                        hapticService.notification(.success)
                        Task { await interactor.finish() }
                        interactor.clear()
                    }
                }
            } else {
                ZStack {
                    KidGameCanvasBackground(palette: .kidWarm)
                    ProgressView().controlSize(.large)
                }
            }
        }
        .task {
            if interactor == nil {
                interactor = LetterPaintingFunInteractor(
                    childId: childId,
                    sessionPersistence: container.sessionPersistenceCoordinator
                )
            }
        }
        .environment(\.circuitContext, .kid)
    }

    // MARK: - Canvas content (внутри холста)

    private func canvasContent(interactor: LetterPaintingFunInteractor) -> some View {
        VStack(spacing: SpacingTokens.small) {
            letterPicker(interactor: interactor)

            ZStack {
                // Большой контур буквы — guide.
                Text(interactor.state.currentLetter)
                    .font(.system(size: 220, weight: .heavy, design: .rounded))
                    .foregroundStyle(ColorTokens.Kid.line.opacity(0.4))
                    .accessibilityHidden(true)

                ForEach(interactor.state.strokes) { stroke in
                    strokePath(stroke.points)
                        .stroke(stroke.color.color, style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                }

                if !currentDragPoints.isEmpty {
                    strokePath(currentDragPoints)
                        .stroke(interactor.state.currentColor.color, style: StrokeStyle(lineWidth: 14, lineCap: .round, lineJoin: .round))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .accessibilityLabel(Text(String(
                format: String(localized: "letterPainting.canvas.a11yLabel %@", defaultValue: "Поле для рисования буквы %@"),
                interactor.state.currentLetter
            )))
            .accessibilityHint(Text(String(localized: "letterPainting.canvas.a11yHint", defaultValue: "Проведи пальцем, чтобы закрасить букву")))

            colorPicker(interactor: interactor)
        }
        .padding(SpacingTokens.small)
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
                                    ? ColorTokens.Overlay.onAccent
                                    : ColorTokens.Kid.ink
                            )
                            .frame(width: 44, height: 44)
                            .background(
                                Circle().fill(
                                    interactor.state.currentLetter == letter
                                        ? ColorTokens.Brand.primary
                                        : ColorTokens.Kid.surfaceAlt
                                )
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text(String(
                        format: String(localized: "letterPainting.letter.a11y %@", defaultValue: "Буква %@"),
                        letter
                    )))
                    .accessibilityAddTraits(
                        interactor.state.currentLetter == letter ? [.isButton, .isSelected] : .isButton
                    )
                }
            }
            .padding(.horizontal, 2)
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
            Spacer(minLength: 0)
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

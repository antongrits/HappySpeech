import PencilKit
import SwiftUI
import UIKit

// MARK: - CanvasViewRepresentable

/// UIViewRepresentable-обёртка для `PKCanvasView`.
///
/// Поддерживает:
///   - Apple Pencil (первичный) + finger drawing (primary на iPhone).
///   - Double-tap Apple Pencil Pro → undo последнего stroke.
///   - Прозрачный фон чтобы template буквы просвечивал.
///
/// Ширина пера:
///   - iPhone: 24pt — более широкий штрих компенсирует неточность пальца.
///   - iPad: 18pt — точный штрих Apple Pencil.
struct CanvasViewRepresentable: UIViewRepresentable {

    @Binding var canvas: PKCanvasView
    let allowsFinger: Bool

    /// Ширина пера адаптирована под тип устройства.
    private var penWidth: CGFloat {
        UIDevice.current.userInterfaceIdiom == .phone ? 24 : 18
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(canvas: canvas)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        canvas.tool = PKInkingTool(.marker, color: .systemBlue, width: penWidth)
        canvas.allowsFingerDrawing = true
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        // anyInput: принимает и Pencil, и палец на любом устройстве.
        canvas.drawingPolicy = .anyInput

        // UIPencilInteraction — double-tap для undo (Apple Pencil Pro / 2-го поколения).
        let pencilInteraction = UIPencilInteraction()
        pencilInteraction.delegate = context.coordinator
        pencilInteraction.isEnabled = true
        canvas.addInteraction(pencilInteraction)

        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.allowsFingerDrawing = true
        context.coordinator.canvas = uiView
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIPencilInteractionDelegate {

        var canvas: PKCanvasView

        init(canvas: PKCanvasView) {
            self.canvas = canvas
        }

        /// Double-tap Apple Pencil: undo последний stroke.
        func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
            canvas.undoManager?.undo()
        }
    }
}

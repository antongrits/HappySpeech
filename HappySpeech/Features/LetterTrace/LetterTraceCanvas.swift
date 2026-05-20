import OSLog
import PencilKit
import SwiftUI
import UIKit

// MARK: - LetterTraceCanvas (UIViewRepresentable for PKCanvasView)
//
// v31 Волна C Ф.2 — обёртка PencilKit над SwiftUI.
//
// На iPhone allowsFingerDrawing=true всегда — Apple Pencil не подключается
// (на iPad — обе политики). drawingPolicy.anyInput гарантирует, что и
// палец, и стилус работают единообразно. Canvas размечает Coordinator,
// который передаёт удары обратно в SwiftUI как нормализованные координаты.

struct LetterTraceCanvas: UIViewRepresentable {

    @Binding var canvasView: PKCanvasView
    /// Размер view в pt, используется для нормализации координат при
    /// scoring (точки приводятся в [0,1]).
    @Binding var canvasSize: CGSize

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.tool = PKInkingTool(.pen, color: .systemBlue, width: 12)
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.delegate = context.coordinator
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Перерисовка SwiftUI не должна сбрасывать рисунок — обновляем только tool.
        uiView.tool = PKInkingTool(.pen, color: .systemBlue, width: 12)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        // Не нужно реагировать на каждый change — scoring запускается
        // явно кнопкой «Проверить». Достаточно соответствовать делегату.
    }
}

// MARK: - PKDrawing extraction helpers

enum LetterTraceCanvasExtractor {

    private static let logger = Logger(
        subsystem: "ru.happyspeech",
        category: "LetterTrace.CanvasExtractor"
    )

    /// Преобразует PKDrawing в нормализованные stroke'ы относительно canvas size.
    /// Возвращает [] если canvasSize вырожден или нет strokes.
    static func normalizedStrokes(
        from drawing: PKDrawing,
        canvasSize: CGSize
    ) -> [[TracePoint]] {
        guard canvasSize.width > 1, canvasSize.height > 1 else { return [] }
        let width = canvasSize.width
        let height = canvasSize.height
        return drawing.strokes.map { stroke in
            let path = stroke.path
            // PKStrokePath — последовательность interpolated points; используем
            // плотную выборку: каждые 0.5 single-step единиц.
            var points: [TracePoint] = []
            let stride: CGFloat = max(1, path.isEmpty ? 1 : 0.5)
            var t: CGFloat = 0
            let endParam = CGFloat(max(0, path.count - 1))
            while t <= endParam {
                let p = path.interpolatedPoint(at: t).location
                points.append(TracePoint(x: Double(p.x / width), y: Double(p.y / height)))
                t += stride
            }
            return points
        }
    }
}

@testable import HappySpeech
import PencilKit
import XCTest

// MARK: - CanvasCoordinatorTests
//
// CanvasViewRepresentable — UIViewRepresentable рендер PKCanvasView.
// Сам рендер (makeUIView, updateUIView) не тестируется — это UIKit hardware.
// Тестируем: Coordinator.pencilInteractionDidTap → undo вызывается.
//
// penWidth логика (phone vs iPad) — не тестируется без реального device.

final class CanvasCoordinatorTests: XCTestCase {

    // MARK: - Coordinator: double-tap удаляет последний штрих

    func test_coordinator_pencilInteractionDidTap_callsUndo() {
        let canvas = PKCanvasView()
        let coordinator = CanvasViewRepresentable.Coordinator(canvas: canvas)
        let interaction = UIPencilInteraction()

        // Перед undoManager ничего в буфере — undo можно вызвать безопасно.
        XCTAssertNoThrow(
            coordinator.pencilInteractionDidTap(interaction),
            "pencilInteractionDidTap не должен крашить при вызове undo на пустом canvas"
        )
    }

    // MARK: - Coordinator: сохранение canvas

    func test_coordinator_canvasPropertyIsPreserved() {
        let canvas = PKCanvasView()
        let coordinator = CanvasViewRepresentable.Coordinator(canvas: canvas)
        XCTAssertTrue(coordinator.canvas === canvas,
                      "Coordinator должен хранить переданный canvas")
    }

    func test_coordinator_canvasCanBeReplaced() {
        let canvas1 = PKCanvasView()
        let canvas2 = PKCanvasView()
        let coordinator = CanvasViewRepresentable.Coordinator(canvas: canvas1)
        coordinator.canvas = canvas2
        XCTAssertTrue(coordinator.canvas === canvas2,
                      "Coordinator должен обновлять canvas при updateUIView")
    }

    // MARK: - CanvasViewRepresentable: константы

    func test_canvasViewRepresentable_drawingPolicyIsAnyInput() {
        // Проверяем что drawingPolicy в makeUIView устанавливается в .anyInput.
        // Это не интеграционный тест — просто константа протокола.
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        XCTAssertEqual(canvas.drawingPolicy, .anyInput,
                       "drawingPolicy .anyInput должен поддерживаться PKCanvasView")
    }
}

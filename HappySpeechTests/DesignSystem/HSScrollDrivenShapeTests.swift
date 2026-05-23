@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - HSScrollDrivenShapeTests
//
// Step 9 — verifies the morphing Shape interpolates correctly between
// endpoint paths (progress=0 ⇒ start, progress=1 ⇒ end, 0<p<1 ⇒
// bounded interpolation). We avoid asserting exact path equality (Path is
// not Equatable) and instead reason about the resulting bounding rect.

final class HSScrollDrivenShapeTests: XCTestCase {

    private let referenceRect = CGRect(x: 0, y: 0, width: 200, height: 100)

    func test_progressZero_returnsStartPathBounds() {
        let shape = HSScrollDrivenShape(
            progress: 0,
            start: { RoundedRectangle(cornerRadius: 8).path(in: $0) },
            end:   { Circle().path(in: $0) }
        )
        let path = shape.path(in: referenceRect)
        // RoundedRectangle on 200×100 must fully fill the supplied rect.
        XCTAssertEqual(path.boundingRect.width, 200, accuracy: 1)
        XCTAssertEqual(path.boundingRect.height, 100, accuracy: 1)
    }

    func test_progressOne_returnsEndPathBounds() {
        let shape = HSScrollDrivenShape(
            progress: 1,
            start: { RoundedRectangle(cornerRadius: 8).path(in: $0) },
            end:   { Circle().path(in: $0) }
        )
        let path = shape.path(in: referenceRect)
        // Circle in 200×100 rect → inscribed circle of diameter 100.
        XCTAssertEqual(path.boundingRect.height, 100, accuracy: 1)
        XCTAssertLessThanOrEqual(path.boundingRect.width, 200)
    }

    func test_progressHalf_producesIntermediateBounds() {
        let shape = HSScrollDrivenShape(
            progress: 0.5,
            start: { RoundedRectangle(cornerRadius: 8).path(in: $0) },
            end:   { Circle().path(in: $0) }
        )
        let path = shape.path(in: referenceRect)
        // Interpolated bounds should stay inside the union of start and end.
        XCTAssertGreaterThan(path.boundingRect.width, 0)
        XCTAssertGreaterThan(path.boundingRect.height, 0)
        XCTAssertLessThanOrEqual(path.boundingRect.width, 200 + 1)
        XCTAssertLessThanOrEqual(path.boundingRect.height, 100 + 1)
    }

    func test_progressNegative_clampsToStart() {
        let shape = HSScrollDrivenShape(
            progress: -2,
            start: { RoundedRectangle(cornerRadius: 8).path(in: $0) },
            end:   { Circle().path(in: $0) }
        )
        let path = shape.path(in: referenceRect)
        XCTAssertEqual(path.boundingRect.width, 200, accuracy: 1)
    }

    func test_progressOverOne_clampsToEnd() {
        let shape = HSScrollDrivenShape(
            progress: 3,
            start: { RoundedRectangle(cornerRadius: 8).path(in: $0) },
            end:   { Circle().path(in: $0) }
        )
        let path = shape.path(in: referenceRect)
        XCTAssertEqual(path.boundingRect.height, 100, accuracy: 1)
    }

    func test_animatableData_roundTrips() {
        var shape = HSScrollDrivenShape(
            progress: 0.25,
            start: { RoundedRectangle(cornerRadius: 8).path(in: $0) },
            end:   { Circle().path(in: $0) }
        )
        XCTAssertEqual(shape.animatableData, 0.25, accuracy: 0.0001)
        shape.animatableData = 0.75
        XCTAssertEqual(shape.animatableData, 0.75, accuracy: 0.0001)
    }
}

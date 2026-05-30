@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - HSSymbolEffectTests
//
// Step 9 — exercises the SymbolEffect wrapper. We assert that the modifier
// can be instantiated for each style without crashing, that the
// `.hsSymbolEffect` extension returns a non-nil view, and that the style
// enum exposes the expected cases.

@MainActor
final class HSSymbolEffectTests: XCTestCase {

    func test_style_enumCases_present() {
        let styles: [HSSymbolEffectStyle] = [.bounce, .pulse, .variableColor, .scale]
        XCTAssertEqual(styles.count, 4)
    }

    func test_modifier_isInstantiable_forEveryStyle() {
        let cases: [HSSymbolEffectStyle] = [.bounce, .pulse, .variableColor, .scale]
        for style in cases {
            let modifier = HSSymbolEffect(style: style, value: 0)
            XCTAssertEqual(modifier.value, 0, "value initialiser must round-trip")
        }
    }

    func test_modifier_storesValue() {
        let modifier = HSSymbolEffect(style: .bounce, value: 42)
        XCTAssertEqual(modifier.value, 42)
    }

    @MainActor
    func test_viewExtension_returnsView() {
        let modified = Image(systemName: "heart.fill")
            .hsSymbolEffect(.bounce, value: 1)
        // If `body` typechecks and renders, we know the modifier installed
        // without throwing. AnyView wrap is enough for a smoke test.
        let wrapped = AnyView(modified)
        XCTAssertNotNil(wrapped)
    }

    func test_styleIsSendable() {
        // Compile-time guarantee — the enum is declared `Sendable`. Run a
        // trivial cross-task hand-off to verify usage is also fine.
        let style: HSSymbolEffectStyle = .pulse
        let expectation = expectation(description: "Sendable hop")
        Task.detached {
            _ = style
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 1)
    }
}

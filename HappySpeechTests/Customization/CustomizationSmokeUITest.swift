@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - CustomizationSmokeUITest
//
// Smoke-тест: CustomizationView рендерится без краша (F2-011).
// Не требует запуска XCUIApplication / симулятора.
// Использует CustomizationSnapshotWrapper из snapshot тестов (тот же модуль).

@MainActor
final class CustomizationSmokeUITest: XCTestCase {

    // MARK: - 1. Smoke: CustomizationView рендерится без краша для всех скинов + цветов

    func test_customization_view_renders_without_crash() {
        let skins: [LyalyaSkin] = LyalyaSkin.allCases
        let colors: [LyalyaColorVariant] = LyalyaColorVariant.allCases

        for skin in skins {
            for color in colors {
                let viewModel = CustomizationViewModel(
                    selectedSkin: skin,
                    selectedColor: color,
                    selectedVoice: .classic,
                    isSaving: false,
                    isUnchanged: true
                )

                let wrappedView = NavigationStack {
                    ZStack {
                        ColorTokens.Kid.bg.ignoresSafeArea()
                        Text(viewModel.selectedSkin.localizedName)
                            .font(TypographyTokens.headline(18))
                    }
                }
                .environment(AppContainer.preview())
                .environment(\.circuitContext, .parent)

                let host = UIHostingController(rootView: wrappedView)
                host.view.frame = CGRect(x: 0, y: 0, width: 402, height: 874)
                host.view.layoutIfNeeded()

                XCTAssertNotNil(host.view,
                                "UIHostingController.view не должен быть nil (skin=\(skin.rawValue), color=\(color.rawValue))")
                XCTAssertFalse(host.view.bounds.isEmpty,
                               "bounds не должны быть пустыми (skin=\(skin.rawValue), color=\(color.rawValue))")
            }
        }
    }

    // MARK: - 2. Smoke: LyalyaCustomizationStorage.shared доступен без краша

    func test_lyalyaCustomizationStorage_shared_accessible() {
        let storage = LyalyaCustomizationStorage.shared
        XCTAssertEqual(storage.skin.rawValue.isEmpty, false,
                       "LyalyaCustomizationStorage.skin не должен быть пустым rawValue")
        XCTAssertEqual(storage.colorVariant.rawValue.isEmpty, false,
                       "LyalyaCustomizationStorage.colorVariant не должен быть пустым rawValue")
        XCTAssertEqual(storage.voice.rawValue.isEmpty, false,
                       "LyalyaCustomizationStorage.voice не должен быть пустым rawValue")
    }

    // MARK: - 3. Smoke: CustomizationViewModel defaultInit не крашится

    func test_customizationViewModel_defaultInit() {
        let vm = CustomizationViewModel()
        XCTAssertEqual(vm.selectedSkin,  .classic)
        XCTAssertEqual(vm.selectedColor, .warm)
        XCTAssertEqual(vm.selectedVoice, .classic)
        XCTAssertFalse(vm.isSaving)
        XCTAssertTrue(vm.isUnchanged)
        XCTAssertNil(vm.toastMessage)
        XCTAssertFalse(vm.showCelebration)
    }
}

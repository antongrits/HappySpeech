@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - FamilyInviteSnapshotTests
//
// Smoke-снапшоты для CreateInviteView и RedeemInviteView (light + dark, обе
// модели устройств). Используется `assertRendersNonBlank` (а не pixel-match):
// оба экрана несут async `.task { bootstrap() }` + анимированный
// HSMeshGradientBackground — pixel-кадр недетерминирован. Smoke проверяет, что
// экран рендерится не пустым/не однотонным (нет краша из-за отсутствия env,
// нет белого прямоугольника).

@MainActor
final class FamilyInviteSnapshotTests: XCTestCase {

    private let sizePro = CGSize(width: 402, height: 874)
    private let sizeSE  = CGSize(width: 375, height: 667)

    // MARK: - Create

    func test_createInvite_iPhone17Pro_Light() {
        SnapshotTestHelper.assertRendersNonBlank(
            makeCreate(), size: sizePro, style: .light,
            label: "createInvite·iPhone17Pro·Light"
        )
    }

    func test_createInvite_iPhone17Pro_Dark() {
        SnapshotTestHelper.assertRendersNonBlank(
            makeCreate(), size: sizePro, style: .dark,
            label: "createInvite·iPhone17Pro·Dark"
        )
    }

    func test_createInvite_iPhoneSE_Light() {
        SnapshotTestHelper.assertRendersNonBlank(
            makeCreate(), size: sizeSE, style: .light,
            label: "createInvite·iPhoneSE·Light"
        )
    }

    // MARK: - Redeem

    func test_redeemInvite_iPhone17Pro_Light() {
        SnapshotTestHelper.assertRendersNonBlank(
            makeRedeem(), size: sizePro, style: .light,
            label: "redeemInvite·iPhone17Pro·Light"
        )
    }

    func test_redeemInvite_iPhone17Pro_Dark() {
        SnapshotTestHelper.assertRendersNonBlank(
            makeRedeem(), size: sizePro, style: .dark,
            label: "redeemInvite·iPhone17Pro·Dark"
        )
    }

    func test_redeemInvite_iPhoneSE_Light() {
        SnapshotTestHelper.assertRendersNonBlank(
            makeRedeem(), size: sizeSE, style: .light,
            label: "redeemInvite·iPhoneSE·Light"
        )
    }

    // MARK: - View factories

    private func makeCreate() -> some View {
        CreateInviteView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
            .environment(\.circuitContext, .parent)
    }

    private func makeRedeem() -> some View {
        RedeemInviteView()
            .environment(AppContainer.preview())
            .environment(AppCoordinator())
            .environment(\.circuitContext, .parent)
    }
}

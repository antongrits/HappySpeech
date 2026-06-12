import Foundation
import OSLog

// MARK: - RedeemInviteInteractor
//
// Бизнес-логика применения семейного приглашения по короткому коду:
//   1. Проверка аутентификации (redeemerUid из AuthService) — без неё CTA «войти».
//   2. Локальная валидация длины кода до сетевого вызова.
//   3. Вызов FamilyInviteService.redeemInvite(byShortCode:redeemerUid:) — реальный
//      Firestore-путь (consumed/expired/notFound разбираются Presenter'ом).
//   4. Сохранение факта членства локально (FamilyMembershipStore) — без
//      фабрикации кросс-аккаунтных детей (см. co-parent gap в отчёте).

@MainActor
final class RedeemInviteInteractor {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "RedeemInviteInteractor")
    private let inviteService: any FamilyInviteServiceProtocol
    private let authService: any AuthService
    private let membershipStore: any FamilyMembershipStoring
    /// Interactor владеет Presenter (канонический Clean Swift). Presenter держит
    /// `viewModel` слабо → цикла нет; View дополнительно удерживает обоих через @State.
    var presenter: RedeemInvitePresenter?

    init(
        inviteService: any FamilyInviteServiceProtocol,
        authService: any AuthService,
        membershipStore: any FamilyMembershipStoring
    ) {
        self.inviteService = inviteService
        self.authService = authService
        self.membershipStore = membershipStore
    }

    func redeem(_ request: FamilyInvite.Redeem.Request) async {
        guard let redeemerUid = authService.currentUser?.uid, !redeemerUid.isEmpty else {
            presenter?.presentNotAuthenticated()
            return
        }

        let normalized = request.shortCode
            .uppercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard normalized.count == FamilyInvite.codeLength else {
            presenter?.presentError(FamilyInviteError.invalidShortCode)
            return
        }

        presenter?.presentLoading()

        do {
            let redemption = try await inviteService.redeemInvite(
                byShortCode: normalized,
                redeemerUid: redeemerUid
            )

            // Фиксируем членство локально (persistence-only, без фантомных детей).
            membershipStore.save(
                FamilyMembershipRecord(
                    inviterParentId: redemption.parentId,
                    role: redemption.role,
                    joinedAt: redemption.consumedAt
                )
            )

            logger.info(
                "RedeemInviteInteractor: redeemed role=\(redemption.role.rawValue, privacy: .public)"
            )
            presenter?.presentSuccess(
                FamilyInvite.Redeem.Response(
                    role: redemption.role,
                    inviterParentId: redemption.parentId
                )
            )
        } catch {
            logger.error(
                "RedeemInviteInteractor: redeem failed \(error.localizedDescription, privacy: .public)"
            )
            presenter?.presentError(error)
        }
    }
}

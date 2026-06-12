import Foundation
import OSLog

// MARK: - CreateInviteInteractor
//
// Бизнес-логика создания семейного приглашения:
//   1. Валидация длительности (1…168 часов).
//   2. Вызов FamilyInviteService.createInvite(role:durationHours:) — реальный
//      Cloud Function через DI (никаких заглушек в проде).
//   3. Передача результата (shortCode + срок + ShareLink-URL) в Presenter.

@MainActor
final class CreateInviteInteractor {

    private let logger = Logger(subsystem: "ru.happyspeech", category: "CreateInviteInteractor")
    private let inviteService: any FamilyInviteServiceProtocol
    weak var presenter: CreateInvitePresenter?

    init(inviteService: any FamilyInviteServiceProtocol) {
        self.inviteService = inviteService
    }

    func createInvite(_ request: FamilyInvite.Create.Request) async {
        presenter?.presentLoading()

        let duration = min(max(request.durationHours, 1), 168)

        do {
            let token = try await inviteService.createInvite(
                role: request.role.parentRole,
                durationHours: duration
            )
            logger.info(
                "CreateInviteInteractor: invite created role=\(request.role.rawValue, privacy: .public)"
            )
            presenter?.presentCreated(
                FamilyInvite.Create.Response(
                    shortCode: token.shortCode,
                    expiresAt: token.expiresAt,
                    shareURL: token.deepLinkURL,
                    role: request.role
                )
            )
        } catch {
            logger.error(
                "CreateInviteInteractor: create failed \(error.localizedDescription, privacy: .public)"
            )
            presenter?.presentError(error)
        }
    }
}

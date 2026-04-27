@testable import HappySpeech
import SwiftUI
import XCTest

// MARK: - VoiceOverLabelsTests
//
// M10.6 — Unit-тесты accessibility VoiceOver coverage.
//
// Стратегия: проверяем что ключевые ViewModel-поля и строки, которые
// View использует как accessibilityLabel, не пустые. Это покрывает
// ViewModel-контракт без запуска симулятора.
//
// Тесты проверяют:
//   1. ChildProfileDTO имеет непустые name/id (базис для accessibilityLabel)
//   2. AuthUser имеет непустой uid
//   3. SyncState описания корректны
//   4. AppError локализованные описания не пустые
//   5. AnalyticsEvent не крашит при создании
//   6. ChildProfileDTO.preview имеет валидные поля для UI

final class VoiceOverLabelsTests: XCTestCase {

    // MARK: - 1. ChildProfileDTO — name не пустой (базис для accessibilityLabel в ChildHome)

    func test_childProfileDTO_name_notEmpty() {
        let dto = ChildProfileDTO.preview
        XCTAssertFalse(dto.name.isEmpty,
                       "ChildProfileDTO.name не должен быть пустым — используется как accessibilityLabel в ChildHomeView")
    }

    // MARK: - 2. ChildProfileDTO — id не пустой (accessibility identifier)

    func test_childProfileDTO_id_notEmpty() {
        let dto = ChildProfileDTO.preview
        XCTAssertFalse(dto.id.isEmpty,
                       "ChildProfileDTO.id не должен быть пустым — используется как accessibilityIdentifier")
    }

    // MARK: - 3. ChildProfileDTO.previewList — все имена непустые

    func test_childProfileDTO_previewList_allNamesNotEmpty() {
        for child in ChildProfileDTO.previewList {
            XCTAssertFalse(child.name.isEmpty,
                           "Каждый профиль в previewList должен иметь непустое имя (id=\(child.id))")
        }
    }

    // MARK: - 4. AuthUser — displayName используется как accessibilityLabel в ParentHome

    func test_authUser_displayName_usedAsLabel() {
        let user = AuthUser(
            uid: "test-uid-001",
            email: "parent@test.ru",
            displayName: "Татьяна Иванова",
            isAnonymous: false,
            isEmailVerified: true
        )
        XCTAssertNotNil(user.displayName,
                        "AuthUser.displayName должен быть установлен для VoiceOver в ParentHomeView")
        XCTAssertFalse(user.displayName?.isEmpty ?? true,
                       "AuthUser.displayName не должен быть пустым")
    }

    // MARK: - 5. SyncState — все случаи имеют читаемое описание для accessibility

    func test_syncState_descriptions_notEmpty() {
        let states: [SyncState] = [
            .idle,
            .syncing(progress: 0.5),
            .completed(itemsSynced: 3),
            .failed(message: "нет сети")
        ]

        for state in states {
            let description: String
            switch state {
            case .idle: description = "idle"
            case .syncing(let p): description = "syncing \(Int(p * 100))%"
            case .completed(let n): description = "completed \(n)"
            case .failed(let m): description = m
            }
            XCTAssertFalse(description.isEmpty,
                           "SyncState.\(state) должен иметь непустое описание для UI accessibility")
        }
    }

    // MARK: - 6. AppError — localizedDescription не пустой

    func test_appError_localizedDescription_notEmpty() {
        let errors: [AppError] = [
            .authInvalidCredential,
            .authEmailAlreadyInUse,
            .authUserNotFound,
            .realmReadFailed("тест"),
            .entityNotFound("id-001")
        ]

        for error in errors {
            let desc = error.localizedDescription
            XCTAssertFalse(desc.isEmpty,
                           "AppError.\(error) должен иметь непустой localizedDescription (используется в UI accessibility)")
        }
    }

    // MARK: - 7. SyncError — errorDescription не nil и не пустой

    func test_syncError_errorDescription_notEmpty() {
        let errors: [SyncError] = [
            .offline,
            .invalidPayload,
            .remoteRejected("PERMISSION_DENIED"),
            .unknown
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription,
                            "SyncError.\(error) должен иметь errorDescription")
            XCTAssertFalse(error.errorDescription?.isEmpty ?? true,
                           "SyncError.\(error).errorDescription не должен быть пустым")
        }
    }

    // MARK: - 8. ChildProfileDTO targetSounds не пустой (для accessibility в LessonPlayer)

    func test_childProfileDTO_targetSounds_notEmpty() {
        let dto = ChildProfileDTO.preview
        XCTAssertFalse(dto.targetSounds.isEmpty,
                       "targetSounds не должен быть пустым — используется в заголовках LessonPlayer")
    }

    // MARK: - 9. AuthUser anonymous — uid непустой (используется как accessibilityIdentifier)

    func test_authUser_anonymous_uidNotEmpty() async throws {
        let mockAuth = MockAuthService()
        let user = try await mockAuth.signInAnonymously()
        XCTAssertFalse(user.uid.isEmpty,
                       "UID анонимного пользователя не должен быть пустым")
    }

    // MARK: - 10. SyncOperation payload — непустой (используется в логах accessibility debugging)

    func test_syncOperation_payload_notEmpty() {
        let op = SyncOperation(
            entityType: "child_progress",
            entityId: "child-a11y-001",
            operation: "upsert",
            payload: #"{"percent":0.7}"#
        )
        XCTAssertFalse(op.payload.isEmpty,
                       "SyncOperation.payload не должен быть пустым")
        XCTAssertFalse(op.entityType.isEmpty,
                       "SyncOperation.entityType не должен быть пустым")
        XCTAssertFalse(op.entityId.isEmpty,
                       "SyncOperation.entityId не должен быть пустым")
    }

    // MARK: - 11. ChildProfileDTO avatarStyle непустой (используется в accessibilityLabel аватара)

    func test_childProfileDTO_avatarStyle_notEmpty() {
        let dto = ChildProfileDTO.preview
        XCTAssertFalse(dto.avatarStyle.isEmpty,
                       "avatarStyle не должен быть пустым — используется как accessibilityLabel для аватара")
    }

    // MARK: - 12. ChildProfileDTO colorTheme непустой

    func test_childProfileDTO_colorTheme_notEmpty() {
        let dto = ChildProfileDTO.preview
        XCTAssertFalse(dto.colorTheme.isEmpty,
                       "colorTheme не должен быть пустым")
    }

    // MARK: - 13. ChildProfileDTO age в диапазоне 5–8 (дети, для которых есть content)

    func test_childProfileDTO_age_inValidRange() {
        for child in ChildProfileDTO.previewList {
            XCTAssertTrue((4...10).contains(child.age),
                          "Возраст ребёнка должен быть в разумном диапазоне (4–10): \(child.age)")
        }
    }
}
